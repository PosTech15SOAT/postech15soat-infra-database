#!/usr/bin/env python3
"""Run one short-lived EKS bootstrap job; secret values only travel over stdin."""
import base64
import hashlib
import hmac
import json
import os
from pathlib import Path
import subprocess
import sys
import time

REGION = 'us-east-1'
NAMESPACE = 'default'
NAME = 'pg-init-' + os.environ['GITHUB_RUN_ID'] + '-' + os.environ['GITHUB_RUN_ATTEMPT']
SCRIPT_DIR = Path(__file__).resolve().parent
AUTH_SECRET = 'numberone-auth-database'
AUTH_USERNAME = 'numberone_auth_runtime'


def call(args, *, data=None, sensitive=False):
    result = subprocess.run(args, input=data, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if result.returncode:
        if not sensitive:
            print(result.stderr, file=sys.stderr)
        raise RuntimeError('Falha em ' + ' '.join(args[:2]))
    return result.stdout


def aws(*args):
    return json.loads(call(['aws', *args, '--region', REGION, '--output', 'json']))


def kube(*args, data=None, sensitive=False):
    return call(['kubectl', '-n', NAMESPACE, *args], data=data, sensitive=sensitive)


def create(obj, sensitive=False):
    kube('create', '-f', '-', data=json.dumps(obj), sensitive=sensitive)


def secret_value(name):
    # Nunca encaminhar stderr ou conteúdo do secret para logs.
    try:
        result = call(['aws', 'secretsmanager', 'get-secret-value', '--secret-id', name,
                       '--version-stage', 'AWSCURRENT', '--region', REGION, '--output', 'json'], sensitive=True)
    except RuntimeError as error:
        raise RuntimeError('Falha ao ler secret; verifique IAM, KMS, AWSCURRENT e validade das credenciais: ' + name) from error
    try:
        value = json.loads(json.loads(result)['SecretString'])
    except (KeyError, TypeError, ValueError) as error:
        raise RuntimeError('Secret sem JSON SecretString válido: ' + name) from error
    if not isinstance(value, dict) or not isinstance(value.get('username'), str) or not isinstance(value.get('password'), str):
        raise RuntimeError('Secret sem username/password válidos: ' + name)
    if not value['username'] or not value['password'] or any(c in value['password'] for c in '\r\n\x00'):
        raise RuntimeError('Secret vazio ou senha com quebra de linha/NUL: ' + name)
    return value


def auth_input():
    username = os.environ.get('DB_AUTH_USERNAME', '')
    password = os.environ.get('DB_AUTH_PASSWORD', '')
    if username != AUTH_USERNAME:
        raise RuntimeError('DB_AUTH_USERNAME deve ser ' + AUTH_USERNAME)
    if not password or any(c in password for c in '\r\n\x00'):
        raise RuntimeError('DB_AUTH_PASSWORD ausente ou contém quebra de linha/NUL')
    return {'username': username, 'password': password}


def auth_credentials():
    expected = auth_input()
    description = aws('secretsmanager', 'describe-secret', '--secret-id', AUTH_SECRET)
    versions = description.get('VersionIdsToStages', {})
    if not any('AWSCURRENT' in stages for stages in versions.values()):
        if versions:
            raise RuntimeError('Secret Auth parcial: existem versões sem AWSCURRENT; inspecione sem rotacionar')
        # O container do secret é criado somente pelo Terraform. O valor nunca passa em argv.
        call(['aws', 'secretsmanager', 'put-secret-value', '--secret-id', AUTH_SECRET,
              '--secret-string', 'file:///dev/stdin', '--region', REGION, '--output', 'json'],
             data=json.dumps(expected), sensitive=True)
    # Releitura garante que a credencial enviada ao PostgreSQL é a versão publicada.
    value = secret_value(AUTH_SECRET)
    if value['username'] != expected['username'] or not hmac.compare_digest(value['password'].encode(), expected['password'].encode()):
        raise RuntimeError('Credenciais do Auth divergem do secret AWSCURRENT; inspecione sem rotacionar')
    return value


def bootstrap_files():
    files = {name: (SCRIPT_DIR / name).read_text(encoding='utf-8')
             for name in ['bootstrap.sh', 'auth-bootstrap.sh', 'auth-validate.sql']}
    source = json.loads((SCRIPT_DIR / 'auth/source.json').read_text(encoding='utf-8'))
    for path in ['db/phase4/bootstrap.psql', 'db/phase4/001_identity.sql']:
        data = (SCRIPT_DIR / 'auth' / path).read_bytes()
        if hashlib.sha256(data).hexdigest() != source['sha256'][path]:
            raise RuntimeError('Checksum divergente no SQL Auth: ' + path)
        files['auth-' + Path(path).name] = data.decode('utf-8')
    return files


def main():
    scripts = bootstrap_files()
    auth_input()
    expected_account = os.environ.get('EXPECTED_AWS_ACCOUNT_ID', '')
    if len(expected_account) != 12 or not expected_account.isascii() or not expected_account.isdecimal():
        raise RuntimeError('Configure EXPECTED_AWS_ACCOUNT_ID com o ID da conta AWS de destino')
    if aws('sts', 'get-caller-identity')['Account'] != expected_account:
        raise RuntimeError('Conta AWS inesperada')
    cluster = aws('eks', 'describe-cluster', '--name', 'numberone-eks')['cluster']
    if cluster['status'] != 'ACTIVE':
        raise RuntimeError('Cluster EKS não está ACTIVE')
    db = aws('rds', 'describe-db-instances', '--db-instance-identifier', 'numberone-postgres')['DBInstances'][0]
    if db['DBInstanceStatus'] != 'available' or db['Engine'] != 'postgres' or not db['EngineVersion'].startswith('17.') or db['PubliclyAccessible']:
        raise RuntimeError('RDS indisponível, público ou incompatível')
    if db['DBSubnetGroup']['VpcId'] != cluster['resourcesVpcConfig']['vpcId']:
        raise RuntimeError('RDS e EKS estão em VPCs diferentes')
    master_arn = db['MasterUserSecret']['SecretArn']
    for name in ['numberone-os-database', 'numberone-billing-database', 'numberone-inventory-database', master_arn]:
        description = aws('secretsmanager', 'describe-secret', '--secret-id', name)
        if not any('AWSCURRENT' in stages for stages in description.get('VersionIdsToStages', {}).values()):
            raise RuntimeError('Secret sem AWSCURRENT: ' + name)
    call(['aws', 'eks', 'update-kubeconfig', '--name', 'numberone-eks', '--region', REGION])
    kube('get', 'namespace', NAMESPACE)
    for verb, resource in [('create', 'jobs'), ('get', 'jobs'), ('watch', 'jobs'), ('delete', 'jobs'), ('create', 'secrets'), ('delete', 'secrets'), ('create', 'configmaps'), ('delete', 'configmaps'), ('get', 'pods'), ('list', 'pods'), ('get', 'pods/log')]:
        try:
            allowed = kube('auth', 'can-i', verb, resource).strip() == 'yes'
        except RuntimeError as error:
            raise RuntimeError('Falha na verificação RBAC: ' + verb + ' ' + resource + ' no namespace ' + NAMESPACE) from error
        if not allowed:
            raise RuntimeError('RBAC insuficiente: ' + verb + ' ' + resource + ' no namespace ' + NAMESPACE)
    master = secret_value(master_arn)
    if master['username'] != db['MasterUsername']:
        raise RuntimeError('Username master diverge do RDS')
    values = {'master-username': master['username'], 'master-password': master['password']}
    for service in ['os', 'billing', 'inventory']:
        name = 'numberone_' + service
        secret = secret_value('numberone-' + service + '-database')
        if secret['username'] != name:
            raise RuntimeError('Username inesperado no secret de ' + service)
        values[name] = secret['password']
    auth = auth_credentials()
    values[AUTH_USERNAME] = auth['password']
    metadata = {'name': NAME, 'namespace': NAMESPACE, 'labels': {'app.kubernetes.io/name': 'postgresql-initialization'}}
    created = []
    try:
        create({'apiVersion': 'v1', 'kind': 'ConfigMap', 'metadata': metadata, 'data': scripts})
        created.append('configmap')
        create({'apiVersion': 'v1', 'kind': 'Secret', 'metadata': metadata, 'type': 'Opaque',
                'data': {k: base64.b64encode(v.encode()).decode() for k, v in values.items()}}, sensitive=True)
        created.append('secret')
        del values, master, secret, auth
        job = {'apiVersion': 'batch/v1', 'kind': 'Job', 'metadata': metadata, 'spec': {
            'backoffLimit': 0, 'activeDeadlineSeconds': 600, 'ttlSecondsAfterFinished': 3600,
            'template': {'metadata': {'labels': {'app': NAME}}, 'spec': {
                'restartPolicy': 'Never', 'automountServiceAccountToken': False,
                'containers': [{'name': 'bootstrap', 'image': 'postgres:17',
                    'command': ['/bin/bash', '-c', 'bash /bootstrap/bootstrap.sh && bash /bootstrap/auth-bootstrap.sh'],
                    'env': [{'name': 'RDS_HOST', 'value': db['Endpoint']['Address']}, {'name': 'RDS_PORT', 'value': str(db['Endpoint']['Port'])}],
                    'resources': {'requests': {'cpu': '100m', 'memory': '64Mi'}, 'limits': {'cpu': '500m', 'memory': '256Mi'}},
                    'securityContext': {'allowPrivilegeEscalation': False, 'capabilities': {'drop': ['ALL']}, 'runAsNonRoot': True, 'runAsUser': 999, 'seccompProfile': {'type': 'RuntimeDefault'}},
                    'volumeMounts': [{'name': 'script', 'mountPath': '/bootstrap', 'readOnly': True}, {'name': 'credentials', 'mountPath': '/credentials', 'readOnly': True}]}],
                'volumes': [{'name': 'script', 'configMap': {'name': NAME, 'items': [
                    {'key': name, 'path': name} for name in ['bootstrap.sh', 'auth-bootstrap.sh', 'auth-validate.sql']
                ] + [
                    {'key': 'auth-' + name, 'path': 'auth/db/phase4/' + name}
                    for name in ['bootstrap.psql', '001_identity.sql']
                ]}}, {'name': 'credentials', 'secret': {'secretName': NAME}}]}}}}
        create(job)
        created.append('job')
        print('Job criado:', NAME, flush=True)
        def diagnose_pods():
            try:
                pods = json.loads(kube('get', 'pods', '-l', 'job-name=' + NAME, '-o', 'json'))
                for pod in pods.get('items', []):
                    status = pod.get('status', {})
                    print('Pod:', pod['metadata']['name'], 'fase:', status.get('phase', 'Unknown'))
                    for container in status.get('containerStatuses', []):
                        state = container.get('state', {})
                        for key in ('waiting', 'terminated'):
                            if key in state:
                                print('Container:', container['name'], key, state[key].get('reason', 'Unknown'))
            except RuntimeError:
                print('Estado dos Pods indisponível.', file=sys.stderr)

        end = time.monotonic() + 660
        while time.monotonic() < end:
            status = json.loads(kube('get', 'job', NAME, '-o', 'json'))['status']
            if status.get('succeeded') or status.get('failed'):
                try:
                    print(kube('logs', 'job/' + NAME, '--all-containers=true'))
                except RuntimeError:
                    print('Logs indisponíveis; verifique eventos do Pod.', file=sys.stderr)
                if status.get('succeeded'):
                    return
                diagnose_pods()
                raise RuntimeError('Job falhou; verifique logs e eventos do Pod')
            time.sleep(5)
        diagnose_pods()
        raise RuntimeError('Tempo esgotado aguardando Job; verifique agendamento e rede')
    finally:
        cleanup_failed = False
        for kind in reversed(created):
            try:
                if kind == 'job':
                    kube('delete', kind, NAME, '--ignore-not-found=true', '--cascade=foreground', '--wait=true', '--timeout=60s')
                else:
                    kube('delete', kind, NAME, '--ignore-not-found=true', '--wait=false')
            except RuntimeError:
                print('Limpeza falhou: ' + kind + '/' + NAME, file=sys.stderr)
                cleanup_failed = True
        if cleanup_failed:
            raise RuntimeError('Limpeza incompleta; remova os recursos identificados após inspeção')


if __name__ == '__main__':
    try:
        main()
    except (RuntimeError, KeyError, ValueError, json.JSONDecodeError) as error:
        print('ERRO:', error, file=sys.stderr)
        sys.exit(1)
