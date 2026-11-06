resource "aws_dynamodb_table" "results" {
  name         = "tsujiura-results"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "token"

  attribute {
    name = "token"
    type = "S"
  }

  # The ingest Lambda writes expiresAt as epoch seconds, one day after the query.
  ttl {
    attribute_name = "expiresAt"
    enabled        = true
  }
}
