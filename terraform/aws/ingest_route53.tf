resource "aws_ecr_repository" "ingest_route53" {
  provider = aws.use1

  name = "tsujiura-ingest-route53"
}

data "aws_iam_policy_document" "ingest_route53_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ingest_route53" {
  name               = "tsujiura-ingest-route53"
  assume_role_policy = data.aws_iam_policy_document.ingest_route53_assume.json
}

data "aws_iam_policy_document" "ingest_route53" {
  statement {
    actions   = ["dynamodb:PutItem"]
    resources = [aws_dynamodb_table.results.arn]
  }
}

resource "aws_iam_role_policy" "ingest_route53" {
  name   = "put-results"
  role   = aws_iam_role.ingest_route53.id
  policy = data.aws_iam_policy_document.ingest_route53.json
}

resource "aws_iam_role_policy_attachment" "ingest_route53_logs" {
  role       = aws_iam_role.ingest_route53.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# lambroll owns the function, so it must be deployed before this can be read.
data "aws_lambda_function" "ingest_route53" {
  provider = aws.use1

  function_name = "tsujiura-ingest-route53"
}

resource "aws_lambda_permission" "ingest_route53" {
  provider = aws.use1

  action        = "lambda:InvokeFunction"
  function_name = data.aws_lambda_function.ingest_route53.function_name
  principal     = "logs.amazonaws.com"
  source_arn    = "${aws_cloudwatch_log_group.route53_query_log.arn}:*"
}

resource "aws_cloudwatch_log_subscription_filter" "ingest_route53" {
  provider   = aws.use1
  depends_on = [aws_lambda_permission.ingest_route53]

  name            = "tsujiura-ingest-route53"
  log_group_name  = aws_cloudwatch_log_group.route53_query_log.name
  filter_pattern  = ""
  destination_arn = data.aws_lambda_function.ingest_route53.arn
}

output "ingest_route53_repository_url" {
  value = aws_ecr_repository.ingest_route53.repository_url
}
