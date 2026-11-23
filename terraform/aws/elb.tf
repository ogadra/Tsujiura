resource "aws_lb" "tsujiura" {
  name                       = "tsujiura"
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.tsujiura_alb.id]
  subnets                    = [for subnet in aws_subnet.tsujiura_public : subnet.id]
  drop_invalid_header_fields = true
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
}
