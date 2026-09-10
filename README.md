# PosTech15SOAT — Infraestrutura do Banco

Infraestrutura como código do banco PostgreSQL do projeto **PosTech15SOAT**, provisionada na AWS utilizando Terraform.

## Objetivo

Este repositório concentra a infraestrutura necessária para execução do banco de dados PostgreSQL do projeto PosTech15SOAT.

A separação da infraestrutura do banco em um repositório dedicado permite:

- ciclo de vida independente do banco de dados;
- menor acoplamento com a infraestrutura da aplicação;
- controle das alterações através de Pull Requests;
- automação do provisionamento através do GitHub Actions;
- state Terraform independente;
- documentação das decisões arquiteturais através de RFCs.

## Escopo

Este repositório é responsável por:

- Amazon RDS for PostgreSQL;
- DB Subnet Group utilizando subnets existentes;
- Security Group dedicado ao banco;
- DB Parameter Group customizado;
- credencial master gerenciada pelo Amazon RDS através do AWS Secrets Manager;
- state Terraform independente armazenado no Amazon S3;
- pipelines GitHub Actions para validação, plan e apply;
- documentação arquitetural;
- RFCs;
- DER de autenticação;
- roteiro de apoio ao vídeo da entrega.

A VPC **não é criada neste repositório**.

A infraestrutura consome automaticamente a VPC, as subnets privadas e o Security Group do EKS a partir do remote state do repositório `postech15soat-infra-cloud`.

---

## Arquitetura

A infraestrutura utiliza recursos de rede existentes na AWS e provisiona somente os componentes relacionados ao banco de dados.

Fluxo simplificado:

```text
GitHub
   |
   v
GitHub Actions
   |
   v
Terraform
   |
   +------------------> Amazon S3
   |                    Terraform State
   |
   +------------------> VPC / Subnets existentes
   |
   +------------------> Security Group
   |
   +------------------> Parameter Group
   |
   +------------------> Amazon RDS PostgreSQL
                            |
                            v
                     AWS Secrets Manager
```

No ambiente acadêmico utilizado atualmente:

- região AWS: `us-east-1`;
- VPC e subnets privadas são obtidas do state `cloud/terraform.tfstate`;
- o Security Group do EKS é autorizado diretamente na porta `5432`;
- nenhuma nova VPC é criada pelo projeto.

O diagrama completo está disponível em:

`docs/architecture/component-diagram.md`

---

## Amazon RDS PostgreSQL

O banco é provisionado utilizando **Amazon RDS for PostgreSQL**.

A configuração acadêmica atual utiliza:

- PostgreSQL `17.5`;
- instância `db.t4g.micro`;
- armazenamento inicial de `20 GiB`;
- autoscaling de armazenamento até `100 GiB`;
- armazenamento `gp3`;
- criptografia habilitada;
- Single-AZ;
- acesso público desabilitado;
- backup automático por `7 dias`;
- atualização automática de versões menores;
- aplicação imediata das alterações;
- senha master gerenciada pelo Amazon RDS.

A configuração Single-AZ e a classe `db.t4g.micro` foram escolhidas devido ao contexto acadêmico e ao objetivo de reduzir consumo de recursos.

---

## Parameter Group

O PostgreSQL utiliza um DB Parameter Group customizado para PostgreSQL 17.

Os seguintes parâmetros são configurados:

| Parâmetro | Valor | Objetivo |
|---|---:|---|
| `rds.force_ssl` | `1` | Obriga conexões utilizando SSL/TLS |
| `log_connections` | `1` | Registra novas conexões |
| `log_disconnections` | `1` | Registra desconexões |
| `log_min_duration_statement` | `1000` | Registra queries com duração superior a 1 segundo |

Essas configurações aumentam a segurança e a observabilidade do banco.

---

## Secrets Manager

A senha master do PostgreSQL **não é definida em arquivos Terraform ou tfvars**.

A instância utiliza:

```hcl
manage_master_user_password = true
```

Com essa configuração:

1. o Amazon RDS gera a senha master;
2. a credencial é armazenada automaticamente no AWS Secrets Manager;
3. a senha não é persistida em `terraform.tfvars`;
4. a senha não é armazenada no código-fonte;
5. a senha não precisa ser cadastrada no GitHub Actions;
6. o ARN do secret pode ser disponibilizado através dos outputs Terraform.

Isso evita o armazenamento de credenciais do banco diretamente no repositório.

---

## Segurança de rede

O RDS possui um Security Group dedicado.

A porta utilizada pelo PostgreSQL é:

```text
TCP 5432
```

