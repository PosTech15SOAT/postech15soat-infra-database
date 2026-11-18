module "maintenance_history" {
  source = "./modules/maintenance-history"

  providers = {
    aws          = aws
    aws.untagged = aws.untagged
  }

  name_prefix = "${var.project_name}-${var.environment}"
  tags        = local.common_tags
}

output "maintenance_history_table_name" {
  description = "Nome da tabela do histórico veicular."
  value       = module.maintenance_history.table_name
}

output "maintenance_history_table_arn" {
  description = "ARN da tabela do histórico veicular."
  value       = module.maintenance_history.table_arn
}

output "maintenance_history_os_policy_arn" {
  description = "Policy de menor privilégio para integração direta com DynamoDB."
  value       = module.maintenance_history.policy_arn
}
