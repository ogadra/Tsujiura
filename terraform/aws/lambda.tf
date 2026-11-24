resource "aws_lambda_permission" "ingest_route53" {
  provider = aws.use1

  action        = "lambda:InvokeFunction"
  function_name = data.aws_lambda_function.ingest_route53.function_name
  principal     = "logs.amazonaws.com"
  source_arn    = "${aws_cloudwatch_log_group.route53_query_log.arn}:*"
}

resource "aws_lambda_permission" "frontend" {
  action        = "lambda:InvokeFunction"
  function_name = data.aws_lambda_function.frontend.function_name
  principal     = "elasticloadbalancing.amazonaws.com"
  source_arn    = aws_lb_target_group.frontend.arn
}

resource "aws_lambda_permission" "result_api" {
  action        = "lambda:InvokeFunction"
  function_name = data.aws_lambda_function.result_api.function_name
  principal     = "elasticloadbalancing.amazonaws.com"
  source_arn    = aws_lb_target_group.result_api.arn
}
