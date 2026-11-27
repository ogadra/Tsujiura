resource "google_dns_managed_zone" "tsujiura" {
  # checkov:skip=CKV_GCP_16:Signing here alone would make resolvers reject the answers of the unsigned peer Route53 zone
  count = local.cloud_dns_up ? 1 : 0

  name        = replace(local.domain_name, ".", "-")
  dns_name    = "${local.domain_name}."
  description = "Tsujiura subdomain zone served alongside Route53 for ${local.domain_name}."
  visibility  = "public"
  labels      = local.common_labels

  cloud_logging_config {
    enable_logging = true
  }
}

resource "google_dns_record_set" "tsujiura_apex_ns" {
  # checkov:skip=CKV_TSUJIURA_2:Resource does not support labels
  count = local.cloud_dns_up ? 1 : 0

  managed_zone = google_dns_managed_zone.tsujiura[0].name
  name         = google_dns_managed_zone.tsujiura[0].dns_name
  type         = "NS"
  ttl          = 10

  rrdatas = [for name_server in local.apex_ns_rrset : "${name_server}."]
}

resource "google_dns_record_set" "tsujiura_apex_a" {
  # checkov:skip=CKV_TSUJIURA_2:Resource does not support labels
  count = local.cloud_dns_up ? 1 : 0

  managed_zone = google_dns_managed_zone.tsujiura[0].name
  name         = google_dns_managed_zone.tsujiura[0].dns_name
  type         = "A"
  ttl          = 10

  routing_policy {
    health_check = google_compute_health_check.tsujiura_frontend.id

    geo {
      location = "asia-northeast1"

      health_checked_targets {
        external_endpoints = values(local.frontend_ips)
      }
    }
  }
}

resource "google_dns_record_set" "tsujiura_wildcard_a" {
  # checkov:skip=CKV_TSUJIURA_2:Resource does not support labels
  count = local.cloud_dns_up ? 1 : 0

  managed_zone = google_dns_managed_zone.tsujiura[0].name
  name         = "*.${google_dns_managed_zone.tsujiura[0].dns_name}"
  type         = "A"
  ttl          = 10

  routing_policy {
    health_check = google_compute_health_check.tsujiura_frontend.id

    geo {
      location = "asia-northeast1"

      health_checked_targets {
        external_endpoints = values(local.frontend_ips)
      }
    }
  }
}

resource "google_dns_record_set" "tsujiura_acm_validation" {
  # checkov:skip=CKV_TSUJIURA_2:Resource does not support labels
  count = local.cloud_dns_up ? 1 : 0

  managed_zone = google_dns_managed_zone.tsujiura[0].name
  name         = local.acm_validation_record.name
  type         = local.acm_validation_record.type
  ttl          = 10

  rrdatas = [local.acm_validation_record.value]
}

resource "google_dns_record_set" "tsujiura_soa" {
  # checkov:skip=CKV_TSUJIURA_2:Resource does not support labels
  count = local.cloud_dns_up ? 1 : 0

  managed_zone = google_dns_managed_zone.tsujiura[0].name
  name         = google_dns_managed_zone.tsujiura[0].dns_name
  type         = "SOA"
  ttl          = 10

  rrdatas = ["ns-cloud-b1.googledomains.com. cloud-dns-hostmaster.google.com. 1 21600 3600 259200 10"]
}
