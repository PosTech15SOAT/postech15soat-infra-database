variable "name_prefix" {
  type        = string
  description = "Prefixo do projeto e ambiente."
}

variable "tags" {
  type        = map(string)
  description = "Tags compartilhadas do Database."
}

resource "aws_dynamodb_table" "this" {
  name         = "${var.name_prefix}-vehicle-maintenance-history"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "vehicleId"
  range_key    = "historyKey"

  attribute {
    name = "vehicleId"
    type = "S"
  }

  attribute {
    name = "historyKey"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = merge(var.tags, {
    Name      = "${var.name_prefix}-vehicle-maintenance-history"
    Component = "service-order-history"
  })
}

data "aws_iam_policy_document" "os_history" {
  statement {
    sid       = "ServiceOrderMaintenanceHistory"
    actions   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:Query"]
    resources = [aws_dynamodb_table.this.arn]
  }
}

resource "aws_iam_policy" "os_history" {
  name        = "${var.name_prefix}-os-maintenance-history"
  description = "Permite à identidade da OS projetar e consultar o histórico na tabela dedicada."
  policy      = data.aws_iam_policy_document.os_history.json
}

output "table_name" {
  value = aws_dynamodb_table.this.name
}

output "table_arn" {
  value = aws_dynamodb_table.this.arn
}

output "policy_arn" {
  value = aws_iam_policy.os_history.arn
}
