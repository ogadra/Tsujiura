resource "aws_wafv2_web_acl" "tsujiura_alb" {
  # checkov:skip=CKV_AWS_192:The backends are Go Lambdas, which Log4j does not affect
  # checkov:skip=CKV2_AWS_31:WAF logs are not needed while the managed rules only count
  name  = "tsujiura-alb"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  rule {
    name     = "aws-common-rule-set"
    priority = 1

    # Count only, so that the measurement page and the result API are never blocked.
    override_action {
      count {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      sampled_requests_enabled   = false
      cloudwatch_metrics_enabled = true
      metric_name                = "tsujiura-alb-common-rule-set"
    }
  }

  visibility_config {
    sampled_requests_enabled   = false
    cloudwatch_metrics_enabled = true
    metric_name                = "tsujiura-alb"
  }

  tags = local.common_tags
}

resource "aws_wafv2_web_acl_association" "tsujiura_alb" {
  # checkov:skip=CKV_TSUJIURA_1:Resource does not support tags
  resource_arn = aws_lb.tsujiura.arn
  web_acl_arn  = aws_wafv2_web_acl.tsujiura_alb.arn
}
