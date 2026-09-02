# Documentação Arquitetural

## Visão geral

A infraestrutura do banco de dados foi separada em um repositório dedicado com o objetivo de reduzir o acoplamento com a infraestrutura da aplicação, permitir evolução independente e tornar o ciclo de provisionamento do Amazon RDS mais simples, auditável e seguro.

Este repositório é responsável exclusivamente pelos componentes relacionados ao banco PostgreSQL e reutiliza recursos de rede já existentes na conta AWS.

A infraestrutura é provisionada utilizando Terraform e possui state independente armazenado em Amazon S3.

---

## Contexto

O projeto PosTech15SOAT utiliza uma infraestrutura já existente na AWS contendo VPC e subnets distribuídas em múltiplas zonas de disponibilidade.

O repositório de banco não recria esses recursos.

Os identificadores da infraestrutura de rede são fornecidos ao Terraform através de variáveis:

- `vpc_id`;
- `subnet_ids`.

Essa abordagem evita duplicação de recursos e permite reutilizar a infraestrutura de rede existente.

No ambiente acadêmico atual são utilizados:

- região AWS: `us-east-1`;
- VPC existente: `vpc-0764754eefab31378`;
- CIDR da VPC: `172.31.0.0/16`;
- quatro subnets existentes em diferentes zonas de disponibilidade.

---

## Componentes da arquitetura

A infraestrutura é composta pelos seguintes elementos:

- Amazon RDS for PostgreSQL;
- DB Subnet Group;
- Security Group dedicado ao banco;
- DB Parameter Group customizado;
- AWS Secrets Manager;
- Amazon S3 para armazenamento do Terraform State;
- GitHub Actions para CI/CD;
- VPC e subnets existentes.

O relacionamento entre esses componentes está representado em:

`docs/architecture/component-diagram.md`

---

## Amazon RDS PostgreSQL

O banco de dados é provisionado através do Amazon RDS utilizando PostgreSQL.

A configuração atual utiliza:

- engine: PostgreSQL;
- versão: `17.5`;
- classe: `db.t4g.micro`;
- armazenamento inicial: `20 GiB`;
- limite de autoscaling: `100 GiB`;
- tipo de armazenamento: `gp3`;
- criptografia de armazenamento habilitada;
- Single-AZ;
- acesso público desabilitado;
- backups automáticos;
- retenção de backup de 7 dias;
- atualização automática de versões menores;
- aplicação imediata das alterações.

A utilização de Single-AZ e da classe `db.t4g.micro` foi escolhida devido ao contexto acadêmico, priorizando simplicidade e menor utilização de recursos.

Em um ambiente produtivo, recomenda-se avaliar configurações com maior disponibilidade e resiliência.

---

## DB Subnet Group

O Amazon RDS utiliza um DB Subnet Group criado pelo Terraform.

As subnets utilizadas são recebidas através da variável:

```hcl
subnet_ids
```

O módulo exige pelo menos duas subnets, permitindo que o RDS seja associado a subnets distribuídas em diferentes zonas de disponibilidade.

A infraestrutura não cria novas subnets.

---

## Segurança de rede

O Amazon RDS possui um Security Group dedicado.

A porta utilizada pelo PostgreSQL é:

```text
TCP 5432
```

O modelo de segurança preferencial permite acesso ao banco somente a partir do Security Group da aplicação.

Esse Security Group pode ser informado através da variável:

```hcl
application_security_group_id
```

Quando esse identificador está disponível, é criada uma regra permitindo acesso à porta TCP 5432 somente a partir do Security Group informado.

No ambiente acadêmico atual, o Security Group da aplicação ainda não está disponível como entrada para essa infraestrutura.

Por esse motivo, existe um fallback temporário que permite conexões provenientes do CIDR da própria VPC.

O CIDR é obtido automaticamente a partir da VPC existente através do Terraform.

No ambiente atual:

```text
172.31.0.0/16
```

Esse fallback permite comunicação entre recursos localizados dentro da VPC sem tornar o banco publicamente acessível.

