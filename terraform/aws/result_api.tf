data "aws_caller_identity" "current" {}

resource "aws_ecr_repository" "result_api" {
  # checkov:skip=CKV_AWS_136:AWS managed encryption is sufficient
  # checkov:skip=CKV_AWS_51:Redeploying a commit pushes its short SHA tag again
  name = "tsujiura-result-api"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = local.common_tags
}

resource "aws_iam_role" "result_api" {
  name               = "tsujiura-result-api"
  assume_role_policy = data.aws_iam_policy_document.ingest_route53_assume.json

  tags = local.common_tags
}

data "aws_iam_policy_document" "result_api" {
  statement {
    actions   = ["dynamodb:GetItem"]
    resources = [aws_dynamodb_table.results.arn]
  }
}

resource "aws_iam_role_policy" "result_api" {
  # checkov:skip=CKV_TSUJIURA_1:Resource does not support tags
  name   = "read-results"
  role   = aws_iam_role.result_api.id
  policy = data.aws_iam_policy_document.result_api.json
}

resource "aws_iam_role_policy_attachment" "result_api_logs" {
  # checkov:skip=CKV_TSUJIURA_1:Resource does not support tags
  role       = aws_iam_role.result_api.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

output "result_api_repository_url" {
  value = aws_ecr_repository.result_api.repository_url
}

# terraform/google-cloud takes this as result_api_assumed_role_arn.
output "result_api_assumed_role_arn" {
  value = "arn:aws:sts::${data.aws_caller_identity.current.account_id}:assumed-role/${aws_iam_role.result_api.name}"
}
