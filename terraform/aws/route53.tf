resource "aws_route53_query_log" "tsujiura" {
  depends_on = [aws_cloudwatch_log_resource_policy.route53_query_log]

  cloudwatch_log_group_arn = aws_cloudwatch_log_group.route53_query_log.arn
  zone_id                  = data.aws_route53_zone.tsujiura.zone_id
}
