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

Quando `application_security_group_id` é informado, o acesso ao PostgreSQL é permitido somente a partir do Security Group da aplicação.

Quando esse identificador não está disponível, o módulo permite utilizar temporariamente o CIDR da VPC como origem para conexões na porta TCP 5432.

No ambiente acadêmico atual, é utilizado o CIDR `172.31.0.0/16` como fallback. Essa configuração deve ser restringida em um ambiente produtivo.

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

O ambiente acadêmico utiliza credenciais temporárias fornecidas pelo AWS Academy.

Os workflows do GitHub Actions utilizam os seguintes GitHub Actions Secrets:

- `AWS_ACCESS_KEY_ID`;
- `AWS_SECRET_ACCESS_KEY`;
- `AWS_SESSION_TOKEN`.

Esses valores devem ser obtidos a partir da sessão atual do AWS Academy e cadastrados em:

**Settings > Secrets and variables > Actions**

As credenciais do AWS Academy são temporárias e expiram periodicamente. Quando uma nova sessão do laboratório é iniciada, pode ser necessário atualizar esses três secrets no GitHub.

Nenhuma credencial AWS deve ser adicionada diretamente ao código-fonte, arquivos `.tf`, `terraform.tfvars` ou documentação.

Em um ambiente corporativo ou produtivo, recomenda-se substituir credenciais temporárias por autenticação federada via GitHub OIDC e IAM Role.

### Ambiente AWS Academy

A infraestrutura atual é executada em uma conta temporária do AWS Academy.

Características importantes desse ambiente:

- região utilizada: `us-east-1`;
- as credenciais AWS possuem tempo de expiração;
- recursos disponíveis dependem das permissões associadas ao `LabRole`;
- a VPC e as subnets padrão da conta são reutilizadas;
- o backend S3 foi criado especificamente para armazenar o state deste projeto.

Devido às limitações naturais de um ambiente acadêmico, algumas decisões priorizam simplicidade e controle de custos.

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
