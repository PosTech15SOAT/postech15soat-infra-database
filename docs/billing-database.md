# Database do Billing

O Billing usa o database `numberone_billing` na instância RDS existente. O
Terraform cria apenas o secret `numberone-billing-database` (ou o prefixo
configurado em `project_name`), sem valor nem senha no state. A criação dos
objetos PostgreSQL é uma operação administrativa separada: o provider AWS
usado pela Fase 3 não administra roles e databases internos, e o runner do
workflow não tem acesso direto ao RDS privado.

## Provisionamento após o apply

O workflow de Terraform inicializa o secret com as configurações do repositório quando ainda não existe `AWSCURRENT`. A criação da role e do banco é separada; siga o [procedimento da Fase 4](phase4.md), usando a senha efetiva do secret. Falhas parciais exigem inspeção antes de retomar.

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
