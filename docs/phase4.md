# Fase 4 — databases dos microserviços

O Terraform na raiz cria o RDS privado `numberone-postgres` e os contêineres `numberone-os-database`, `numberone-billing-database` e `numberone-inventory-database`. As senhas não entram no Terraform State. A configuração `infra/` é histórica e independente.

## Secrets de aplicação

Após cada Terraform Apply bem-sucedido, inclusive sem alterações, o workflow da main inicializa os secrets sem versão `AWSCURRENT`, usando as repository variables `DB_OS_USERNAME`, `DB_BILLING_USERNAME`, `DB_INVENTORY_USERNAME` e os repository secrets `DB_OS_PASSWORD`, `DB_BILLING_PASSWORD`, `DB_INVENTORY_PASSWORD`. Configure todos antes do apply; os usernames devem ser, respectivamente, `numberone_os`, `numberone_billing` e `numberone_inventory`. O valor é JSON com `username` e `password`.

A identidade AWS precisa de `secretsmanager:DescribeSecret` e `secretsmanager:PutSecretValue` nos três secrets e das permissões KMS aplicáveis. Secrets com `AWSCURRENT` não são alterados; mudar valores no GitHub não atualiza nem rotaciona o secret existente. Uma falha pode deixar apenas parte dos secrets preenchida: confira os três e corrija a causa antes de repetir o workflow. Evite execuções simultâneas e outros escritores: a consulta e a gravação não são atômicas.

São credenciais do laboratório AWS Academy. Em produção, utilize credenciais únicas por serviço e ambiente, acesso de menor privilégio, gestão apropriada e rotação coordenada entre PostgreSQL, Secrets Manager e Kubernetes.

## Preparação PostgreSQL

Secrets Manager e PostgreSQL têm estados independentes: inicializar um secret não cria a role ou configura sua senha. Um administrador deve preparar os bancos separadamente, usando as mesmas credenciais cadastradas para cada serviço. Se um secret já tinha `AWSCURRENT`, confira a credencial efetiva armazenada nele por um meio seguro: ela pode ser diferente da configuração atual do GitHub. Não imprima senhas em logs, argumentos, histórico ou SQL e não use a credencial master nos serviços.

Acesse o RDS por rede privada ou pelo [túnel](rds-port-forward.md), usando TLS e a credencial master gerenciada pelo RDS. Confirme conta, endpoint, identidade e permissões. Antes de iniciar, verifique a existência das três roles e databases; se qualquer um existir, pare e investigue ownership e privilégios. Em uma sessão administrativa `psql` conectada a `postgres`, execute fora de transação:

```sql
CREATE ROLE numberone_os NOLOGIN;
CREATE ROLE numberone_billing NOLOGIN;
CREATE ROLE numberone_inventory NOLOGIN;
\password numberone_os
\password numberone_billing
\password numberone_inventory
CREATE DATABASE numberone_os OWNER numberone_os;
CREATE DATABASE numberone_billing OWNER numberone_billing;
CREATE DATABASE numberone_inventory OWNER numberone_inventory;
REVOKE CONNECT, TEMPORARY ON DATABASE numberone_os FROM PUBLIC;
REVOKE CONNECT, TEMPORARY ON DATABASE numberone_billing FROM PUBLIC;
REVOKE CONNECT, TEMPORARY ON DATABASE numberone_inventory FROM PUBLIC;
ALTER ROLE numberone_os LOGIN;
ALTER ROLE numberone_billing LOGIN;
ALTER ROLE numberone_inventory LOGIN;
```

Em cada prompt `\password`, informe a senha correspondente ao secret. Donos podem criar os objetos e o histórico Flyway; não conceda membership entre as roles. Conecte como administrador ao `numberone_inventory` e execute `CREATE EXTENSION IF NOT EXISTS pgcrypto;` antes do primeiro deploy. Não execute as migrations manualmente. Se houver falha parcial, inspecione os objetos antes de retomar; não apague bancos nem redefina senhas automaticamente.

Valide que cada role conecta ao próprio banco e não aos outros dois. Revise separadamente o acesso aos bancos administrativos e ao banco inicial, preservando os acessos necessários. TLS com `sslmode=require` cifra a conexão, mas não autentica o servidor; para verificar a identidade, configure a CA do RDS e `verify-full`.

## Deploy dos serviços

Os workflows dos serviços descobrem os secrets por nome e leem suas credenciais durante o deploy. Configure `DB_APP_USERNAME` em OS e Inventory conforme seus respectivos workflows, e conceda às identidades de deploy acesso apenas ao secret necessário, `rds:DescribeDBInstances`, `secretsmanager:GetSecretValue`, eventual `kms:Decrypt` e acesso Kubernetes. Proteja também os Secrets Kubernetes com RBAC adequado.
