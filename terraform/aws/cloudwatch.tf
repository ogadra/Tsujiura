resource "aws_cloudwatch_log_group" "route53_query_log" {
  # checkov:skip=CKV_AWS_158:KMS encryption is not required for this use case
  # checkov:skip=CKV_AWS_338:Query logs only feed the ingest Lambda, so one day of retention is enough
  provider = aws.use1

  name              = "/aws/route53/${local.domain_name}"
  retention_in_days = 1

  tags = local.common_tags
}

resource "aws_cloudwatch_log_resource_policy" "route53_query_log" {
  # checkov:skip=CKV_TSUJIURA_1:Resource does not support tags
  provider = aws.use1

  policy_name     = "tsujiura-route53-query-log"
  policy_document = data.aws_iam_policy_document.route53_query_log.json
}

resource "aws_cloudwatch_log_subscription_filter" "ingest_route53" {
  # checkov:skip=CKV_TSUJIURA_1:Resource does not support tags
  provider   = aws.use1
  depends_on = [aws_lambda_permission.ingest_route53]

  name            = "tsujiura-ingest-route53"
  log_group_name  = aws_cloudwatch_log_group.route53_query_log.name
  filter_pattern  = ""
  destination_arn = data.aws_lambda_function.ingest_route53.arn
}
