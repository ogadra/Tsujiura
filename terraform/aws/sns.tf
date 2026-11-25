resource "aws_sns_topic" "tsujiura_budget" {
  # checkov:skip=CKV_AWS_26:Budget alerts carry no sensitive data
  name = "tsujiura-budget"
  tags = local.common_tags
}

resource "aws_sns_topic_policy" "tsujiura_budget" {
  # checkov:skip=CKV_TSUJIURA_1:Resource does not support tags
  arn    = aws_sns_topic.tsujiura_budget.arn
  policy = data.aws_iam_policy_document.tsujiura_budget_topic.json
}
