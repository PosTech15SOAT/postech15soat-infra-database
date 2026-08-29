# Documentação Arquitetural

## Visão geral

A infraestrutura do banco foi isolada em um repositório próprio para reduzir acoplamento entre aplicação e persistência, permitir evolução independente e tornar o ciclo de entrega do RDS auditável.

## Contexto

O projeto principal já provisiona a VPC e as subnets privadas. O repositório de banco não recria esses recursos: ele consome `vpc_id` e `private_subnet_ids` por `terraform_remote_state` a partir do state existente.

## Decisões principais

- PostgreSQL gerenciado por Amazon RDS.
- RDS privado, sem exposição pública.
- Armazenamento criptografado.
- Credencial master gerenciada pelo RDS no AWS Secrets Manager.
- Custom DB Parameter Group para PostgreSQL 17.
- TLS obrigatório (`rds.force_ssl = 1`).
- Logs de conexão/desconexão e consultas acima de 1 segundo habilitados no Parameter Group.
- State Terraform do banco separado do state da infraestrutura principal.
- `terraform plan` em Pull Requests.
- `terraform apply` somente na `main`, protegido por GitHub Environment `production`.
- Autenticação AWS do pipeline por OIDC, evitando Access Keys estáticas.

## Segurança de rede

O Security Group do RDS aceita conexões na porta TCP 5432. O modo recomendado usa o Security Group da aplicação como origem. Enquanto esse identificador não estiver publicado pelo state da aplicação, existe fallback para o CIDR da VPC; esse fallback deve ser removido quando a integração entre states estiver concluída.

## Gestão de segredos

A senha master não é declarada em `terraform.tfvars`, GitHub Actions ou código-fonte. `manage_master_user_password = true` delega ao RDS a geração e armazenamento no AWS Secrets Manager. O Terraform expõe apenas o ARN do secret como output sensível.

## Disponibilidade e custo

A configuração inicial usa Single-AZ e `db.t4g.micro` para manter o custo compatível com um ambiente acadêmico. Em produção real, recomenda-se Multi-AZ, proteção contra exclusão, janela de manutenção definida, monitoramento e estratégia formal de recuperação.

## Dependências

1. Bucket S3 `backend-terraform-numberone` acessível pela role do pipeline.
2. State principal em `infra/terraform.tfstate` contendo `vpc_id` e `private_subnet_ids`.
3. GitHub Secret `AWS_ROLE_ARN` apontando para uma IAM Role com confiança OIDC no repositório.
4. GitHub Environment `production` com reviewer obrigatório para aprovação do apply.
