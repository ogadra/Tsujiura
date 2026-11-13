_validate-vendor vendor:
    @if [ "{{vendor}}" != "aws" ] && [ "{{vendor}}" != "google-cloud" ]; then echo "Error: vendor must be 'aws' or 'google-cloud', got '{{vendor}}'"; exit 1; fi

_validate-tf-backend-bucket:
    @if [ -z "${TF_BACKEND_BUCKET:-}" ]; then echo "Error: TF_BACKEND_BUCKET must be set (see .env.example)"; exit 1; fi

# Initialize terraform with the S3 backend config
# Requires TF_BACKEND_BUCKET to be set (e.g. via direnv / .env)
init vendor: (_validate-vendor vendor) _validate-tf-backend-bucket
    terraform -chdir=terraform/{{vendor}} init -reconfigure -backend-config="bucket=${TF_BACKEND_BUCKET}" -backend-config="key=tsujiura/{{vendor}}/terraform.tfstate"

test:
    go test ./...

lint:
    go vet ./...
    test -z "$(gofmt -l .)"

# Functions take the database in their deploy artifact, so run this before deploying them.
geolite2-asn:
    curl -fsSL -u "$MAXMIND_ACCOUNT_ID:$MAXMIND_LICENSE_KEY" "https://download.maxmind.com/geoip/databases/GeoLite2-ASN/download?suffix=tar.gz" | tar -xzf - --strip-components=1 --wildcards '*/GeoLite2-ASN.mmdb'

# Needs `just geolite2-asn` for the image and `just init aws` for the repository URL.
deploy-ingest-route53: _validate-tf-backend-bucket
    #!/usr/bin/env bash
    set -euo pipefail
    repository="$(terraform -chdir=terraform/aws output -raw ingest_route53_repository_url)"
    export IMAGE_TAG="$(git rev-parse --short HEAD)"
    aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin "${repository%%/*}"
    docker build --platform linux/amd64 --provenance=false -f lambda/ingest-route53/Dockerfile -t "$repository:$IMAGE_TAG" .
    docker push "$repository:$IMAGE_TAG"
    lambroll deploy --function lambda/ingest-route53/function.json --region us-east-1 --tfstate "s3://$TF_BACKEND_BUCKET/tsujiura/aws/terraform.tfstate"

# Needs `just geolite2-asn` for the database and `just init google-cloud` for the outputs.
deploy-ingest-cloud-dns: _validate-tf-backend-bucket
    #!/usr/bin/env bash
    set -euo pipefail
    service_account="$(terraform -chdir=terraform/google-cloud output -raw ingest_cloud_dns_service_account)"
    trigger_service_account="$(terraform -chdir=terraform/google-cloud output -raw ingest_cloud_dns_trigger_service_account)"
    topic="$(terraform -chdir=terraform/google-cloud output -raw dns_query_logs_topic)"
    # Go functions must sit at the module root, so stage the package there under the same module path.
    source_dir="$(mktemp -d)"
    trap 'rm -rf "$source_dir"' EXIT
    cp -r go.mod go.sum internal GeoLite2-ASN.mmdb functions/ingest-cloud-dns/. "$source_dir"
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
      --set-env-vars=FIRESTORE_COLLECTION=results,ASN_DB_PATH=serverless_function_source_code/GeoLite2-ASN.mmdb
