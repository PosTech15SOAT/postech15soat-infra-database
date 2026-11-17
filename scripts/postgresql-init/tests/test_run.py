"""Offline checks for credential reuse and reproducible bootstrap packaging."""
import importlib.util
import base64
import json
import os
from pathlib import Path
import shutil
import tempfile
import unittest
from unittest.mock import patch

os.environ.setdefault('GITHUB_RUN_ID', 'offline-test')
os.environ.setdefault('GITHUB_RUN_ATTEMPT', '1')
SPEC = importlib.util.spec_from_file_location('postgresql_init', Path(__file__).parents[1] / 'run.py')
runner = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(runner)


class AuthCredentialsTest(unittest.TestCase):
    def setUp(self):
        self.value = {'username': runner.AUTH_USERNAME, 'password': 'offline-auth-fixture'}
        self.environment = patch.dict(os.environ, DB_AUTH_USERNAME=self.value['username'],
                                      DB_AUTH_PASSWORD=self.value['password'])
        self.environment.start()
        self.addCleanup(self.environment.stop)

    def test_current_credential_is_reused_without_publication(self):
        with patch.object(runner, 'aws', return_value={'VersionIdsToStages': {'v1': ['AWSCURRENT']}}), \
                patch.object(runner, 'secret_value', return_value=self.value), \
                patch.object(runner, 'call') as writer:
            self.assertEqual(runner.auth_credentials(), self.value)
            writer.assert_not_called()

    def test_empty_secret_publishes_supplied_credential_over_stdin(self):
        with patch.object(runner, 'aws', return_value={}), \
                patch.object(runner, 'secret_value', return_value=self.value) as read, \
                patch.object(runner, 'call') as writer:
            self.assertEqual(runner.auth_credentials(), self.value)
            read.assert_called_once_with(runner.AUTH_SECRET)
            args, kwargs = writer.call_args
            self.assertIn('file:///dev/stdin', args[0])
            self.assertNotIn(self.value['password'], ' '.join(args[0]))
            self.assertEqual(json.loads(kwargs['data']), self.value)
            self.assertTrue(kwargs['sensitive'])

    def test_missing_or_invalid_input_fails_before_aws(self):
        for username, password in [('', 'test'), ('owner', 'test'), (runner.AUTH_USERNAME, ''),
                                   (runner.AUTH_USERNAME, 'test\n')]:
            with self.subTest(username=username, password=repr(password)), \
                    patch.dict(os.environ, DB_AUTH_USERNAME=username, DB_AUTH_PASSWORD=password), \
                    patch.object(runner, 'aws') as aws:
                with self.assertRaises(RuntimeError):
                    runner.auth_credentials()
                aws.assert_not_called()

    def test_divergent_current_is_not_replaced_or_exposed(self):
        for value in [{'username': 'owner', 'password': self.value['password']},
                      {'username': runner.AUTH_USERNAME, 'password': 'different-private-fixture'}]:
            with self.subTest(username=value['username']), \
                    patch.object(runner, 'aws', return_value={'VersionIdsToStages': {'v1': ['AWSCURRENT']}}), \
                    patch.object(runner, 'secret_value', return_value=value), \
                    patch.object(runner, 'call') as writer:
                with self.assertRaisesRegex(RuntimeError, 'divergem') as error:
                    runner.auth_credentials()
                self.assertNotIn(value['password'], str(error.exception))
                writer.assert_not_called()

    def test_versions_without_current_fail_without_replacement(self):
        with patch.object(runner, 'aws', return_value={'VersionIdsToStages': {'v1': ['AWSPREVIOUS']}}), \
                patch.object(runner, 'call') as writer:
            with self.assertRaisesRegex(RuntimeError, 'parcial'):
                runner.auth_credentials()
            writer.assert_not_called()

    def test_read_or_iam_failure_does_not_replace_current(self):
        with patch.object(runner, 'aws', return_value={'VersionIdsToStages': {'v1': ['AWSCURRENT']}}), \
                patch.object(runner, 'secret_value', side_effect=RuntimeError('unavailable')), \
                patch.object(runner, 'call') as writer:
            with self.assertRaises(RuntimeError):
                runner.auth_credentials()
            writer.assert_not_called()
        with patch.object(runner, 'aws', side_effect=RuntimeError('access denied')), \
                patch.object(runner, 'call') as writer:
            with self.assertRaises(RuntimeError):
                runner.auth_credentials()
            writer.assert_not_called()

    def test_read_after_publication_must_match_input(self):
        with patch.object(runner, 'aws', return_value={}), \
                patch.object(runner, 'secret_value', return_value={'username': runner.AUTH_USERNAME, 'password': 'other'}), \
                patch.object(runner, 'call') as writer:
            with self.assertRaisesRegex(RuntimeError, 'divergem'):
                runner.auth_credentials()
            writer.assert_called_once()