Em um ambiente produtivo, recomenda-se remover o fallback por CIDR e permitir acesso exclusivamente ao Security Group da aplicação.

---

## DB Parameter Group

Foi criado um DB Parameter Group customizado para PostgreSQL 17.

Os parâmetros configurados são:

| Parâmetro | Valor | Finalidade |
|---|---:|---|
| `rds.force_ssl` | `1` | Exigir conexões SSL/TLS |
| `log_connections` | `1` | Registrar conexões realizadas |
| `log_disconnections` | `1` | Registrar desconexões |
| `log_min_duration_statement` | `1000` | Registrar consultas com duração superior a 1 segundo |

O parâmetro `rds.force_ssl` aumenta a segurança ao exigir comunicação criptografada entre clientes e o PostgreSQL.

Os parâmetros de log aumentam a observabilidade e facilitam análise e diagnóstico de comportamento do banco.

---

## Gestão de credenciais do banco

A senha master do PostgreSQL não é definida diretamente no Terraform, em arquivos `tfvars` ou no GitHub Actions.

A instância utiliza:

```hcl
manage_master_user_password = true
```

Com essa configuração, o próprio Amazon RDS:

1. gera a senha master;
2. armazena a credencial no AWS Secrets Manager;
3. associa o secret à instância RDS;
4. gerencia o armazenamento seguro da credencial.

Dessa forma, a senha do banco não precisa ser versionada ou configurada manualmente na pipeline.

O Terraform disponibiliza apenas a referência ao secret através de output apropriado.

---

## AWS Secrets Manager

O AWS Secrets Manager é utilizado para armazenar a credencial master gerenciada pelo Amazon RDS.

Essa decisão reduz o risco de exposição de credenciais porque:

- nenhuma senha do banco é armazenada no código-fonte;
- nenhuma senha é colocada em `terraform.tfvars`;
- nenhuma senha do PostgreSQL é armazenada em GitHub Actions Secrets;
- o acesso ao secret pode ser controlado através de permissões IAM.

Em produção, recomenda-se aplicar políticas de acesso com princípio do menor privilégio.

---

## Terraform State

A infraestrutura do banco possui state Terraform independente.

O backend utilizado é Amazon S3.

Configuração atual:

```text
Bucket: postech15soat-infra-banco-tfstate-777137014941
Key:    infra-banco/terraform.tfstate
Region: us-east-1
```

O bucket possui:

- versionamento habilitado;
- bloqueio de acesso público habilitado.

A separação do state permite que alterações relacionadas ao banco sejam executadas independentemente da infraestrutura da aplicação.

Essa decisão também reduz o impacto potencial de alterações e facilita o gerenciamento do ciclo de vida dos recursos.

---

## Terraform

O Terraform é responsável pelo provisionamento e gerenciamento dos recursos de banco.

Os principais arquivos utilizados são:

```text
backend.tf
main.tf
variables.tf
outputs.tf
providers.tf
versions.tf
terraform.tfvars.example
modules/rds/
```

O módulo `modules/rds` concentra a implementação dos recursos relacionados ao banco.

Entre os recursos provisionados estão:

- `aws_security_group`;
- regras de ingress e egress;
- `aws_db_subnet_group`;
- `aws_db_parameter_group`;
- `aws_db_instance`.

---

## Variáveis de infraestrutura

As principais entradas relacionadas à rede são:

```hcl
vpc_id
subnet_ids
application_security_group_id
```

As principais entradas relacionadas ao banco são:

```hcl
db_name
db_username
db_instance_class
db_allocated_storage
db_max_allocated_storage
backup_retention_period
deletion_protection
```

O arquivo:

```text
terraform.tfvars.example
```

contém um exemplo de configuração para o ambiente acadêmico atual.

Nenhuma senha do banco deve ser incluída nesse arquivo.

---

## CI/CD

O repositório utiliza GitHub Actions para validação e provisionamento da infraestrutura.

O fluxo de branches adotado é:

```text
feature/* → develop → main
```

Alterações são desenvolvidas em branches `feature/*` e promovidas através de Pull Requests.

