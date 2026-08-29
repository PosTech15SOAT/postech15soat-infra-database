# PosTech15SOAT — Infraestrutura do Banco

Infraestrutura como código do banco PostgreSQL do projeto PosTech15SOAT, provisionada na AWS com Terraform.

## Escopo

Este repositório é responsável por:

- Amazon RDS for PostgreSQL;
- DB Subnet Group utilizando subnets privadas já existentes;
- Security Group do banco;
- DB Parameter Group customizado;
- credencial master gerenciada pelo RDS no AWS Secrets Manager;
- state Terraform independente;
- pipelines GitHub Actions para plan e apply;
- documentação arquitetural, RFCs, DER de autenticação e apoio ao vídeo.

A VPC **não é criada neste repositório**. Ela é consumida do state da infraestrutura principal por `terraform_remote_state`.

## Arquitetura

O state atual da rede encontra-se, por padrão, em:

- bucket: `backend-terraform-numberone`
- key: `infra/terraform.tfstate`
- região: `us-east-1`

O state deste repositório utiliza uma chave própria:

- bucket: `backend-terraform-numberone`
- key: `infra-banco/terraform.tfstate`

O fluxo completo está documentado em [docs/architecture/architecture.md](docs/architecture/architecture.md) e no [diagrama de componentes](docs/architecture/component-diagram.md).

## Pré-requisitos

- Terraform >= 1.7;
- conta AWS com permissão para RDS, EC2 Security Groups, Secrets Manager e leitura/escrita do backend S3;
- infraestrutura principal previamente provisionada, expondo `vpc_id` e `private_subnet_ids`;
- AWS CLI configurada para execução local, quando aplicável.

## Configuração local

Copie o arquivo de exemplo:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Ajuste somente os valores necessários. **Não coloque senha do banco no arquivo**: a senha master é gerenciada automaticamente pelo RDS no AWS Secrets Manager.

## Execução

```bash
terraform init
terraform fmt -check -recursive
terraform validate
terraform plan
terraform apply
```

## Secrets Manager

A instância utiliza `manage_master_user_password = true`. Com isso:

1. o RDS gera a senha master;
2. a credencial é armazenada no AWS Secrets Manager;
3. a senha não é persistida em `terraform.tfvars` ou GitHub Actions;
4. o ARN do secret é disponibilizado no output `rds_master_secret_arn` como valor sensível.

## Parameter Group

O PostgreSQL utiliza um Parameter Group `postgres17` customizado com:

- `rds.force_ssl = 1`;
- `log_connections = 1`;
- `log_disconnections = 1`;
- `log_min_duration_statement = 1000` ms.

## Segurança de rede

A porta 5432 é liberada preferencialmente para o Security Group da aplicação via `application_security_group_id`.

Enquanto esse SG não estiver exposto como output da infraestrutura principal, o módulo utiliza um fallback para o CIDR da VPC. Esse comportamento é temporário e está registrado na documentação arquitetural.

## GitHub Actions

### Pull Request

`.github/workflows/terraform-plan.yml` executa:

- `terraform init`;
- `terraform fmt -check -recursive`;
- `terraform validate`;
- `terraform plan`.

### Main

`.github/workflows/terraform-apply.yml` executa o `terraform apply` no GitHub Environment `production`.

Para que a aprovação funcione, configure em **Settings > Environments > production** um reviewer obrigatório.

### Autenticação AWS

Os workflows usam OIDC. Configure no GitHub o secret:

- `AWS_ROLE_ARN`: ARN da IAM Role que pode ser assumida pelo repositório.

Não é necessário manter `AWS_ACCESS_KEY_ID` ou `AWS_SECRET_ACCESS_KEY` no GitHub.

## Documentação

- [Documentação arquitetural](docs/architecture/architecture.md)
- [Diagrama de componentes](docs/architecture/component-diagram.md)
- [DER de autenticação](docs/architecture/authentication-der.md)
- [RFC-001 — Repositório dedicado](docs/rfcs/RFC-001-repositorio-dedicado.md)
- [RFC-002 — PostgreSQL no RDS](docs/rfcs/RFC-002-rds-postgresql.md)
- [RFC-003 — Secrets e CI/CD](docs/rfcs/RFC-003-secrets-e-cicd.md)
- [Roteiro de apoio ao vídeo](docs/video/roteiro.md)

## Observações para produção

A configuração atual foi dimensionada para contexto acadêmico e controle de custos. Para um ambiente produtivo real, recomenda-se avaliar Multi-AZ, deletion protection, snapshots finais, Performance Insights, alarmes no CloudWatch e uma política formal de backup e recuperação.
