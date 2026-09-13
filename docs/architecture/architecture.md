# Documentação Arquitetural

## Visão geral

O repositório `postech15soat-infra-database` concentra a infraestrutura do banco PostgreSQL do projeto NumberOne.

A infraestrutura é provisionada com Terraform, possui state próprio em Amazon S3 e consome dados de rede do repositório `postech15soat-infra-cloud` via `terraform_remote_state`.

## Contexto

Arquitetura integrada da solução:

```text
Cliente / Insomnia
    -> API Gateway HTTP API
    -> Lambda Authorizer
    -> VPC Link
    -> NLB interno
    -> EKS / Spring Boot
    -> RDS PostgreSQL
```

Este repositório não cria VPC, subnets, EKS, ECR, API Gateway ou Lambda Authorizer. Seu escopo é o banco gerenciado e os recursos diretamente necessários para conectividade, segurança e operação do RDS.

## Componentes

Componentes provisionados por este repositório:

- Amazon RDS for PostgreSQL;
- DB Subnet Group;
- Security Group dedicado ao banco;
- DB Parameter Group customizado;
- integração com AWS Secrets Manager para senha master;
- outputs Terraform para endpoint, porta, Security Group e secret.

Componentes consumidos do `postech15soat-infra-cloud`:

- `vpc_id`;
- `private_subnet_ids`;
- `eks_cluster_security_group_id`.

O diagrama de componentes está em [component-diagram.md](component-diagram.md).

## Amazon RDS PostgreSQL

Configuração real do Terraform atual:

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
| Deletion protection | variável; `false` no exemplo acadêmico |
| Apply immediately | habilitado |
| Final snapshot no destroy | desabilitado |
| Porta | `5432` |

Single-AZ, `db.t4g.micro`, deletion protection desabilitado e snapshot final desabilitado são escolhas pragmáticas do ambiente acadêmico AWS Academy. Para produção corporativa, devem ser reavaliadas conforme requisitos de disponibilidade, backup, recuperação e governança.

## DB Subnet Group

O DB Subnet Group é criado pelo Terraform a partir das subnets privadas recebidas do remote state de cloud:

```hcl
data.terraform_remote_state.cloud.outputs.private_subnet_ids
```

A infraestrutura não cria subnets novas.

## Segurança de rede

O RDS possui Security Group dedicado e não é público.

O acesso de entrada é liberado na porta TCP `5432` a partir do Security Group do EKS:

```hcl
data.terraform_remote_state.cloud.outputs.eks_cluster_security_group_id
```

O módulo ainda possui um recurso de fallback por CIDR da VPC caso `application_security_group_id` seja `null`, mas o root module atual sempre preenche essa variável com o output `eks_cluster_security_group_id`. Portanto, no desenho atual, o acesso esperado é pelo Security Group do EKS.

## DB Parameter Group

Foi criado um DB Parameter Group customizado para PostgreSQL 17.

| Parâmetro | Valor | Finalidade |
|---|---:|---|
| `rds.force_ssl` | `1` | Exigir conexões SSL/TLS |
| `log_connections` | `1` | Registrar conexões |
| `log_disconnections` | `1` | Registrar desconexões |
| `log_min_duration_statement` | `1000` | Registrar consultas com duração superior a 1 segundo |

Esses parâmetros reforçam segurança de transporte e observabilidade básica do banco.

## Gestão de credenciais

A senha master do PostgreSQL não é definida em arquivos Terraform, `tfvars` ou GitHub Actions Secrets.

A instância RDS usa:

```hcl
manage_master_user_password = true
```

Com isso:

- o Amazon RDS gera a senha master;
- a credencial é armazenada no AWS Secrets Manager;
- a senha não é versionada;
- o pipeline não precisa receber senha do banco;
- o Terraform expõe apenas o ARN do secret como output sensível.

## Terraform State

O backend remoto é Amazon S3:

```text
Key:    database/terraform.tfstate
Region: us-east-1
Bucket: informado por backend-config/TF_STATE_BUCKET
```

O root module também consome o state de cloud:

```hcl
data "terraform_remote_state" "cloud" {
  backend = "s3"

  config = {
    bucket = var.cloud_state_bucket
    key    = var.cloud_state_key
    region = var.aws_region
  }
}
```

`cloud_state_key` tem padrão `cloud/terraform.tfstate`.

## CI/CD

O repositório possui quatro workflows:

- `.github/workflows/ci.yml`: validação em push e PR para `develop`/`main`;
- `.github/workflows/terraform-plan.yml`: `init`, `fmt`, `validate` e `plan` em PR para `develop`/`main`;
- `.github/workflows/branch-flow.yml`: PR para `main` precisa vir de `develop`;
- `.github/workflows/terraform-apply.yml`: `apply` em `main` usando GitHub Environment `production`.

O ambiente acadêmico usa credenciais temporárias do AWS Academy em GitHub Actions Secrets.

## Modelo de dados

Materiais existentes neste repositório:

- [authentication-der.md](authentication-der.md): DER do contexto de autenticação administrativa;
- [../../database/migrations/V1__create_initial_schema.sql](../../database/migrations/V1__create_initial_schema.sql): schema inicial em SQL;
- [../../database/seeds/seed_oficina_mvp.sql](../../database/seeds/seed_oficina_mvp.sql): seed local/desenvolvimento.

O DER de autenticação não representa sozinho o banco completo da solução. Não foi encontrado neste repositório um DER consolidado de todos os contextos nem uma explicação formal completa de todos os relacionamentos.

TODO OBRIGATÓRIO — consolidar DER/modelo relacional final da solução e explicação dos relacionamentos.

## Decisões registradas

As decisões formais existentes estão em RFCs:

- [RFC-001 — Repositório dedicado para infraestrutura do banco](../rfcs/RFC-001-repositorio-dedicado.md);
- [RFC-002 — PostgreSQL no Amazon RDS](../rfcs/RFC-002-rds-postgresql.md);
- [RFC-003 — Secrets e pipeline Terraform](../rfcs/RFC-003-secrets-e-cicd.md).

Não há ADRs no repositório.

Candidatos a ADR:

- `[CANDIDATO A ADR]` decisões acadêmicas de sizing e disponibilidade;
- `[CANDIDATO A ADR]` ownership futuro das migrations no repositório de banco;
- `[CANDIDATO A ADR]` política futura de backup, restore e disaster recovery.
