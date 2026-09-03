terraform {
  backend "s3" {
    key    = "database/terraform.tfstate"
    region = "us-east-1"
  }
}