O acesso ao banco é permitido somente através do Security Group do EKS publicado pela infraestrutura cloud:

```text
eks_cluster_security_group_id
```

Não existe fallback para todo o CIDR da VPC quando o state compartilhado está sendo utilizado.

---

## Terraform State

O state Terraform desta infraestrutura é armazenado separadamente no Amazon S3.

Configuração atual:

```text
Bucket: configurado pela variável de ambiente GitHub `TF_STATE_BUCKET`
Key:    database/terraform.tfstate
Region: us-east-1
```

O bucket possui:

- versionamento habilitado;
- bloqueio de acesso público habilitado.

O state independente permite que a infraestrutura do banco evolua sem depender do ciclo de vida do Terraform da aplicação.

---

## Variáveis Terraform

As principais variáveis utilizadas são:

### Rede

- `cloud_state_bucket`: bucket que contém o state da infraestrutura cloud;
- `cloud_state_key`: chave do state cloud, por padrão `cloud/terraform.tfstate`.

### Banco

- `db_name`: nome inicial do banco;
- `db_username`: usuário master;
- `db_instance_class`: classe da instância RDS;
- `db_allocated_storage`: armazenamento inicial;
- `db_max_allocated_storage`: limite de autoscaling;
- `backup_retention_period`: quantidade de dias de backup;
- `deletion_protection`: habilita ou desabilita proteção contra exclusão.

### Projeto

- `aws_region`: região AWS;
- `project_name`: nome base utilizado nos recursos;
- `environment`: ambiente lógico da infraestrutura.

Um exemplo de configuração está disponível em:

```text
terraform.tfvars.example
```

**Não adicione senha do banco nesse arquivo.**

---

## Exemplo de configuração

O ambiente acadêmico utiliza atualmente:

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

---

## Pré-requisitos

Para executar a infraestrutura são necessários:

- Terraform `>= 1.7`;
- conta AWS;
- acesso ao ambiente AWS Academy para o contexto acadêmico;
- permissões necessárias para RDS;
- permissões para EC2 Security Groups;
- permissões para Secrets Manager;
- acesso de leitura e escrita ao backend S3;
- VPC existente;
- pelo menos duas subnets em zonas de disponibilidade distintas;
- credenciais AWS válidas.

Para execução local, também é recomendado possuir AWS CLI configurada.

---

## Execução local

Inicialize o Terraform:

```bash
terraform init
```

Verifique a formatação:

```bash
terraform fmt -check -recursive
```

Valide a configuração:

```bash
terraform validate
```

Gere o plano:

```bash
terraform plan -var-file=terraform.tfvars.example
```

Para provisionar a infraestrutura manualmente:

```bash
terraform apply -var-file=terraform.tfvars.example
```

O provisionamento normal do projeto, entretanto, é realizado através do GitHub Actions.

---

## CI/CD com GitHub Actions

O repositório utiliza GitHub Actions para validar e provisionar a infraestrutura.

O fluxo adotado é:

```text
feature/* → develop → main
```

Alterações não devem ser enviadas diretamente para `develop` ou `main`.

---

### Pull Requests

O workflow:

```text
.github/workflows/terraform-plan.yml
```

é executado em Pull Requests destinados às branches:

- `develop`;
- `main`.

O pipeline executa:

```text
terraform init
        ↓
terraform fmt -check -recursive
        ↓
terraform validate
        ↓
terraform plan
```

Dessa forma, alterações de infraestrutura são verificadas antes de serem integradas.

---

### Promoção para `main`

Pull Requests destinados à `main` devem ter como origem a branch:

```text
develop
```

O workflow de validação de fluxo impede a promoção direta de uma branch `feature/*` para `main`.

O fluxo esperado é:

```text
feature/*
    |
    v
 develop
    |
    v
  main
```

---

### Terraform Apply

Quando uma alteração é integrada à branch `main`, o workflow:

```text
.github/workflows/terraform-apply.yml
```

executa o provisionamento através de:

```bash
terraform apply -input=false -auto-approve -var-file=terraform.tfvars.example
```

Assim, commits e Pull Requests em `develop` validam o Terraform sem aplicar
infraestrutura. O `terraform plan` e utilizado durante a validacao dos Pull
Requests, e o `terraform apply` ocorre somente apos a promocao para `main`.

---

## Autenticação AWS no GitHub Actions

O ambiente acadêmico utiliza credenciais temporárias fornecidas pelo **AWS Academy**.

Os workflows utilizam os seguintes GitHub Actions Secrets:

- `AWS_ACCESS_KEY_ID`;
- `AWS_SECRET_ACCESS_KEY`;
- `AWS_SESSION_TOKEN`.

