# Validação local do bootstrap

Os testes offline usam apenas a biblioteca padrão Python e mocks de AWS/Kubernetes:

```bash
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s scripts/postgresql-init/tests -v
```

A CI executa esses testes e a sintaxe Bash. Os testes SQL são ignorados sem
`POSTGRESQL_TEST_CONTAINER`. Para executá-los, use somente um container PostgreSQL 17
local e descartável: os testes apagam e recriam os quatro databases e suas roles
dentro dele. Eles recusam um servidor sem o marcador `cluster_name` abaixo ou sem
autenticação SCRAM nas conexões TCP, inclusive loopback.

Se Docker e a imagem `postgres:17` já estiverem disponíveis, é possível executar
em memória, sem portas publicadas, rede externa ou provisionamento AWS. As senhas
abaixo são fixtures locais, sem relação com o ambiente real:

```bash
docker run --rm -d --pull=never --name numberone-auth-bootstrap-test \
  --network none --tmpfs /var/lib/postgresql/data:rw \
  --mount type=bind,src="$PWD/scripts/postgresql-init",dst=/bootstrap,readonly \
  -e POSTGRES_PASSWORD=local-disposable-test-only \
  -e 'POSTGRES_INITDB_ARGS=--auth-host=scram-sha-256 --auth-local=trust' \
  --entrypoint bash postgres:17 -c '
    openssl req -x509 -newkey rsa:2048 -nodes \
      -keyout /tmp/server.key -out /tmp/server.crt \
      -days 1 -subj /CN=localhost >/dev/null 2>&1 &&
    chown postgres:postgres /tmp/server.key /tmp/server.crt &&
    chmod 600 /tmp/server.key &&
    exec docker-entrypoint.sh postgres \
      -c cluster_name=numberone-bootstrap-test \
      -c ssl=on -c ssl_cert_file=/tmp/server.crt -c ssl_key_file=/tmp/server.key'

# Aguarde o servidor ficar pronto antes de iniciar os testes.
docker exec numberone-auth-bootstrap-test pg_isready -U postgres

POSTGRESQL_TEST_CONTAINER=numberone-auth-bootstrap-test PYTHONDONTWRITEBYTECODE=1 \
  python3 -m unittest discover -s scripts/postgresql-init/tests -v

docker stop numberone-auth-bootstrap-test
```

Os testes SQL usam um master `CREATEDB CREATEROLE`, sem superuser, e TLS. Comparam
hashes de dumps, ACLs, memberships e verificadores de senha antes e depois da
reexecução. Cobrem ausência de usuários no bootstrap, preservação de dados nos
quatro bancos, senha incompatível, roles/schema parciais e divergências de owner,
grants, constraints, colunas, defaults e permissões base. Os testes offline cobrem
reuso/geração de credenciais, falhas de IAM/leitura, formato de secrets, checksums,+caminhos do ConfigMap/Job e limpeza dos recursos temporários.

Esses testes não comprovam IAM/KMS, RBAC, conectividade EKS/RDS ou particularidades
do master gerenciado pelo RDS. Nenhum teste executa AWS CLI real, Terraform apply
ou deploy. Não aponte os testes para bancos com dados a preservar.
