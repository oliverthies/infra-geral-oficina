# ==================== DynamoDB — Billing Service (NoSQL Fase 4) ====================
# Access patterns:
#   PK = QUOTE#<quoteId> | PAYMENT#<paymentId>
#   SK = META | ITEM#<n> | EVENT#<ts>
#   GSI1: serviceOrderId → listar quotes/payments de uma OS

resource "aws_dynamodb_table" "billing" {
  name         = "${var.project_name}-billing"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "pk"
  range_key    = "sk"

  attribute {
    name = "pk"
    type = "S"
  }

  attribute {
    name = "sk"
    type = "S"
  }

  attribute {
    name = "gsi1pk"
    type = "S"
  }

  attribute {
    name = "gsi1sk"
    type = "S"
  }

  global_secondary_index {
    name            = "gsi1"
    hash_key        = "gsi1pk"
    range_key       = "gsi1sk"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = false
  }

  tags = merge(local.common_tags, {
    Name    = "${var.project_name}-billing"
    Service = "billing"
    Phase   = "4"
  })
}
