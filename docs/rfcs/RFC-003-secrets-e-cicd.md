# RFC-003 — Secrets e pipeline Terraform

## Status
Aceito

## Contexto
Credenciais de banco e credenciais AWS não devem ser mantidas em arquivos versionados ou chaves estáticas no pipeline.

## Decisão
A senha master do PostgreSQL será gerenciada pelo próprio RDS no AWS Secrets Manager (`manage_master_user_password = true`). O GitHub Actions autentica na AWS por OIDC e assume uma IAM Role indicada pelo secret `AWS_ROLE_ARN`.

O fluxo de entrega é:
1. Pull Request para `main`: `terraform fmt`, `validate` e `plan`.
2. Merge/push em `main`: workflow de `apply`.
3. O job de `apply` referencia o GitHub Environment `production`, que deve possuir aprovação obrigatória.

## Consequências
- nenhuma senha de banco no repositório ou em `terraform.tfvars`;
- ausência de Access Key/Secret Key AWS persistentes no GitHub;
- trilha de auditoria de alterações via Pull Request e Actions;
- necessidade de configurar uma IAM Role OIDC e o Environment `production` fora do Terraform deste repositório.
