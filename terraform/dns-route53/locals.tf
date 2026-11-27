locals {
  parent_domain_name = "ogadra.net"
  domain_name        = "tsujiura.${local.parent_domain_name}"

  aws          = data.terraform_remote_state.aws.outputs
  google_cloud = data.terraform_remote_state.google_cloud.outputs

  delegated_name_servers = flatten([
    for record_set in data.aws_route53_records.tsujiura_delegation.resource_record_sets : [
      for record in record_set.resource_records : trimsuffix(record.value, ".")
    ] if record_set.type == "NS"
  ])

  cloud_dns_name_servers = sort(tolist(setsubtract(local.delegated_name_servers, local.aws.route53_name_servers)))

  apex_ns_rrset = concat(local.aws.route53_name_servers, local.cloud_dns_name_servers)

  common_tags = {
    Project   = "Tsujiura"
    ManagedBy = "terraform"
  }
}
