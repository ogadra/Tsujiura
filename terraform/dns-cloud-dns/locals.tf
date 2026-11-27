locals {
  domain_name = "tsujiura.ogadra.net"

  aws          = data.terraform_remote_state.aws.outputs
  google_cloud = data.terraform_remote_state.google_cloud.outputs

  cloud_dns_name_servers = sort([
    for name_server in google_dns_managed_zone.tsujiura.name_servers : trimsuffix(name_server, ".")
  ])

  apex_ns_rrset = concat(local.aws.route53_name_servers, local.cloud_dns_name_servers)

  common_labels = {
    project    = "tsujiura"
    managed_by = "terraform"
  }
}
