resource "aws_lambda_permission" "ingest_route53" {
  provider = aws.use1

  action        = "lambda:InvokeFunction"
  function_name = data.aws_lambda_function.ingest_route53.function_name
  principal     = "logs.amazonaws.com"
  source_arn    = "${aws_cloudwatch_log_group.route53_query_log.arn}:*"
}
