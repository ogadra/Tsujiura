variable "dns_down" {
  description = "Authoritative DNS whose tsujiura.ogadra.net zone is deleted to test failover: none, route53, or cloud-dns"
  type        = string

  validation {
    condition     = contains(["none", "route53", "cloud-dns"], var.dns_down)
    error_message = "dns_down must be none, route53, or cloud-dns."
  }
}
