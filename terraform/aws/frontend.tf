resource "aws_ecr_repository" "frontend" {
  name = "tsujiura-frontend"
}

resource "aws_iam_role" "frontend" {
  name               = "tsujiura-frontend"
  assume_role_policy = data.aws_iam_policy_document.ingest_route53_assume.json
}

resource "aws_iam_role_policy_attachment" "frontend_logs" {
  role       = aws_iam_role.frontend.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# lambroll owns the functions, so they must be deployed before these can be read.
data "aws_lambda_function" "frontend" {
  function_name = "tsujiura-frontend"
}

data "aws_lambda_function" "result_api" {
  function_name = "tsujiura-result-api"
}

locals {
  alb_lambda_targets = {
    frontend = {
      function = data.aws_lambda_function.frontend
      paths    = ["/", "/main.js"]
      priority = 10
    }
    result_api = {
      function = data.aws_lambda_function.result_api
      paths    = ["/api/result"]
      priority = 20
    }
  }
}

resource "aws_lb_target_group" "lambda" {
  for_each = local.alb_lambda_targets

  name        = each.value.function.function_name
  target_type = "lambda"

  # The result API reads the token from the single-value query string parameters.
  lambda_multi_value_headers_enabled = false
}

resource "aws_lambda_permission" "alb" {
  for_each = local.alb_lambda_targets

  action        = "lambda:InvokeFunction"
  function_name = each.value.function.function_name
  principal     = "elasticloadbalancing.amazonaws.com"
  source_arn    = aws_lb_target_group.lambda[each.key].arn
}

resource "aws_lb_target_group_attachment" "lambda" {
  for_each   = local.alb_lambda_targets
  depends_on = [aws_lambda_permission.alb]

  target_group_arn = aws_lb_target_group.lambda[each.key].arn
  target_id        = each.value.function.arn
}

resource "aws_lb_listener_rule" "lambda" {
  for_each = local.alb_lambda_targets

  listener_arn = aws_lb_listener.https.arn
  priority     = each.value.priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lambda[each.key].arn
  }

  condition {
    path_pattern {
      values = each.value.paths
    }
  }
}

output "frontend_repository_url" {
  value = aws_ecr_repository.frontend.repository_url
}
