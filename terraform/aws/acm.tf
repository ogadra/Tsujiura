resource "aws_acm_certificate" "tsujiura" {
  domain_name               = local.domain_name
  subject_alternative_names = ["*.${local.domain_name}"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = local.common_tags
}

resource "aws_acm_certificate_validation" "tsujiura" {
  # checkov:skip=CKV_TSUJIURA_1:Resource does not support tags
  certificate_arn = aws_acm_certificate.tsujiura.arn

  validation_record_fqdns = [trimsuffix(local.acm_validation_record.name, ".")]
}
