data "aws_route53_zone" "tsujiura" {
  name = var.domain_name
}

resource "aws_cloudwatch_log_group" "route53_query_log" {
  provider = aws.use1

  name              = "/aws/route53/${var.domain_name}"
  retention_in_days = 1
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
  provider = aws.use1

  policy_name     = "tsujiura-route53-query-log"
  policy_document = data.aws_iam_policy_document.route53_query_log.json
}

resource "aws_route53_query_log" "tsujiura" {
  depends_on = [aws_cloudwatch_log_resource_policy.route53_query_log]

  cloudwatch_log_group_arn = aws_cloudwatch_log_group.route53_query_log.arn
  zone_id                  = data.aws_route53_zone.tsujiura.zone_id
}