---

## Terraform Plan

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
terraform fmt -check -recursive
terraform validate
terraform plan
```

Esse processo permite detectar erros de sintaxe, formatação, configuração e alterações de infraestrutura antes do merge.

---

## Promoção para main

Pull Requests destinados à branch `main` devem possuir como origem a branch:

```text
develop
```

Esse comportamento é validado pelo workflow:

```text
.github/workflows/branch-flow.yml
```

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

Isso reduz a possibilidade de alterações de infraestrutura serem promovidas diretamente para `main` sem passar pela etapa de integração.

---

## Terraform Apply

Quando uma alteração é integrada à branch `main`, o workflow:

```text
.github/workflows/terraform-apply.yml
```

executa o provisionamento da infraestrutura.

O apply utiliza:

```bash
terraform apply -input=false -auto-approve -var-file=terraform.tfvars.example
```

Dessa forma:

- Pull Requests executam validação e `terraform plan`;
- alterações promovidas para `main` executam `terraform apply`.

---

## Autenticação AWS no pipeline

O ambiente atual utiliza AWS Academy.

Nesse contexto, o GitHub Actions autentica na AWS utilizando credenciais temporárias disponibilizadas pela sessão do laboratório.

As credenciais são cadastradas como GitHub Actions Secrets:

```text
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
AWS_SESSION_TOKEN
```

Essas credenciais possuem tempo de expiração.

Quando uma nova sessão do AWS Academy é iniciada, pode ser necessário atualizar os Secrets no GitHub.

Nenhuma credencial AWS deve ser armazenada diretamente no código-fonte, arquivos Terraform ou documentação.

---

## Evolução da autenticação para produção

A utilização de credenciais temporárias do AWS Academy atende às limitações do ambiente acadêmico.

Em um ambiente corporativo ou produtivo, recomenda-se utilizar autenticação federada através de:

```text
GitHub Actions
      |
      v
GitHub OIDC
      |
      v
