# Google ID tokens carry the service account's unique ID in sub and azp, and
# AWS exposes azp as aud and the requested audience as oaud.
data "aws_iam_policy_document" "google_cloud_result_api_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = ["accounts.google.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "accounts.google.com:sub"
      values   = [var.google_cloud_result_api_service_account_id]
    }

    condition {
      test     = "StringEquals"
      variable = "accounts.google.com:aud"
      values   = [var.google_cloud_result_api_service_account_id]
    }

    condition {
      test     = "StringEquals"
      variable = "accounts.google.com:oaud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "google_cloud_result_api" {
  name               = "tsujiura-google-cloud-result-api"
  assume_role_policy = data.aws_iam_policy_document.google_cloud_result_api_assume.json
}

resource "aws_iam_role_policy" "google_cloud_result_api" {
  name   = "read-results"
  role   = aws_iam_role.google_cloud_result_api.id
  policy = data.aws_iam_policy_document.result_api.json
}

output "google_cloud_result_api_role_arn" {
  value = aws_iam_role.google_cloud_result_api.arn
}
