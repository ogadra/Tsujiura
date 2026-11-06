resource "aws_budgets_budget" "logs_and_dns" {
  name         = "tsujiura-logs-and-dns"
  budget_type  = "COST"
  limit_amount = var.budget_limit_usd
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  # CloudWatch Logs is billed under AmazonCloudWatch.
  cost_filter {
    name   = "Service"
    values = ["AmazonCloudWatch", "Amazon Route 53"]
  }

  dynamic "notification" {
    for_each = [80, 100]

    content {
      comparison_operator        = "GREATER_THAN"
      notification_type          = "ACTUAL"
      threshold                  = notification.value
      threshold_type             = "PERCENTAGE"
      subscriber_email_addresses = var.budget_notification_emails
    }
  }
}
