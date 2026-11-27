locals {
  parent_domain_name = "ogadra.net"
  domain_name        = "tsujiura.${local.parent_domain_name}"

  route53_up   = var.dns_down != "route53"
  cloud_dns_up = var.dns_down != "cloud-dns"

  route53_name_servers = sort(aws_route53_delegation_set.tsujiura.name_servers)

  delegated_name_servers = flatten([
    for record_set in data.aws_route53_records.tsujiura_delegation.resource_record_sets : [
      for record in record_set.resource_records : trimsuffix(record.value, ".")
    ] if record_set.type == "NS"
  ])

  cloud_dns_name_servers = local.cloud_dns_up ? sort([
    for name_server in google_dns_managed_zone.tsujiura[0].name_servers : trimsuffix(name_server, ".")
  ]) : sort(tolist(setsubtract(local.delegated_name_servers, local.route53_name_servers)))

  apex_ns_rrset = concat(local.route53_name_servers, local.cloud_dns_name_servers)

  frontend_ips = merge(
    { for index, ip in aws_globalaccelerator_accelerator.tsujiura.ip_sets[0].ip_addresses : "aws-${index}" => ip },
    { "google-cloud" = data.google_compute_global_address.frontend.address },
  )

  # ACM gives the apex and the wildcard the same validation record.
  acm_validation_record = one(distinct([
    for option in aws_acm_certificate.tsujiura.domain_validation_options : {
      name  = option.resource_record_name
      type  = option.resource_record_type
      value = option.resource_record_value
    }
  ]))

  common_tags = {
    Project   = "Tsujiura"
    ManagedBy = "terraform"
  }

  common_labels = {
    project    = "tsujiura"
    managed_by = "terraform"
  }

  public_subnet_cidrs = {
    "ap-northeast-1a" = "10.0.0.0/24"
    "ap-northeast-1c" = "10.0.1.0/24"
    "ap-northeast-1d" = "10.0.2.0/24"
  }
}
