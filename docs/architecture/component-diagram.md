# Diagrama de Componentes

```mermaid
flowchart LR
    DEV[Desenvolvedor] --> GH[GitHub Repository\nPosTech15SOAT-Infra-Banco]
    GH --> GA[GitHub Actions]
    GA --> OIDC[GitHub OIDC]
    OIDC --> IAM[AWS IAM Role]
    GA --> TF[Terraform]

    TF --> S3[(S3 Terraform State\ninfra-banco/terraform.tfstate)]
    TF --> NETSTATE[(Remote State da Rede\ninfra/terraform.tfstate)]
    NETSTATE --> VPC[VPC existente]
    NETSTATE --> SUBNETS[Private Subnets existentes]

    TF --> PG[RDS Parameter Group]
    TF --> SG[Security Group RDS]
    TF --> RDS[(Amazon RDS\nPostgreSQL 17.5)]
    RDS --> SECRET[AWS Secrets Manager\nMaster credentials gerenciadas]

    VPC --> SG
    SUBNETS --> RDS
    PG --> RDS
    SG --> RDS

    APP[Aplicação / EKS] -->|TCP 5432| SG
    APP -->|Obtém credenciais autorizadas| SECRET
```

## Responsabilidades

- **PosTech15SOAT-Infra-Banco**: ciclo de vida do RDS, Parameter Group, Security Group e integração com Secrets Manager.
- **Infraestrutura principal**: VPC e subnets privadas consumidas por remote state.
- **GitHub Actions**: validação, plano e aplicação controlada do Terraform.
- **AWS Secrets Manager**: armazenamento das credenciais master gerenciadas pelo próprio RDS.
