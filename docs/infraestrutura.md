# Infraestrutura do banco

O root Terraform atual do repositório fica na raiz e usa:

- `backend.tf`;
- `main.tf`;
- `variables.tf`;
- `outputs.tf`;
- `providers.tf`;
- `versions.tf`;
- `modules/rds/`;
- `terraform.tfvars.example`.

Ele cria uma instância PostgreSQL 17 no Amazon RDS, um DB Subnet Group, um Security Group dedicado, um Parameter Group customizado e usa senha master gerenciada pelo RDS no AWS Secrets Manager.

O diretório `infra/` contém uma estrutura Terraform anterior/legada. Ela foi preservada no repositório, mas não representa o fluxo atual dos workflows de CI/CD.

## Pré-requisitos do root atual

- Terraform 1.7 ou superior;
- credenciais AWS configuradas;
- state do `postech15soat-infra-cloud` disponível no bucket S3;
- variável `TF_STATE_BUCKET` configurada no GitHub Actions;
- credenciais temporárias do AWS Academy cadastradas no GitHub Actions.

O root atual consome do remote state cloud:

- `vpc_id`;
- `private_subnet_ids`;
- `eks_cluster_security_group_id`.

Não configure senha do banco em `terraform.tfvars`. A senha master é gerenciada por `manage_master_user_password = true` e armazenada pelo RDS no AWS Secrets Manager.
