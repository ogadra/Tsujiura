resource "aws_ecr_repository" "result_api" {
  name = "tsujiura-result-api"
}

resource "aws_iam_role" "result_api" {
  name               = "tsujiura-result-api"
  assume_role_policy = data.aws_iam_policy_document.ingest_route53_assume.json
}

data "aws_iam_policy_document" "result_api" {
  statement {
    actions   = ["dynamodb:GetItem"]
    resources = [aws_dynamodb_table.results.arn]
  }
}

resource "aws_iam_role_policy" "result_api" {
  name   = "read-results"
  role   = aws_iam_role.result_api.id
  policy = data.aws_iam_policy_document.result_api.json
}

resource "aws_iam_role_policy_attachment" "result_api_logs" {
  role       = aws_iam_role.result_api.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

output "result_api_repository_url" {
  value = aws_ecr_repository.result_api.repository_url
}
