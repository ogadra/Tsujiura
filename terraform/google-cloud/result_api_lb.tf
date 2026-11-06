resource "google_compute_region_network_endpoint_group" "result_api" {
  name                  = "tsujiura-result-api"
  region                = "asia-northeast1"
  network_endpoint_type = "SERVERLESS"

  cloud_function {
    function = "tsujiura-result-api"
  }

  depends_on = [google_project_service.frontend]
}

resource "google_compute_backend_service" "result_api" {
  name = "tsujiura-result-api"

  backend {
    group = google_compute_region_network_endpoint_group.result_api.id
  }
}