class SecretParsingTest(unittest.TestCase):
    def test_invalid_payloads_fail_without_exposing_values(self):
        for value in ['not-json-private-fixture', '[]', '{}',
                      json.dumps({'username': runner.AUTH_USERNAME, 'password': ''}),
                      json.dumps({'username': runner.AUTH_USERNAME, 'password': 'private-fixture\n'})]:
            with self.subTest(value_type=type(value).__name__), \
                    patch.object(runner, 'call', return_value=json.dumps({'SecretString': value})):
                with self.assertRaises(RuntimeError) as error:
                    runner.secret_value(runner.AUTH_SECRET)
                self.assertNotIn('private-fixture', str(error.exception))


class BootstrapFilesTest(unittest.TestCase):
    def test_sql_files_and_relative_include_are_packaged(self):
        files = runner.bootstrap_files()
        self.assertIn('auth-bootstrap.psql', files)
        self.assertIn('auth-001_identity.sql', files)
        self.assertIn('\\ir 001_identity.sql', files['auth-bootstrap.psql'])

    def test_changed_vendor_sql_is_rejected_before_aws_calls(self):
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / 'scripts'
            shutil.copytree(runner.SCRIPT_DIR, target, ignore=shutil.ignore_patterns('__pycache__'))
            (target / 'auth/db/phase4/001_identity.sql').write_text('-- changed\n')
            with patch.object(runner, 'SCRIPT_DIR', target), patch.object(runner, 'aws') as aws:
                with self.assertRaisesRegex(RuntimeError, 'Checksum'):
                    runner.main()
                aws.assert_not_called()


class JobPackagingTest(unittest.TestCase):
    def test_job_keeps_relative_sql_paths_and_cleans_up_temporary_resources(self):
        account = '123456789012'
        master_arn = 'master-fixture-arn'
        fixtures = {
            ('sts', 'get-caller-identity'): {'Account': account},
            ('eks', 'describe-cluster'): {'cluster': {'status': 'ACTIVE', 'resourcesVpcConfig': {'vpcId': 'vpc-fixture'}}},
            ('rds', 'describe-db-instances'): {'DBInstances': [{
                'DBInstanceStatus': 'available', 'Engine': 'postgres', 'EngineVersion': '17.5',
                'PubliclyAccessible': False, 'DBSubnetGroup': {'VpcId': 'vpc-fixture'},
                'MasterUserSecret': {'SecretArn': master_arn}, 'MasterUsername': 'test_master',
                'Endpoint': {'Address': 'postgresql.invalid', 'Port': 5432},
            }]},
            ('secretsmanager', 'describe-secret'): {'VersionIdsToStages': {'v1': ['AWSCURRENT']}},
        }

        def fake_secret(name):
            username = 'test_master' if name == master_arn else name.removesuffix('-database').replace('-', '_')
            return {'username': username, 'password': 'offline-password-fixture'}

        def fake_kube(*args, **kwargs):
            if args[:2] == ('auth', 'can-i'):
                return 'yes'
            if args[:2] == ('get', 'job'):
                return json.dumps({'status': {'succeeded': 1}})
            return ''

        with patch.dict(os.environ, EXPECTED_AWS_ACCOUNT_ID=account,
                        DB_AUTH_USERNAME=runner.AUTH_USERNAME, DB_AUTH_PASSWORD='offline-auth-password-fixture'), \
                patch.object(runner, 'aws', side_effect=lambda *args: fixtures[args[:2]]), \
                patch.object(runner, 'call'), patch.object(runner, 'kube', side_effect=fake_kube) as kube, \
                patch.object(runner, 'secret_value', side_effect=fake_secret), \
                patch.object(runner, 'auth_credentials', return_value={
                    'username': runner.AUTH_USERNAME, 'password': 'offline-auth-password-fixture'}), \
                patch.object(runner, 'create') as create, patch('builtins.print'):
            runner.main()
        configmap, credentials, job = [call.args[0] for call in create.call_args_list]
        self.assertTrue(create.call_args_list[1].kwargs['sensitive'])
        self.assertEqual(base64.b64decode(credentials['data'][runner.AUTH_USERNAME]).decode(), 'offline-auth-password-fixture')
        pod = job['spec']['template']['spec']
        mounts = pod['volumes'][0]['configMap']['items']
        mounted_files = {item['path']: configmap['data'][item['key']] for item in mounts}
        self.assertIn('auth/db/phase4/bootstrap.psql', mounted_files)
        self.assertIn('auth/db/phase4/001_identity.sql', mounted_files)
        command = pod['containers'][0]['command']
        self.assertEqual(command, ['/bin/bash', '-c', 'bash /bootstrap/bootstrap.sh && bash /bootstrap/auth-bootstrap.sh'])
        self.assertNotIn('offline-auth-password-fixture', json.dumps(job))
        self.assertFalse(pod['automountServiceAccountToken'])
        self.assertEqual([call.args[1] for call in kube.call_args_list if call.args[0] == 'delete'],
                         ['job', 'secret', 'configmap'])


if __name__ == '__main__':
    unittest.main()
