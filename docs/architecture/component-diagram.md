# Diagrama de Componentes

```mermaid
flowchart LR
    DEV[Desenvolvedor] --> GH[GitHub Repository]
    GH --> GA[GitHub Actions]
    GA --> TF[Terraform]

    SECRETS_GH[GitHub Actions Secrets<br/>AWS Academy] --> GA

    TF --> S3_DB[(S3<br/>database/terraform.tfstate)]
    TF --> S3_CLOUD[(S3<br/>cloud/terraform.tfstate)]

    S3_CLOUD --> VPC[VPC<br/>infra-cloud]
    S3_CLOUD --> SUBNETS[Private Subnets<br/>infra-cloud]
    S3_CLOUD --> EKS_SG[EKS Cluster SG<br/>infra-cloud]

    TF --> PG[RDS Parameter Group]
    TF --> SG[Security Group RDS]
    TF --> RDS[(Amazon RDS<br/>PostgreSQL 17.5)]

    RDS --> SECRET[AWS Secrets Manager<br/>Master Credentials]

    VPC --> SG
    SUBNETS --> RDS
    PG --> RDS
    SG --> RDS

    APP[EKS / Aplicação Spring Boot] --> EKS_SG
    EKS_SG -->|TCP 5432| SG
```

## Responsabilidades

- **postech15soat-infra-database**: ciclo de vida do RDS, DB Subnet Group, Parameter Group, Security Group, state do banco e integração com Secrets Manager.
- **postech15soat-infra-cloud**: VPC, subnets privadas e Security Group do EKS publicados via remote state.
- **GitHub Actions**: validação, plano e aplicação controlada do Terraform.
- **AWS Secrets Manager**: armazenamento das credenciais master gerenciadas pelo próprio RDS.
