# AWS maps azp of a Google ID token, the service account's unique ID, to aud and its audience to oaud.
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
      values   = [data.google_service_account.result_api.unique_id]
    }

    condition {
      test     = "StringEquals"
      variable = "accounts.google.com:aud"
      values   = [data.google_service_account.result_api.unique_id]
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

  tags = local.common_tags
}

resource "aws_iam_role_policy" "google_cloud_result_api" {
  # checkov:skip=CKV_TSUJIURA_1:Resource does not support tags
  name   = "read-results"
  role   = aws_iam_role.google_cloud_result_api.id
  policy = data.aws_iam_policy_document.result_api.json
}

output "google_cloud_result_api_role_arn" {
  value = aws_iam_role.google_cloud_result_api.arn
}
