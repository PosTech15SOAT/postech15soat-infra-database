resource "aws_secretsmanager_secret" "auth_database" {
  name        = "${var.project_name}-auth-database"
  description = "Credenciais PostgreSQL exclusivas do Auth runtime"
}
