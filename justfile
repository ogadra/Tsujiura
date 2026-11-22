update-asn:
    #!/usr/bin/env bash
    set -euo pipefail
    s3_bucket="$(terraform -chdir=terraform/aws output -raw asn_bucket)"
    gcs_bucket="$(terraform -chdir=terraform/google-cloud output -raw asn_bucket)"
    dir="$(mktemp -d)"
    trap 'rm -rf "$dir"' EXIT
    curl -fsSL -u "$MAXMIND_ACCOUNT_ID:$MAXMIND_LICENSE_KEY" "https://download.maxmind.com/geoip/databases/GeoLite2-ASN/download?suffix=tar.gz" | tar -xzf - -C "$dir" --strip-components=1 --wildcards '*/GeoLite2-ASN.mmdb'
    aws s3 cp "$dir/GeoLite2-ASN.mmdb" "s3://$s3_bucket/GeoLite2-ASN.mmdb"
    gcloud storage cp "$dir/GeoLite2-ASN.mmdb" "gs://$gcs_bucket/GeoLite2-ASN.mmdb"

deploy cloud:
    @"{{just_executable()}}" "_deploy-{{cloud}}"

_deploy-aws:
    #!/usr/bin/env bash
    set -euo pipefail
    : "${TF_BACKEND_BUCKET:?TF_BACKEND_BUCKET must be set}"
    ingest_repository="$(terraform -chdir=terraform/aws output -raw ingest_route53_repository_url)"
    result_api_repository="$(terraform -chdir=terraform/aws output -raw result_api_repository_url)"
    export IMAGE_TAG="$(git rev-parse --short HEAD)"
    aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin "${ingest_repository%%/*}"
    docker build --platform linux/amd64 --provenance=false -f lambda/ingest-route53/Dockerfile -t "$ingest_repository:$IMAGE_TAG" .
    docker push "$ingest_repository:$IMAGE_TAG"
    lambroll deploy --function lambda/ingest-route53/function.json --region us-east-1 --tfstate "s3://$TF_BACKEND_BUCKET/tsujiura/aws/terraform.tfstate"
    aws ecr get-login-password --region ap-northeast-1 | docker login --username AWS --password-stdin "${result_api_repository%%/*}"
    docker build --platform linux/amd64 --provenance=false -f lambda/result-api/Dockerfile -t "$result_api_repository:$IMAGE_TAG" .
    docker push "$result_api_repository:$IMAGE_TAG"
    lambroll deploy --function lambda/result-api/function.json --region ap-northeast-1 --tfstate "s3://$TF_BACKEND_BUCKET/tsujiura/aws/terraform.tfstate"

_deploy-google-cloud:
    #!/usr/bin/env bash
    set -euo pipefail
    : "${TF_BACKEND_BUCKET:?TF_BACKEND_BUCKET must be set}"
    service_account="$(terraform -chdir=terraform/google-cloud output -raw ingest_cloud_dns_service_account)"
    trigger_service_account="$(terraform -chdir=terraform/google-cloud output -raw ingest_cloud_dns_trigger_service_account)"
    topic="$(terraform -chdir=terraform/google-cloud output -raw dns_query_logs_topic)"
    asn_bucket="$(terraform -chdir=terraform/google-cloud output -raw asn_bucket)"
    source_dir="$(mktemp -d)"
    trap 'rm -rf "$source_dir"' EXIT
    cp -r go.mod go.sum internal functions/ingest-cloud-dns/. "$source_dir"
    gcloud functions deploy tsujiura-ingest-cloud-dns \
      --gen2 \
      --region=asia-northeast1 \
      --runtime=go127 \
      --source="$source_dir" \
      --entry-point=IngestCloudDNS \
      --trigger-topic="$topic" \
      --trigger-service-account="$trigger_service_account" \
      --service-account="$service_account" \
      --no-allow-unauthenticated \
      --retry \
      --set-env-vars="FIRESTORE_COLLECTION=results,ASN_BUCKET=$asn_bucket"
