resource "google_dns_record_set" "tsujiura_apex_a" {
  # checkov:skip=CKV_TSUJIURA_2:Resource does not support labels
  managed_zone = data.google_dns_managed_zone.tsujiura.name
  name         = data.google_dns_managed_zone.tsujiura.dns_name
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
  managed_zone = data.google_dns_managed_zone.tsujiura.name
  name         = "*.${data.google_dns_managed_zone.tsujiura.dns_name}"
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
  managed_zone = data.google_dns_managed_zone.tsujiura.name
  name         = local.acm_validation_record.name
  type         = local.acm_validation_record.type
  ttl          = 60

  rrdatas = [local.acm_validation_record.value]
}
