# The wildcard covers the token names, which the page loads an image from to see which provider answered.
resource "aws_acm_certificate" "main" {
  domain_name               = local.domain_name
  subject_alternative_names = ["*.${local.domain_name}"]
  validation_method         = "DNS"

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

locals {
  # ACM lists the record once for the apex and once for the wildcard, so one() fails unless they collapse into one.
  acm_validation = one(distinct([
    for option in aws_acm_certificate.main.domain_validation_options : {
      name  = option.resource_record_name
      value = option.resource_record_value
    }
  ]))
}

output "acm_validation_cname_name" {
  description = "Name of the ACM validation CNAME to pass to ogadra-net"
  value       = local.acm_validation.name
}

output "acm_validation_cname_value" {
  description = "Value of the ACM validation CNAME to pass to ogadra-net"
  value       = local.acm_validation.value
}
