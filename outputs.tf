output "rds_endpoint" {
  description = "Endpoint do PostgreSQL no RDS."
  value       = module.rds.endpoint
}

output "rds_port" {
  description = "Porta do PostgreSQL."
  value       = module.rds.port
}

output "rds_identifier" {
  description = "Identificador da instância RDS."
  value       = module.rds.identifier
}

output "rds_security_group_id" {
  description = "Security Group associado ao RDS."
  value       = module.rds.security_group_id
}

output "rds_master_secret_arn" {
  description = "ARN do secret gerenciado pelo RDS no AWS Secrets Manager."
  value       = module.rds.master_secret_arn
  sensitive   = true
}

output "parameter_group_name" {
  description = "Parameter Group customizado utilizado pelo PostgreSQL."
  value       = module.rds.parameter_group_name
}

output "cloud_vpc_id" {
  description = "VPC compartilhada consumida do state da infraestrutura cloud."
  value       = data.terraform_remote_state.cloud.outputs.vpc_id
}

output "cloud_private_subnet_ids" {
  description = "Subnets privadas compartilhadas consumidas do state da infraestrutura cloud."
  value       = data.terraform_remote_state.cloud.outputs.private_subnet_ids
}

output "application_security_group_id" {
  description = "Security Group do EKS autorizado a acessar o PostgreSQL."
  value       = data.terraform_remote_state.cloud.outputs.eks_cluster_security_group_id
}
