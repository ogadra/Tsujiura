resource "aws_dynamodb_table" "results" {
  # checkov:skip=CKV_AWS_28:Results expire through TTL one day after the query
  # checkov:skip=CKV_AWS_119:AWS managed encryption is sufficient for this use case
  name         = "tsujiura-results"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "token"

  attribute {
    name = "token"
    type = "S"
  }

  ttl {
    attribute_name = "expiresAt"
    enabled        = true
  }

  tags = local.common_tags
}
