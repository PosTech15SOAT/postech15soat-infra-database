data "terraform_remote_state" "cloud" {
  backend = "s3"

  config = {
    bucket = var.cloud_state_bucket
    key    = var.cloud_state_key
    region = var.aws_region
  }
}

module "rds" {
  source = "./modules/rds"

  project_name = var.project_name
  environment  = var.environment

  vpc_id     = data.terraform_remote_state.cloud.outputs.vpc_id
  subnet_ids = data.terraform_remote_state.cloud.outputs.private_subnet_ids

  application_security_group_id = data.terraform_remote_state.cloud.outputs.eks_cluster_security_group_id

  db_name                 = var.db_name
  username                = var.db_username
  instance_class          = var.db_instance_class
  allocated_storage       = var.db_allocated_storage
  max_allocated_storage   = var.db_max_allocated_storage
  deletion_protection     = var.deletion_protection
  backup_retention_period = var.backup_retention_period
}
