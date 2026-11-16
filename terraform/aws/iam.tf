data "aws_iam_policy_document" "budget_topic" {
  statement {
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.budget.arn]

    principals {
      type        = "Service"
      identifiers = ["budgets.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    # A wildcard instead of the budget's ARN keeps the policy free of a dependency on the budget it serves.
    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:budgets::${data.aws_caller_identity.current.account_id}:*"]
    }
  }
}

data "aws_iam_policy_document" "route53_query_log" {
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["${aws_cloudwatch_log_group.route53_query_log.arn}:*"]

    principals {
      type        = "Service"
      identifiers = ["route53.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "ingest_route53_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "ingest_route53" {
  statement {
    actions   = ["dynamodb:PutItem"]
    resources = [aws_dynamodb_table.results.arn]
  }
}
