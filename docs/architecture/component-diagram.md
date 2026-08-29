# Diagrama de Componentes

# Diagrama de Componentes

```mermaid
flowchart LR
    DEV[Desenvolvedor] --> GH[GitHub Repository]
    GH --> GA[GitHub Actions]
    GA --> TF[Terraform]

    SECRETS_GH[GitHub Actions Secrets<br/>AWS Academy] --> GA

    TF --> S3[(S3<br/>Terraform State)]
    TF --> VPC[VPC existente]
    TF --> SUBNETS[Subnets existentes]

    TF --> PG[RDS Parameter Group]
    TF --> SG[Security Group RDS]
    TF --> RDS[(Amazon RDS<br/>PostgreSQL 17.5)]

    RDS --> SECRET[AWS Secrets Manager<br/>Master Credentials]

    VPC --> SG
    SUBNETS --> RDS
    PG --> RDS
    SG --> RDS

    APP[Aplicação / EKS] -->|TCP 5432| SG
```

## Responsabilidades

- **PosTech15SOAT-Infra-Banco**: ciclo de vida do RDS, Parameter Group, Security Group e integração com Secrets Manager.
- **Infraestrutura principal**: VPC e subnets privadas consumidas por remote state.
- **GitHub Actions**: validação, plano e aplicação controlada do Terraform.
- **AWS Secrets Manager**: armazenamento das credenciais master gerenciadas pelo próprio RDS.
