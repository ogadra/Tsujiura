resource "aws_acm_certificate" "main" {
  domain_name       = var.domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate_validation" "main" {
  certificate_arn = aws_acm_certificate.main.arn
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate_validation.main.certificate_arn

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Not Found"
      status_code  = "404"
    }
  }
}

output "acm_validation_cname_name" {
  description = "Name of the ACM validation CNAME to pass to ogadra-net"
  value       = one(aws_acm_certificate.main.domain_validation_options).resource_record_name
}

output "acm_validation_cname_value" {
  description = "Value of the ACM validation CNAME to pass to ogadra-net"
  value       = one(aws_acm_certificate.main.domain_validation_options).resource_record_value
}
