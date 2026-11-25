resource "aws_sns_topic" "tsujiura_budget" {
  name = "tsujiura-budget"
  tags = local.common_tags
}

resource "aws_sns_topic_policy" "tsujiura_budget" {
  arn    = aws_sns_topic.tsujiura_budget.arn
  policy = data.aws_iam_policy_document.tsujiura_budget_topic.json
}
