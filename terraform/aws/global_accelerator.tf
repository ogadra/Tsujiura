resource "aws_globalaccelerator_accelerator" "main" {
  name            = "tsujiura"
  ip_address_type = "IPV4"
  enabled         = true
}

resource "aws_globalaccelerator_listener" "https" {
  accelerator_arn = aws_globalaccelerator_accelerator.main.arn
  protocol        = "TCP"

  port_range {
    from_port = 443
    to_port   = 443
  }
}

resource "aws_globalaccelerator_endpoint_group" "alb" {
  listener_arn          = aws_globalaccelerator_listener.https.arn
  endpoint_group_region = data.aws_region.current.region

  endpoint_configuration {
    endpoint_id                    = aws_lb.main.arn
    client_ip_preservation_enabled = true
  }
}
