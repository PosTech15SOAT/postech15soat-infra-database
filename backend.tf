terraform {
  backend "s3" {
    bucket = "postech15soat-infra-banco-tfstate-777137014941"
    key    = "infra-banco/terraform.tfstate"
    region = "us-east-1"
  }
}
