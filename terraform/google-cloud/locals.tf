locals {
  domain_name = "tsujiura.ogadra.net"

  common_labels = {
    project    = "tsujiura"
    managed_by = "terraform"
  }

  result_api_assumed_role_arn = format("arn:aws:sts::%s:assumed-role/%s", data.aws_caller_identity.current.account_id, "tsujiura-result-api")
}
