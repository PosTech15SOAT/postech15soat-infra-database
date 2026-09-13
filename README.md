# NumberOne — Infraestrutura do Banco

Infraestrutura como código do banco PostgreSQL do projeto **NumberOne**, desenvolvida para o Tech Challenge Fase 3 da FIAP.

Este repositório concentra o provisionamento do Amazon RDS PostgreSQL e a documentação relacionada à infraestrutura do banco. A aplicação principal, autenticação, rede base, EKS, API Gateway e governança permanecem em seus respectivos repositórios.

## 📌 Visão Geral

Responsabilidades deste repositório:

- Amazon RDS for PostgreSQL;
- DB Subnet Group com subnets privadas vindas do `postech15soat-infra-cloud`;
- Security Group dedicado ao banco;
- DB Parameter Group customizado;
- senha master gerenciada pelo Amazon RDS no AWS Secrets Manager;
- state Terraform próprio para banco;
- remote state para consumir dados da infraestrutura cloud;
- CI/CD Terraform com GitHub Actions;
- documentação arquitetural específica do banco;
- documentação de modelo de dados disponível no repositório.

A VPC, subnets, EKS, ECR e infraestrutura cloud base não são criados aqui. Esses recursos pertencem ao repositório `postech15soat-infra-cloud`.

## 🏗️ Arquitetura

Fluxo integrado da solução NumberOne:

```text
Cliente / Insomnia
    -> API Gateway HTTP API
    -> Lambda Authorizer
    -> VPC Link
    -> NLB interno
    -> EKS / Spring Boot
    -> RDS PostgreSQL
```

Escopo deste repositório dentro da arquitetura:

```text
postech15soat-infra-cloud
    -> VPC
    -> private subnets
    -> EKS cluster security group

postech15soat-infra-database
    -> DB Subnet Group
    -> Security Group RDS
    -> DB Parameter Group
    -> Amazon RDS PostgreSQL
    -> AWS Secrets Manager
```

O diagrama de componentes específico do banco está em [docs/architecture/component-diagram.md](docs/architecture/component-diagram.md).

## 🧰 Tecnologias

- Terraform `>= 1.7.0`;
- AWS Provider `~> 5.0`;
- Amazon RDS for PostgreSQL;
- AWS Secrets Manager;
- Amazon S3 para backend remoto do Terraform;
- GitHub Actions;
- Docker Compose para execução local do PostgreSQL.

## 📁 Estrutura do Projeto

```text
.
├── .github/
│   └── workflows/
├── adapters/
│   └── java/
├── database/
│   ├── migrations/
│   └── seeds/
├── docs/
│   ├── architecture/
│   └── rfcs/
├── infra/
├── modules/
│   └── rds/
├── backend.tf
├── docker-compose.yml
├── main.tf
├── outputs.tf
├── providers.tf
├── terraform.tfvars.example
├── variables.tf
└── versions.tf
```

Diretórios de atenção:

- `adapters/`: código Java de persistência preservado como referência/histórico dos adapters da aplicação; não é compilado por este repositório Terraform.
- `database/`: contém SQL de schema inicial e seed para execução local/desenvolvimento; não altera o executor atual de migrations da aplicação.
- `infra/`: estrutura Terraform anterior/legada, mantida no repositório, mas diferente do root atual usado pelos workflows.
- `modules/rds/`: módulo Terraform atual do RDS usado pelo root module.

## ✅ Pré-requisitos

- Terraform compatível com `>= 1.7.0`;
- AWS CLI configurado para uso local, quando necessário;
- acesso ao AWS Academy para o ambiente acadêmico;
- permissões para RDS, EC2 Security Groups, Secrets Manager e S3 backend;
- bucket S3 do state configurado em `TF_STATE_BUCKET`;
- state do `postech15soat-infra-cloud` já disponível no mesmo bucket;
- Docker, caso use o PostgreSQL local via `docker-compose.yml`.

## ⚙️ Configuração

O exemplo de variáveis fica em [terraform.tfvars.example](terraform.tfvars.example).

Configuração acadêmica atual:

```hcl
aws_region   = "us-east-1"
project_name = "numberone"
environment  = "lab"

cloud_state_key = "cloud/terraform.tfstate"

db_name                  = "numberone"
db_username              = "numberone_admin"
db_instance_class        = "db.t4g.micro"
db_allocated_storage     = 20
db_max_allocated_storage = 100

deletion_protection     = false
backup_retention_period = 7
```

`cloud_state_bucket` é informado pelo pipeline via `TF_VAR_cloud_state_bucket` e aponta para o bucket configurado em `TF_STATE_BUCKET`.

Não configure senha de banco em `terraform.tfvars`. A senha master é gerenciada pelo RDS com `manage_master_user_password = true`.

