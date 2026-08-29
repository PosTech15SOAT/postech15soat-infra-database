module "rds" {
  source = "./modules/rds"

  project_name          = var.project_name
  vpc_id                = var.vpc_id
  private_subnet_ids    = var.private_subnet_ids
  allowed_cidr_blocks   = var.allowed_cidr_blocks
  db_name               = var.db_name
  username              = var.db_username
  password              = var.db_password
  instance_class        = var.db_instance_class
  allocated_storage     = var.db_allocated_storage
  backup_retention_days = var.backup_retention_days
  deletion_protection   = var.deletion_protection
  multi_az              = var.multi_az
  tags                  = local.common_tags
}
