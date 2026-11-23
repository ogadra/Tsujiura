resource "aws_acm_certificate" "tsujiura" {
  domain_name               = local.domain_name
  subject_alternative_names = ["*.${local.domain_name}"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate_validation" "tsujiura" {
  certificate_arn = aws_acm_certificate.tsujiura.arn
}