AWS IAM Role
```

Esse modelo elimina a necessidade de armazenar Access Keys no GitHub e permite controlar as permissões através de uma IAM Role dedicada.

OIDC é, portanto, uma recomendação de evolução e não faz parte da arquitetura atualmente utilizada no AWS Academy.

---

## Proteção das branches

As branches de integração possuem regras de proteção.

Atualmente são utilizadas as regras:

- `Protected integration branches`;
- `Require develop promotion`;
- `Required CI checks`.

Essas regras garantem que:

- alterações sejam integradas através de Pull Requests;
- `main` receba alterações provenientes de `develop`;
- verificações obrigatórias sejam executadas;
- alterações diretas nas branches principais sejam evitadas.

---

## Disponibilidade

A configuração atual utiliza Single-AZ.

Essa decisão é adequada ao ambiente acadêmico porque reduz complexidade e utilização de recursos.

Para uma infraestrutura de produção, recomenda-se avaliar:

- Multi-AZ;
- réplicas de leitura quando aplicável;
- políticas formais de backup;
- estratégias de disaster recovery;
- testes periódicos de restauração.

---

## Backup

O Amazon RDS possui backups automáticos com retenção configurada em:

```text
7 dias
```

Para o ambiente acadêmico atual:

```hcl
skip_final_snapshot = true
```

Essa configuração simplifica a exclusão dos recursos durante testes.

Em produção, recomenda-se:

- utilizar snapshot final;
- aumentar a retenção conforme os requisitos do negócio;
- definir políticas formais de backup e recuperação;
- testar restaurações periodicamente.

---

## Proteção contra exclusão

No ambiente acadêmico:

```hcl
deletion_protection = false
```

Isso facilita a criação e remoção dos recursos durante a execução do projeto.

Para produção, recomenda-se habilitar:

```hcl
deletion_protection = true
```

para reduzir o risco de exclusão acidental da instância.

---

## Observabilidade

O Parameter Group habilita logs de:

- conexões;
- desconexões;
- consultas com duração superior a 1 segundo.

Para ambientes produtivos, a arquitetura pode ser complementada com:

- Amazon CloudWatch;
- alarmes de utilização de CPU;
- alarmes de armazenamento;
- monitoramento de conexões;
- Performance Insights;
- métricas de latência;
- alertas relacionados a falhas e disponibilidade.

---

## Considerações de custo

A arquitetura atual foi dimensionada para um ambiente acadêmico.

As principais decisões para reduzir utilização de recursos são:

- instância `db.t4g.micro`;
- Single-AZ;
- armazenamento inicial de 20 GiB;
- ausência de réplicas;
- deletion protection desabilitada;
- ausência de componentes adicionais de alta disponibilidade.

Essas decisões não representam necessariamente a configuração recomendada para um ambiente produtivo.

---

## Segurança

A arquitetura segue os seguintes princípios:

- banco sem acesso público;
- comunicação PostgreSQL através da porta TCP 5432;
- SSL/TLS obrigatório;
- armazenamento criptografado;
- credencial master gerenciada pelo Secrets Manager;
- ausência de senha do banco em arquivos versionados;
- credenciais AWS armazenadas apenas em GitHub Actions Secrets no contexto acadêmico;
- isolamento da infraestrutura do banco em state próprio;
- validação de alterações através de Pull Requests.

---

## Decisões arquiteturais

As principais decisões estão documentadas através das RFCs:

- `RFC-001` — Repositório dedicado para infraestrutura do banco;
- `RFC-002` — PostgreSQL no Amazon RDS;
- `RFC-003` — Secrets e pipeline Terraform.

Os documentos estão disponíveis em:

```text
docs/rfcs/
```

---

## DER de autenticação

A documentação do modelo de autenticação administrativa está disponível em:

```text
docs/architecture/authentication-der.md
```

A autenticação utiliza a entidade:

```text
admin_users
```

contendo:

- identificador UUID;
- username único;
- hash da senha;
- role;
- status enabled;
- data de criação.

A entidade de autenticação permanece desacoplada das entidades de negócio.

---

## Trade-offs

A solução atual prioriza simplicidade e compatibilidade com o ambiente AWS Academy.

Os principais trade-offs são:

### Single-AZ

Reduz a utilização de recursos, porém não oferece a mesma disponibilidade de uma implantação Multi-AZ.

### Credenciais temporárias AWS Academy

Atendem ao ambiente acadêmico, porém exigem atualização periódica dos GitHub Actions Secrets.

### Fallback por CIDR da VPC

Permite comunicação enquanto o Security Group da aplicação não está disponível, porém é menos restritivo que permitir acesso exclusivamente pelo Security Group da aplicação.

### Deletion protection desabilitada

Facilita testes e destruição do ambiente acadêmico, porém não seria recomendada em produção.

---

## Evoluções recomendadas

Para uma arquitetura produtiva, recomenda-se avaliar:

- Multi-AZ;
- deletion protection;
- snapshot final;
- política formal de backup e restauração;
- Performance Insights;
- alarmes no CloudWatch;
- Security Group exclusivo da aplicação;
- remoção do fallback por CIDR da VPC;
- GitHub OIDC;
- IAM Role com princípio do menor privilégio;
- maior controle de acesso ao AWS Secrets Manager;
- estratégia formal de disaster recovery;
- monitoramento contínuo de disponibilidade e desempenho.

---

## Resultado arquitetural

A solução final mantém o banco PostgreSQL desacoplado da infraestrutura principal e utiliza componentes gerenciados da AWS.

A arquitetura resultante oferece:

- infraestrutura do banco independente;
- state Terraform próprio;
- reaproveitamento da rede existente;
- banco PostgreSQL privado;
- criptografia de armazenamento;
- SSL/TLS obrigatório;
- credenciais de banco protegidas pelo AWS Secrets Manager;
- CI/CD através de GitHub Actions;
- fluxo controlado de promoção entre branches;
- rastreabilidade das alterações;
- documentação das principais decisões técnicas.

Essa arquitetura atende ao contexto acadêmico atual e mantém um caminho de evolução claro para uma implantação produtiva.
