data "aws_iam_policy_document" "tsujiura_budget_topic" {
  statement {
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.tsujiura_budget.arn]

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

data "aws_iam_policy_document" "lambda_assume" {
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

  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.asn.arn}/GeoLite2-ASN.mmdb"]
  }
}

resource "aws_iam_role" "ingest_route53" {
  name               = "tsujiura-ingest-route53"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

resource "aws_iam_role_policy" "ingest_route53" {
  name   = "ingest-route53"
  role   = aws_iam_role.ingest_route53.id
  policy = data.aws_iam_policy_document.ingest_route53.json
}

resource "aws_iam_role_policy_attachment" "ingest_route53_logs" {
  role       = aws_iam_role.ingest_route53.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role" "result_api" {
  name               = "tsujiura-result-api"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

data "aws_iam_policy_document" "result_api" {
  statement {
    actions   = ["dynamodb:GetItem"]
    resources = [aws_dynamodb_table.results.arn]
  }
}

resource "aws_iam_role_policy" "result_api" {
  name   = "read-results"
  role   = aws_iam_role.result_api.id
  policy = data.aws_iam_policy_document.result_api.json
}

resource "aws_iam_role_policy_attachment" "result_api_logs" {
  role       = aws_iam_role.result_api.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role" "frontend" {
  name               = "tsujiura-frontend"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

resource "aws_iam_role_policy_attachment" "frontend_logs" {
  role       = aws_iam_role.frontend.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
