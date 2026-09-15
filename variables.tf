variable "aws_region" {
  description = "Região AWS utilizada pelos recursos."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nome base utilizado na identificação dos recursos."
  type        = string
  default     = "numberone"
}

variable "environment" {
  description = "Ambiente lógico da infraestrutura."
  type        = string
  default     = "lab"
}

variable "cloud_state_bucket" {
  description = "Bucket S3 que armazena o state do repositório postech15soat-infra-cloud."
  type        = string

  validation {
    condition     = length(trimspace(var.cloud_state_bucket)) > 0
    error_message = "Informe o bucket que contém o state da infraestrutura cloud."
  }
}

variable "cloud_state_key" {
  description = "Chave do state Terraform da infraestrutura cloud."
  type        = string
  default     = "cloud/terraform.tfstate"
}

variable "db_name" {
  description = "Nome inicial do banco PostgreSQL."
  type        = string
  default     = "numberone"
}

variable "db_username" {
  description = "Usuário master do RDS. A senha é gerenciada pelo RDS no AWS Secrets Manager."
  type        = string
  default     = "numberone_admin"
}

variable "db_instance_class" {
  description = "Classe da instância RDS."
  type        = string
  default     = "db.t4g.micro"
}

variable "db_allocated_storage" {
  description = "Armazenamento inicial em GiB."
  type        = number
  default     = 20
}

variable "db_max_allocated_storage" {
  description = "Limite de autoscaling do armazenamento em GiB."
  type        = number
  default     = 100
}

variable "deletion_protection" {
  description = "Proteção contra exclusão acidental do RDS."
  type        = bool
  default     = false
}

variable "backup_retention_period" {
  description = "Quantidade de dias de retenção de backups automáticos."
  type        = number
  default     = 7
}
