resource "aws_secretsmanager_secret" "billing_database" {
  name        = "${var.project_name}-billing-database"
  description = "Credenciais PostgreSQL exclusivas do Billing"
}

resource "aws_secretsmanager_secret" "os_database" {
  name        = "${var.project_name}-os-database"
  description = "Credenciais PostgreSQL exclusivas da OS"
}

resource "aws_secretsmanager_secret" "inventory_database" {
  name        = "${var.project_name}-inventory-database"
  description = "Credenciais PostgreSQL exclusivas do Inventory"
}
