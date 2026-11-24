resource "aws_ce_cost_allocation_tag" "tsujiura_project" {
  tag_key = "Project"
  status  = "Active"
}

resource "aws_budgets_budget" "tsujiura" {
  name         = "tsujiura"
  budget_type  = "COST"
  limit_amount = "30"
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  cost_filter {
    name   = "TagKeyValue"
    values = [format("user:%s$%s", aws_ce_cost_allocation_tag.tsujiura_project.tag_key, local.common_tags.Project)]
  }

  dynamic "notification" {
    for_each = [80, 100]

    content {
      comparison_operator       = "GREATER_THAN"
      notification_type         = "ACTUAL"
      threshold                 = notification.value
      threshold_type            = "PERCENTAGE"
      subscriber_sns_topic_arns = [aws_sns_topic.tsujiura_budget.arn]
    }
  }

  depends_on = [aws_sns_topic_policy.tsujiura_budget]
}