## ▶️ Execução Local

Para subir um PostgreSQL local com o schema inicial:

```bash
cp .env.example .env
docker compose up -d
```

O `docker-compose.yml` monta [database/migrations/V1__create_initial_schema.sql](database/migrations/V1__create_initial_schema.sql) em `/docker-entrypoint-initdb.d/001_schema.sql`.

Para conectar localmente no RDS privado usando ferramentas como DBeaver ou DataGrip, consulte [docs/rds-port-forward.md](docs/rds-port-forward.md).

## 🧪 Validação da Infraestrutura

Comandos mínimos de validação:

```bash
terraform init
terraform fmt -check -recursive
terraform validate
terraform plan -var-file=terraform.tfvars.example
```

Para validação local sem backend remoto:

```bash
terraform init -backend=false
terraform validate
```

O provisionamento normal do ambiente acadêmico ocorre via GitHub Actions. Não execute `apply` ou `destroy` sem intenção explícita de alterar recursos.

## 🔐 Segurança

Controles configurados no Terraform atual:

- RDS sem acesso público (`publicly_accessible = false`);
- DB Subnet Group com subnets privadas consumidas do remote state de cloud;
- Security Group dedicado ao RDS;
- acesso PostgreSQL na porta TCP `5432`;
- origem autorizada pelo Security Group do EKS (`eks_cluster_security_group_id`);
- armazenamento criptografado (`storage_encrypted = true`);
- SSL/TLS obrigatório via `rds.force_ssl = 1`;
- senha master gerenciada pelo Amazon RDS no AWS Secrets Manager;
- ausência de senha de banco em `terraform.tfvars`, GitHub Actions Secrets ou código-fonte.

Parameter Group customizado:

| Parâmetro | Valor | Objetivo |
|---|---:|---|
| `rds.force_ssl` | `1` | Obriga conexões SSL/TLS |
| `log_connections` | `1` | Registra novas conexões |
| `log_disconnections` | `1` | Registra desconexões |
| `log_min_duration_statement` | `1000` | Registra consultas com duração superior a 1 segundo |

Nunca versionar:

- Access Key AWS;
- Secret Access Key AWS;
- Session Token;
- senha do PostgreSQL;
- conteúdo de secrets;
- `terraform.tfstate`;
- arquivos locais com credenciais reais.

## 🚀 CI/CD

Workflows existentes:

| Workflow | Evento | Função |
|---|---|---|
| `.github/workflows/ci.yml` | `push` e PR para `develop`/`main` | valida README, diff, `terraform init -backend=false`, `fmt` e `validate` |
| `.github/workflows/terraform-plan.yml` | PR para `develop`/`main` e `workflow_dispatch` | executa `init`, `fmt`, `validate` e `plan` |
| `.github/workflows/branch-flow.yml` | PR para `main` | exige origem `develop` |
| `.github/workflows/terraform-apply.yml` | `push` em `main` e `workflow_dispatch` | executa `terraform apply` no environment `production` |

Fluxo de branches:

```text
feature/*
    -> Pull Request
develop
    -> Pull Request
main
    -> Production
```

As regras efetivas de proteção de branches são centralizadas no repositório `postech15soat-governance`.

## ☁️ Deploy

O deploy de infraestrutura ocorre no GitHub Actions quando alterações chegam à branch `main`.

O workflow de apply usa:

```bash
terraform apply -input=false -auto-approve -var-file=terraform.tfvars.example
```

O environment utilizado é `production`.

Secrets e variables esperados no GitHub:

- `AWS_ACCESS_KEY_ID`;
- `AWS_SECRET_ACCESS_KEY`;
- `AWS_SESSION_TOKEN`;
- `TF_STATE_BUCKET`.

As credenciais AWS são temporárias no AWS Academy e podem precisar de atualização a cada nova sessão de laboratório.

## 🗃️ Banco de Dados

Características reais do RDS configurado:

| Item | Valor |
|---|---|
| Engine | `postgres` |
| Versão | `17.5` |
| Classe | `db.t4g.micro` |
| Armazenamento inicial | `20 GiB` |
| Armazenamento máximo | `100 GiB` |
| Tipo de storage | `gp3` |
| Criptografia | habilitada |
| Acesso público | desabilitado |
| Multi-AZ | desabilitado / Single-AZ |
| Backup retention | `7` dias |
| Auto minor version upgrade | habilitado |
| Deletion protection | desabilitado no exemplo acadêmico |
| Apply immediately | habilitado |
| Final snapshot no destroy | desabilitado (`skip_final_snapshot = true`) |
| Porta | `5432` |

Documentação de modelo de dados existente:

