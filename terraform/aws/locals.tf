locals {
  domain_name = "tsujiura.ogadra.net"

  frontend_a_rrset = concat(
    aws_globalaccelerator_accelerator.tsujiura.ip_sets[0].ip_addresses,
    [data.google_compute_global_address.frontend.address],
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

  public_subnet_cidrs = {
    "ap-northeast-1a" = "10.0.0.0/24"
    "ap-northeast-1c" = "10.0.1.0/24"
    "ap-northeast-1d" = "10.0.2.0/24"
  }
}
