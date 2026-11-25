resource "aws_lb" "tsujiura" {
  # checkov:skip=CKV_AWS_91:ALB access logs are not used
  # checkov:skip=CKV_AWS_150:Deletion protection would block terraform destroy
  # checkov:skip=CKV2_AWS_76:The backends are Go Lambdas, which Log4j does not affect
  name                       = "tsujiura"
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.tsujiura_alb.id]
  subnets                    = [for subnet in aws_subnet.tsujiura_public : subnet.id]
  drop_invalid_header_fields = true

  tags = local.common_tags
}

resource "aws_lb_listener" "tsujiura_https" {
  load_balancer_arn = aws_lb.tsujiura.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate_validation.tsujiura.certificate_arn

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Not Found"
      status_code  = "404"
    }
  }

  tags = local.common_tags
}

resource "aws_lb_target_group" "frontend" {
  name        = data.aws_lambda_function.frontend.function_name
  target_type = "lambda"

  lambda_multi_value_headers_enabled = false

  tags = local.common_tags
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

  tags = local.common_tags
}

resource "aws_lb_target_group" "result_api" {
  name        = data.aws_lambda_function.result_api.function_name
  target_type = "lambda"

  lambda_multi_value_headers_enabled = false

  tags = local.common_tags
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

  tags = local.common_tags
}

resource "aws_lb_target_group_attachment" "frontend" {
  # checkov:skip=CKV_TSUJIURA_1:Resource does not support tags
  depends_on = [aws_lambda_permission.frontend]

  target_group_arn = aws_lb_target_group.frontend.arn
  target_id        = data.aws_lambda_function.frontend.arn
}

resource "aws_lb_target_group_attachment" "result_api" {
  # checkov:skip=CKV_TSUJIURA_1:Resource does not support tags
  depends_on = [aws_lambda_permission.result_api]

  target_group_arn = aws_lb_target_group.result_api.arn
  target_id        = data.aws_lambda_function.result_api.arn
}
