locals {
  common_tags = {
    Project     = var.project_name
    ManagedBy   = "Terraform"
    Repository  = "PosTech15SOAT-Infra-Banco"
    Environment = var.environment
  }
}
