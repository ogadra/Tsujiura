locals {
  domain_name = "tsujiura.ogadra.net"

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