- [docs/architecture/authentication-der.md](docs/architecture/authentication-der.md): DER apenas do contexto de autenticação administrativa.
- [database/migrations/V1__create_initial_schema.sql](database/migrations/V1__create_initial_schema.sql): SQL com schema inicial contendo entidades de autenticação e domínio.
- [database/seeds/seed_oficina_mvp.sql](database/seeds/seed_oficina_mvp.sql): seed local/desenvolvimento.

Situação do DER:

- Existe DER de autenticação.
- Existe migration SQL com tabelas e FKs do schema inicial.
- Não foi encontrado DER completo consolidado da solução.
- Não foi encontrada explicação formal consolidada de todos os relacionamentos.

TODO OBRIGATÓRIO — consolidar DER/modelo relacional final da solução e explicação dos relacionamentos.

## 🔄 Integração com outros repositórios

- `postech15soat-infra-cloud`: fornece VPC, subnets privadas e Security Group do EKS pelo remote state.
- `numberone-app-auth`: autenticação por CPF, JWT, Lambda Authorizer, API Gateway e migrations/tabelas relacionadas ao RBAC quando aplicável.
- `numberone-app-auto-service-api`: aplicação principal, domínio e execução atual do Flyway no startup.
- `postech15soat-governance`: rulesets, branch protection e required checks.

Outputs consumidos do state cloud:

- `vpc_id`;
- `private_subnet_ids`;
- `eks_cluster_security_group_id`.

Este repositório depende desses outputs para provisionar rede e segurança do RDS. Isso não significa acoplamento da aplicação ao Terraform do banco.

## 📚 Documentação

- [Documentação arquitetural](docs/architecture/architecture.md)
- [Diagrama de componentes do banco](docs/architecture/component-diagram.md)
- [DER de autenticação](docs/architecture/authentication-der.md)
- [Adapters de persistência](docs/adapters.md)
- [Tunel local para o RDS](docs/rds-port-forward.md)
- [Variáveis de ambiente](docs/variaveis-ambiente.md)
- [RFC-001 — Repositório dedicado para infraestrutura do banco](docs/rfcs/RFC-001-repositorio-dedicado.md)
- [RFC-002 — PostgreSQL no Amazon RDS](docs/rfcs/RFC-002-rds-postgresql.md)
- [RFC-003 — Secrets e pipeline Terraform](docs/rfcs/RFC-003-secrets-e-cicd.md)

Não há arquivo `docs/video/roteiro.md` neste repositório.

## 🧠 Decisões Arquiteturais

RFCs existentes:

| RFC | Status | Tema |
|---|---|---|
| [RFC-001](docs/rfcs/RFC-001-repositorio-dedicado.md) | Aceito | Repositório dedicado para infraestrutura do banco |
| [RFC-002](docs/rfcs/RFC-002-rds-postgresql.md) | Aceito | PostgreSQL no Amazon RDS |
| [RFC-003](docs/rfcs/RFC-003-secrets-e-cicd.md) | Aceito | Secrets Manager e pipeline Terraform |

Justificativa formal da escolha do PostgreSQL: [RFC-002 — PostgreSQL no Amazon RDS](docs/rfcs/RFC-002-rds-postgresql.md).

ADRs existentes: nenhum ADR foi encontrado no repositório.

Candidatos a ADR, sem status de decisão aceita:

- `[CANDIDATO A ADR]` política acadêmica de Single-AZ, sizing reduzido e deletion protection desabilitado;
- `[CANDIDATO A ADR]` ownership futuro das migrations no `postech15soat-infra-database`;
- `[CANDIDATO A ADR]` política produtiva futura de alta disponibilidade, backups e disaster recovery.

## ⚠️ Limitações e decisões do ambiente acadêmico

Por orientação acadêmica, existem apenas:

- Local: desenvolvimento;
- Production: AWS Academy.

Não há ambiente cloud de homologação neste projeto.

Decisões pragmáticas confirmadas no Terraform:

- `db.t4g.micro`;
- Single-AZ;
- armazenamento inicial de `20 GiB`;
- deletion protection desabilitado no exemplo acadêmico;
- `skip_final_snapshot = true`;
- `apply_immediately = true`;
- credenciais AWS temporárias do AWS Academy.

Essas escolhas atendem ao contexto acadêmico, custo e simplicidade operacional do laboratório. Elas não representam necessariamente uma configuração de produção corporativa.

## 🤝 Contribuição

Fluxo esperado:

1. criar branch `feature/*`;
2. abrir Pull Request para `develop`;
3. validar CI e Terraform plan;
4. promover de `develop` para `main` via Pull Request;
5. aplicar em `production` pelo GitHub Actions.

Não fazer push direto para `develop` ou `main`.
