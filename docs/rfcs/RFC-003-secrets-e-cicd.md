# RFC-003 — Secrets e pipeline Terraform

## Status
Aceito

## Contexto
Credenciais de banco e credenciais AWS não devem ser mantidas em arquivos versionados.

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

Em um ambiente produtivo real, recomenda-se substituir esse modelo por autenticação federada utilizando GitHub OIDC e IAM Role.

## Consequências

- nenhuma senha de banco no repositório ou em `terraform.tfvars`;
- credenciais AWS do laboratório não são armazenadas no código-fonte;
- trilha de auditoria das alterações através de Pull Requests e GitHub Actions;
- necessidade de atualizar os GitHub Actions Secrets quando as credenciais temporárias do AWS Academy expirarem.
