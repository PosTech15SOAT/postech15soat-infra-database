# Roteiro de apoio ao vídeo

## Objetivo
Apresentar de forma curta e demonstrável a separação da infraestrutura do banco, as decisões arquiteturais e o fluxo de provisionamento.

## Sequência sugerida

### 1. Contexto e problema
- Mostrar rapidamente o `PosTech15SOAT-V2` e explicar que banco, EKS, ECR e rede estavam no mesmo conjunto de infraestrutura.
- Explicar a diretiva de criar um repositório dedicado ao banco.

### 2. Nova arquitetura
- Abrir `docs/architecture/component-diagram.md`.
- Destacar que a VPC não foi duplicada.
- Explicar que `vpc_id` e `subnet_ids` são fornecidos ao Terraform por variáveis.
- Mostrar que o state do banco é independente e armazenado em S3.

### 3. RDS e segurança
- Abrir `modules/rds/main.tf`.
- Mostrar PostgreSQL 17, subnets privadas, criptografia e Security Group.
- Destacar o Parameter Group e o `rds.force_ssl`.
- Explicar que a senha master é gerenciada pelo RDS no AWS Secrets Manager e não existe em `tfvars`.

### 4. CI/CD
- Mostrar `terraform-plan.yml` e `terraform-apply.yml`.
- Explicar o fluxo `feature/* → develop → main`.
- Explicar que Pull Requests executam `fmt`, `validate` e `plan`.
- Explicar que a `main` executa o `apply`.
- Informar que o AWS Academy utiliza credenciais temporárias cadastradas como GitHub Actions Secrets.
- Citar OIDC apenas como recomendação para ambiente produtivo real.
  
### 5. Arquitetura e RFCs
- Mostrar rapidamente as três RFCs.
- Explicar por que as decisões foram registradas e quais trade-offs foram assumidos para um ambiente acadêmico.

### 6. DER de autenticação
- Abrir `docs/architecture/authentication-der.md`.
- Mostrar `admin_users`, `username`, `password_hash`, `role` e `enabled`.
- Explicar que a autenticação administrativa permanece desacoplada das entidades de negócio.

### 7. Encerramento
- Reforçar ganhos: separação de responsabilidades, segurança de credenciais, rastreabilidade de mudanças e possibilidade de evolução independente.

## Demonstração opcional
Executar em terminal:

```bash
terraform init
terraform fmt -check -recursive
terraform validate
terraform plan
```

Evite exibir valores sensíveis, conteúdo do Secrets Manager ou credenciais durante a gravação.
