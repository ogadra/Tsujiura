data "aws_route53_zone" "tsujiura" {
  name = local.domain_name
}

resource "aws_cloudwatch_log_group" "route53_query_log" {
  # checkov:skip=CKV_AWS_158:KMS encryption is not required for this use case
  # checkov:skip=CKV_AWS_338:Query logs only feed the ingest Lambda, so one day of retention is enough
  provider = aws.use1

  name              = "/aws/route53/${local.domain_name}"
  retention_in_days = 1

  tags = local.common_tags
}

data "aws_iam_policy_document" "route53_query_log" {
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["${aws_cloudwatch_log_group.route53_query_log.arn}:*"]

    principals {
      type        = "Service"
      identifiers = ["route53.amazonaws.com"]
    }
  }
}

resource "aws_cloudwatch_log_resource_policy" "route53_query_log" {
  # checkov:skip=CKV_TSUJIURA_1:Resource does not support tags
  provider = aws.use1

  policy_name     = "tsujiura-route53-query-log"
  policy_document = data.aws_iam_policy_document.route53_query_log.json
}

resource "aws_route53_query_log" "tsujiura" {
  # checkov:skip=CKV_TSUJIURA_1:Resource does not support tags
  depends_on = [aws_cloudwatch_log_resource_policy.route53_query_log]

  cloudwatch_log_group_arn = aws_cloudwatch_log_group.route53_query_log.arn
  zone_id                  = data.aws_route53_zone.tsujiura.zone_id
}
