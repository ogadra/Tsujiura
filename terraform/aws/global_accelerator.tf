resource "aws_globalaccelerator_accelerator" "tsujiura" {
  # checkov:skip=CKV_AWS_75:Flow logs are not used
  name            = "tsujiura"
  ip_address_type = "IPV4"
  enabled         = true

  tags = local.common_tags
}

resource "aws_globalaccelerator_listener" "tsujiura_https" {
  # checkov:skip=CKV_TSUJIURA_1:Resource does not support tags
  accelerator_arn = aws_globalaccelerator_accelerator.tsujiura.arn
  protocol        = "TCP"

  port_range {
    from_port = 443
    to_port   = 443
  }
}

resource "aws_globalaccelerator_endpoint_group" "tsujiura_alb" {
  # checkov:skip=CKV_TSUJIURA_1:Resource does not support tags
  listener_arn          = aws_globalaccelerator_listener.tsujiura_https.arn
  endpoint_group_region = data.aws_region.current.region

  endpoint_configuration {
    endpoint_id                    = aws_lb.tsujiura.arn
    client_ip_preservation_enabled = true
  }
}
