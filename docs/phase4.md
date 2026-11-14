# Fase 4 — databases dos microserviços

A configuração Terraform ativa fica na raiz. Ela cria RDS `numberone-postgres`, com senha master gerenciada pelo RDS, TLS obrigatório e três containers Secrets Manager vazios: `numberone-os-database`, `numberone-billing-database`, `numberone-inventory-database`. O valor de cada secret é criado fora do Terraform e não entra em seu state. O RDS é privado, usa subnets e security group do state Cloud; confirme que os nodes usam o SG autorizado. `infra/` é uma configuração histórica independente e não é utilizada no workflow.

Após provisionar e validar o RDS na nova conta, um administrador deve acessar PostgreSQL em rede privada ou por túnel aprovado (ver `rds-port-forward.md`) usando TLS e credencial master, sem guardar senha em linha de comando, logs ou histórico. Antes de qualquer comando, verifique se roles e databases já existem; se existirem, pare e investigue ownership e privilégios. Não use master nos serviços.

Crie uma senha forte independente para cada role no Secrets Manager, como JSON com `username` e `password`. Os usernames são `numberone_os`, `numberone_billing` e `numberone_inventory`; restrinja leitura de cada secret à identidade de deploy correspondente. Em uma sessão administrativa `psql` conectada ao database `postgres`, execute fora de transação:

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

Em cada prompt `\password`, informe a senha correspondente ao secret sem escrever SQL com senhas. Donos conservam acesso ao próprio banco e podem criar objetos e tabela Flyway. Não conceda membership entre as roles. Como bancos administrativos e o banco inicial também podem conceder CONNECT a PUBLIC, revise e revogue esse acesso nesses bancos quando apropriado, preservando o acesso dos administradores e serviços autorizados. Valide com cada role que pode conectar apenas ao próprio banco, criar objetos e que não acessa os outros; falhas parciais exigem inspeção antes de retomar.

Conecte como administrador ao `numberone_inventory` e execute `CREATE EXTENSION IF NOT EXISTS pgcrypto;` antes do primeiro deploy: a migration V1 também solicita essa extensão. Confirme disponibilidade e permissões no RDS PostgreSQL 17; não execute migrations manualmente. Cada Flyway de aplicação cria seus próprios objetos. URLs dos workflows usam `sslmode=require`; isso cifra mas não autentica a identidade do servidor. Para verificação de identidade é necessário configurar CA RDS e `verify-full` em cada cliente.

Configure no GitHub os ARNs completos (output `application_secret_arns`) como repository variable `DB_SECRET_ARN` de cada serviço, e `DB_APP_USERNAME` em OS e Inventory. Compartilhe organização variables e secrets conforme `docs/phase4.md` no Cloud. Rotação requer atualizar a senha no PostgreSQL e no Secrets Manager e repetir a sincronização Kubernetes, coordenando a janela de troca. Confirme permissões `rds:DescribeDBInstances`, `secretsmanager:GetSecretValue`, eventual `kms:Decrypt` e acesso Kubernetes por identidade. Os Secrets Kubernetes também requerem controle RBAC e proteção adequada de dados no cluster.
