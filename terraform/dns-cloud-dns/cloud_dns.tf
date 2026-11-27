resource "google_dns_managed_zone" "tsujiura" {
  # checkov:skip=CKV_GCP_16:Signing here alone would make resolvers reject the answers of the unsigned peer Route53 zone
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
  managed_zone = google_dns_managed_zone.tsujiura.name
  name         = google_dns_managed_zone.tsujiura.dns_name
  type         = "NS"
  ttl          = 10

  rrdatas = [for name_server in local.apex_ns_rrset : "${name_server}."]

  lifecycle {
    precondition {
      condition     = length(distinct(local.apex_ns_rrset)) == 8
      error_message = "The apex NS RRset must hold 8 distinct name servers, 4 from each provider."
    }
  }
}

resource "google_dns_record_set" "tsujiura_soa" {
  # checkov:skip=CKV_TSUJIURA_2:Resource does not support labels
  managed_zone = google_dns_managed_zone.tsujiura.name
  name         = google_dns_managed_zone.tsujiura.dns_name
  type         = "SOA"
  ttl          = 10

  rrdatas = [format("%s cloud-dns-hostmaster.google.com. 1 21600 3600 259200 10", google_dns_managed_zone.tsujiura.name_servers[0])]
}

resource "google_dns_record_set" "tsujiura_apex_a" {
  # checkov:skip=CKV_TSUJIURA_2:Resource does not support labels
  managed_zone = google_dns_managed_zone.tsujiura.name
  name         = google_dns_managed_zone.tsujiura.dns_name
  type         = "A"
  ttl          = 10

  routing_policy {
    health_check = local.aws.cloud_dns_health_check_id

    geo {
      location = "asia-northeast1"

      health_checked_targets {
        external_endpoints = values(local.aws.frontend_ips)
      }
    }
  }
}

resource "google_dns_record_set" "tsujiura_wildcard_a" {
  # checkov:skip=CKV_TSUJIURA_2:Resource does not support labels
  managed_zone = google_dns_managed_zone.tsujiura.name
  name         = "*.${google_dns_managed_zone.tsujiura.dns_name}"
  type         = "A"
  ttl          = 10

  routing_policy {
    health_check = local.aws.cloud_dns_health_check_id

    geo {
      location = "asia-northeast1"

      health_checked_targets {
        external_endpoints = values(local.aws.frontend_ips)
      }
    }
  }
}

resource "google_dns_record_set" "tsujiura_acm_validation" {
  # checkov:skip=CKV_TSUJIURA_2:Resource does not support labels
  managed_zone = google_dns_managed_zone.tsujiura.name
  name         = local.aws.acm_validation_record.name
  type         = local.aws.acm_validation_record.type
  ttl          = 10

  rrdatas = [local.aws.acm_validation_record.value]
}

resource "google_dns_record_set" "tsujiura_dns_authorization" {
  # checkov:skip=CKV_TSUJIURA_2:Resource does not support labels
  managed_zone = google_dns_managed_zone.tsujiura.name
  name         = local.google_cloud.dns_authorization_record.name
  type         = local.google_cloud.dns_authorization_record.type
  ttl          = 10

  rrdatas = [local.google_cloud.dns_authorization_record.data]
}