Os valores devem ser obtidos a partir da sessão atual do AWS Academy e cadastrados no GitHub em:

```text
Settings
  → Secrets and variables
    → Actions
```

As credenciais do AWS Academy são temporárias e expiram periodicamente.

Quando uma nova sessão do laboratório for iniciada, pode ser necessário atualizar os três GitHub Actions Secrets.

**Nenhuma credencial AWS deve ser adicionada diretamente ao código-fonte, arquivos `.tf`, `terraform.tfvars` ou documentação.**

Em um ambiente corporativo ou produtivo, recomenda-se substituir esse modelo por autenticação federada utilizando **GitHub OIDC + IAM Role**.

---

## Proteção das branches

As branches de integração possuem regras de proteção para garantir o fluxo de entrega.

O repositório utiliza:

- `Protected integration branches`;
- `Require develop promotion`;
- `Required CI checks`.

Essas regras ajudam a garantir que:

- alterações sejam realizadas através de Pull Requests;
- `main` receba alterações provenientes de `develop`;
- validações obrigatórias sejam executadas antes do merge;
- alterações diretas nas branches de integração sejam evitadas.

---

## Estrutura principal

```text
.
├── .github/
│   └── workflows/
│       ├── branch-flow.yml
│       ├── terraform-plan.yml
│       └── terraform-apply.yml
│
├── docs/
│   ├── architecture/
│   │   ├── architecture.md
│   │   ├── component-diagram.md
│   │   └── authentication-der.md
│   │
│   ├── rfcs/
│   │   ├── RFC-001-repositorio-dedicado.md
│   │   ├── RFC-002-rds-postgresql.md
│   │   └── RFC-003-secrets-e-cicd.md
│   │
│   └── video/
│       └── roteiro.md
│
├── modules/
│   └── rds/
│
├── backend.tf
├── main.tf
├── outputs.tf
├── providers.tf
├── terraform.tfvars.example
├── variables.tf
└── versions.tf
```

---

## Documentação

A documentação complementar está disponível nos seguintes arquivos:

- [Documentação arquitetural](docs/architecture/architecture.md)
- [Diagrama de componentes](docs/architecture/component-diagram.md)
- [DER de autenticação](docs/architecture/authentication-der.md)
- [RFC-001 — Repositório dedicado](docs/rfcs/RFC-001-repositorio-dedicado.md)
- [RFC-002 — PostgreSQL no Amazon RDS](docs/rfcs/RFC-002-rds-postgresql.md)
- [RFC-003 — Secrets e pipeline Terraform](docs/rfcs/RFC-003-secrets-e-cicd.md)
- [Roteiro de apoio ao vídeo](docs/video/roteiro.md)

---

## Decisões para o ambiente acadêmico

Algumas configurações foram escolhidas especificamente para o contexto acadêmico:

- instância `db.t4g.micro`;
- Single-AZ;
- `deletion_protection = false`;
- `skip_final_snapshot = true`;
- credenciais temporárias do AWS Academy;
- acesso ao PostgreSQL restrito ao Security Group do EKS compartilhado.

Essas decisões priorizam simplicidade, compatibilidade com o AWS Academy e controle de recursos.

---

## Recomendações para produção

Para uma implantação produtiva real, recomenda-se avaliar:

- Multi-AZ;
- deletion protection;
- snapshots finais antes da exclusão;
- política formal de backup e recuperação;
- Performance Insights;
- métricas e alarmes no Amazon CloudWatch;
- Security Group exclusivo da aplicação como origem;
- autenticação GitHub Actions através de OIDC;
- IAM Roles com princípio do menor privilégio;
- políticas de rotação e gestão de credenciais;
- estratégia formal de disaster recovery.

---

## Segurança

Nunca devem ser versionados:

- Access Key AWS;
- Secret Access Key AWS;
- Session Token;
- senha do PostgreSQL;
- conteúdo do AWS Secrets Manager;
- arquivos locais contendo credenciais.

A senha master do banco é gerenciada pelo Amazon RDS através do AWS Secrets Manager, enquanto as credenciais utilizadas pelo pipeline acadêmico são armazenadas como GitHub Actions Secrets.

---

## Projeto acadêmico

Infraestrutura desenvolvida como parte da Pós-Graduação FIAP — PosTech, utilizando práticas de:

- Infrastructure as Code;
- Terraform;
- Amazon RDS;
- PostgreSQL;
- AWS Secrets Manager;
- GitHub Actions;
- CI/CD;
- documentação arquitetural;
- registro de decisões através de RFCs.
