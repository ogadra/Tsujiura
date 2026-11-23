resource "aws_cloudwatch_log_group" "route53_query_log" {
  provider = aws.use1

  name              = "/aws/route53/${local.domain_name}"
  retention_in_days = 1
}

resource "aws_cloudwatch_log_resource_policy" "route53_query_log" {
  provider = aws.use1

  policy_name     = "tsujiura-route53-query-log"
  policy_document = data.aws_iam_policy_document.route53_query_log.json
}

resource "aws_cloudwatch_log_subscription_filter" "ingest_route53" {
  provider   = aws.use1
  depends_on = [aws_lambda_permission.ingest_route53]

  name            = "tsujiura-ingest-route53"
  log_group_name  = aws_cloudwatch_log_group.route53_query_log.name
  filter_pattern  = ""
  destination_arn = data.aws_lambda_function.ingest_route53.arn
}
