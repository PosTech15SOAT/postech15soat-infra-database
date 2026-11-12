resource "aws_secretsmanager_secret" "billing_database" {
  name        = "${var.project_name}-billing-database"
  description = "Credenciais PostgreSQL exclusivas do Billing"
}
