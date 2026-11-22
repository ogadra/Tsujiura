resource "aws_sns_topic" "budget" {
  name = "tsujiura-budget"
  tags = local.common_tags
}

resource "aws_sns_topic_policy" "budget" {
  arn    = aws_sns_topic.budget.arn
  policy = data.aws_iam_policy_document.budget_topic.json
}
