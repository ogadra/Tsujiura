resource "aws_ecr_repository" "frontend" {
  name = "tsujiura-frontend"
}

resource "aws_iam_role" "frontend" {
  name               = "tsujiura-frontend"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

resource "aws_iam_role_policy_attachment" "frontend_logs" {
  role       = aws_iam_role.frontend.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_lambda_function" "frontend" {
  function_name = "tsujiura-frontend"
}

data "aws_lambda_function" "result_api" {
  function_name = "tsujiura-result-api"
}

resource "aws_lb_target_group" "frontend" {
  name        = data.aws_lambda_function.frontend.function_name
  target_type = "lambda"

  lambda_multi_value_headers_enabled = false
}

resource "aws_lambda_permission" "frontend" {
  action        = "lambda:InvokeFunction"
  function_name = data.aws_lambda_function.frontend.function_name
  principal     = "elasticloadbalancing.amazonaws.com"
  source_arn    = aws_lb_target_group.frontend.arn
}

resource "aws_lb_target_group_attachment" "frontend" {
  depends_on = [aws_lambda_permission.frontend]

  target_group_arn = aws_lb_target_group.frontend.arn
  target_id        = data.aws_lambda_function.frontend.arn
}

resource "aws_lb_listener_rule" "frontend" {
  listener_arn = aws_lb_listener.tsujiura_https.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }

  condition {
    path_pattern {
      values = ["/", "/provider.svg"]
    }
  }
}

resource "aws_lb_target_group" "result_api" {
  name        = data.aws_lambda_function.result_api.function_name
  target_type = "lambda"

  lambda_multi_value_headers_enabled = false
}

resource "aws_lambda_permission" "result_api" {
  action        = "lambda:InvokeFunction"
  function_name = data.aws_lambda_function.result_api.function_name
  principal     = "elasticloadbalancing.amazonaws.com"
  source_arn    = aws_lb_target_group.result_api.arn
}

resource "aws_lb_target_group_attachment" "result_api" {
  depends_on = [aws_lambda_permission.result_api]

  target_group_arn = aws_lb_target_group.result_api.arn
  target_id        = data.aws_lambda_function.result_api.arn
}

resource "aws_lb_listener_rule" "result_api" {
  listener_arn = aws_lb_listener.tsujiura_https.arn
  priority     = 20

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.result_api.arn
  }

  condition {
    path_pattern {
      values = ["/api/result"]
    }
  }
}

output "frontend_repository_url" {
  value = aws_ecr_repository.frontend.repository_url
}
