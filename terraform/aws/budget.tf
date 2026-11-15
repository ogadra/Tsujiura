resource "aws_ce_cost_allocation_tag" "project" {
  tag_key = "Project"
  status  = "Active"
}

resource "aws_budgets_budget" "main" {
  name         = "tsujiura"
  budget_type  = "COST"
  limit_amount = var.budget_limit_usd
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  # The account is shared with bunshin, so an account-wide budget would count its costs too.
  cost_filter {
    name   = "TagKeyValue"
    values = [format("user:%s$%s", aws_ce_cost_allocation_tag.project.tag_key, local.common_tags.Project)]
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
