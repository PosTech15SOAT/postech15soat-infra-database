# RFC-003 — Secrets e pipeline Terraform

## Status
Aceito

## Contexto
Credenciais de banco e credenciais AWS não devem ser mantidas em arquivos versionados ou chaves estáticas no pipeline.

## Decisão
A senha master do PostgreSQL será gerenciada pelo próprio RDS no AWS Secrets Manager (`manage_master_user_password = true`). 

## Decisão

A senha master do PostgreSQL será gerenciada pelo próprio Amazon RDS através do AWS Secrets Manager utilizando `manage_master_user_password = true`.

No ambiente acadêmico AWS Academy, o GitHub Actions utiliza credenciais temporárias cadastradas como GitHub Actions Secrets:

- `AWS_ACCESS_KEY_ID`;
- `AWS_SECRET_ACCESS_KEY`;
- `AWS_SESSION_TOKEN`.

O fluxo de entrega é:

1. alterações são desenvolvidas em branches `feature/*`;
2. Pull Requests para `develop` executam validações e `terraform plan`;
3. a promoção ocorre de `develop` para `main`;
4. alterações integradas à `main` executam `terraform apply`.

As credenciais do AWS Academy possuem expiração e devem ser atualizadas no GitHub quando uma nova sessão do laboratório for iniciada.

## Consequências
- nenhuma senha de banco no repositório ou em `terraform.tfvars`;
- ausência de Access Key/Secret Key AWS persistentes no GitHub;
- trilha de auditoria de alterações via Pull Request e Actions;
- necessidade de configurar uma IAM Role OIDC e o Environment `production` fora do Terraform deste repositório.
