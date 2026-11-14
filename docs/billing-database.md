# Database do Billing

O Billing usa o database `numberone_billing` na instância RDS existente. O
Terraform cria apenas o secret `numberone-billing-database` (ou o prefixo
configurado em `project_name`), sem valor nem senha no state. A criação dos
objetos PostgreSQL é uma operação administrativa separada: o provider AWS
usado pela Fase 3 não administra roles e databases internos, e o runner do
workflow não tem acesso direto ao RDS privado.

## Provisionamento após o apply

1. Confirme no plano que somente o secret Billing será criado e execute o fluxo
   Terraform habitual. No Secrets Manager, gere uma senha forte e independente
   e salve uma versão JSON no secret criado, com as chaves `username` e
   `password`. Use `numberone_billing` como `username`. Não use o secret nem
   a senha master como credencial da aplicação. Restrinja leitura do secret
   às identidades que precisam dele, incluindo a identidade de deploy Billing.
2. Abra o [túnel existente](rds-port-forward.md) e, em outro terminal, conecte
   com `psql` ao database administrativo `postgres`, como usuário master do
   RDS, usando `sslmode=require`. Informe a senha master interativamente;
   não a coloque na linha de comando, no histórico ou em arquivos do repositório.
   Por exemplo: `psql "host=localhost port=5432 dbname=postgres user=numberone_admin sslmode=require"`.
3. Verifique que a role e o database `numberone_billing` ainda não existem
   (`\du numberone_billing` e `\l numberone_billing`). Se algum existir,
   interrompa e investigue seu proprietário e uso; não o recrie ou altere
   automaticamente.
4. No `psql`, execute os comandos abaixo, fora de uma transação. No prompt de
   `\password`, informe a mesma senha salva no secret, sem colá-la como SQL:

   ```sql
   CREATE ROLE numberone_billing NOLOGIN;
   \password numberone_billing
   CREATE DATABASE numberone_billing OWNER numberone_billing;
   ALTER ROLE numberone_billing LOGIN;
   ```

   A role proprietária pode criar os objetos e a tabela de histórico do Flyway
   no schema padrão do database PostgreSQL 17. Se houver falha parcial, examine
   os objetos criados antes de retomar; não apague objetos existentes. Não
   execute as migrations aqui: o Flyway do Billing as executa no startup.
5. Configure no GitHub Environment usado pelo deploy Billing `DB_IDENTIFIER`
   com o identificador do RDS existente e `DB_SECRET_ARN` com o ARN completo do
   novo secret. O ARN pode ser consultado no console do Secrets Manager ou por
   `aws secretsmanager describe-secret --secret-id numberone-billing-database --query ARN --output text`.
   Ajuste o nome se `project_name` tiver sido alterado.

O workflow Billing consulta o endpoint e a porta do RDS, rejeita o secret e o
usuário master, lê `username` e `password` do secret e sincroniza um Secret
Kubernetes com `DB_USERNAME` e `DB_PASSWORD`. Ele cria `DB_URL` no ConfigMap
com `jdbc:postgresql://<endpoint>:<porta>/numberone_billing?sslmode=require`.
O parâmetro existente `rds.force_ssl=1` também exige TLS no servidor;
`sslmode=require` não verifica a identidade do servidor. A identidade de deploy
precisa de `rds:DescribeDBInstances`, `secretsmanager:GetSecretValue` e, se
aplicável, `kms:Decrypt`, além do acesso Kubernetes já necessário ao deploy.

O database compartilha capacidade, conexões, backups e disponibilidade da
instância com os demais workloads. O provisionamento deve ser realizado com
cuidado e a senha mantida consistente entre PostgreSQL e Secrets Manager;
rotacioná-la exige atualizar ambos e sincronizar novamente o Secret do EKS.
