# The wildcard serves provider.svg on the token names.
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

locals {
  # ACM lists the shared record once per name, so collapse it before one().
  acm_validation = one(distinct([
    for option in aws_acm_certificate.main.domain_validation_options : {
      name  = option.resource_record_name
      value = option.resource_record_value
    }
  ]))
}

output "acm_validation_cname_name" {
  description = "Name of the ACM validation CNAME"
  value       = local.acm_validation.name
}

output "acm_validation_cname_value" {
  description = "Value of the ACM validation CNAME"
  value       = local.acm_validation.value
}
