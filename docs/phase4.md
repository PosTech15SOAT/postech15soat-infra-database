# Fase 4 — databases dos microserviços

O Terraform na raiz cria o RDS privado `numberone-postgres` e os contêineres `numberone-os-database`, `numberone-billing-database` e `numberone-inventory-database`. As senhas não entram no Terraform State. A configuração `infra/` é histórica e independente.

## Secrets de aplicação

Após cada Terraform Apply bem-sucedido, inclusive sem alterações, o workflow da main inicializa os secrets sem versão `AWSCURRENT`, usando as repository variables `DB_OS_USERNAME`, `DB_BILLING_USERNAME`, `DB_INVENTORY_USERNAME` e os repository secrets `DB_OS_PASSWORD`, `DB_BILLING_PASSWORD`, `DB_INVENTORY_PASSWORD`. Configure todos antes do apply; os usernames devem ser, respectivamente, `numberone_os`, `numberone_billing` e `numberone_inventory`. O valor é JSON com `username` e `password`.

A identidade AWS precisa de `secretsmanager:DescribeSecret` e `secretsmanager:PutSecretValue` nos três secrets e das permissões KMS aplicáveis. Secrets com `AWSCURRENT` não são alterados; mudar valores no GitHub não atualiza nem rotaciona o secret existente. Uma falha pode deixar apenas parte dos secrets preenchida: confira os três e corrija a causa antes de repetir o workflow. Evite execuções simultâneas e outros escritores: a consulta e a gravação não são atômicas.

São credenciais do laboratório AWS Academy. Em produção, utilize credenciais únicas por serviço e ambiente, acesso de menor privilégio, gestão apropriada e rotação coordenada entre PostgreSQL, Secrets Manager e Kubernetes.

## Preparação PostgreSQL

Secrets Manager e PostgreSQL têm estados independentes. Para preparar e validar os bancos e roles sem executar migrations, siga [Inicialização do PostgreSQL](postgresql-initialization.md).

## Deploy dos serviços

Os workflows dos serviços descobrem os secrets por nome e leem suas credenciais durante o deploy. Configure `DB_APP_USERNAME` em OS e Inventory conforme seus respectivos workflows, e conceda às identidades de deploy acesso apenas ao secret necessário, `rds:DescribeDBInstances`, `secretsmanager:GetSecretValue`, eventual `kms:Decrypt` e acesso Kubernetes. Proteja também os Secrets Kubernetes com RBAC adequado.
