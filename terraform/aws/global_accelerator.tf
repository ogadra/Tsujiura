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
  endpoint_group_region = "ap-northeast-1"

  endpoint_configuration {
    endpoint_id                    = aws_lb.main.arn
    client_ip_preservation_enabled = true
  }
}

output "global_accelerator_ips" {
  description = "Static IPs of the Global Accelerator to pass to the frontend A records"
  value       = one(aws_globalaccelerator_accelerator.main.ip_sets).ip_addresses
}
