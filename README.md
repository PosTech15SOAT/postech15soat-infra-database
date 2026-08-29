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

A VPC **não é criada neste repositório**. A infraestrutura utiliza uma VPC existente na conta AWS.

O identificador da VPC e as subnets utilizadas pelo RDS são informados ao Terraform por variáveis, permitindo reutilizar a infraestrutura de rede existente sem duplicar recursos.

## Arquitetura

A infraestrutura do banco utiliza recursos de rede já existentes na AWS.

No ambiente acadêmico utilizado atualmente:

- região AWS: `us-east-1`;
- VPC existente: `vpc-0764754eefab31378`;
- CIDR da VPC: `172.31.0.0/16`;
- as subnets utilizadas pelo RDS são fornecidas através das variáveis Terraform;
- nenhuma nova VPC é criada por este repositório.

O state Terraform deste repositório é armazenado em um backend S3 independente:

- bucket: `postech15soat-infra-banco-tfstate-777137014941`;
- key: `infra-banco/terraform.tfstate`;
- região: `us-east-1`;
- versionamento habilitado no bucket;
- bloqueio de acesso público habilitado.

Essa separação permite que a infraestrutura do banco evolua de forma independente da infraestrutura da aplicação.

## Pré-requisitos

- Terraform >= 1.7;
- conta AWS com permissão para RDS, EC2 Security Groups, Secrets Manager e leitura/escrita no backend S3;
- VPC existente na AWS;
- pelo menos duas subnets disponíveis em zonas de disponibilidade distintas;
- credenciais temporárias válidas do AWS Academy;
- AWS CLI configurada para execução local, quando aplicável.

## Configuração local

As principais variáveis de rede são:

- `vpc_id`: identificador da VPC existente;
- `subnet_ids`: subnets utilizadas para criação do DB Subnet Group;
- `vpc_cidr`: CIDR utilizado como fallback temporário para acesso ao PostgreSQL;
- `application_security_group_id`: Security Group da aplicação, quando disponível.

No ambiente AWS Academy atualmente utilizado, esses valores já estão exemplificados no arquivo `terraform.tfvars.example`.

**Não coloque senha do banco no arquivo.** A senha master é gerenciada automaticamente pelo Amazon RDS através do AWS Secrets Manager.

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

`.github/workflows/terraform-plan.yml` é executado em Pull Requests destinados às branches `develop` e `main`.

O workflow executa:

- `terraform init`;
- `terraform fmt -check -recursive`;
- `terraform validate`;
- `terraform plan`.

O fluxo de desenvolvimento adotado é:

`feature/*` → `develop` → `main`

Dessa forma, alterações de infraestrutura são validadas antes da promoção para os ambientes de integração e principal.

### Main

Quando uma alteração é integrada à branch `main`, `.github/workflows/terraform-apply.yml` executa o provisionamento da infraestrutura através de:

```bash
terraform apply

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
