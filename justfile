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

deploy-ingest-route53:
    #!/usr/bin/env bash
    set -euo pipefail
    : "${TF_BACKEND_BUCKET:?TF_BACKEND_BUCKET must be set}"
    repository="$(terraform -chdir=terraform/aws output -raw ingest_route53_repository_url)"
    export IMAGE_TAG="$(git rev-parse --short HEAD)"
    aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin "${repository%%/*}"
    docker build --platform linux/amd64 --provenance=false -f lambda/ingest-route53/Dockerfile -t "$repository:$IMAGE_TAG" .
    docker push "$repository:$IMAGE_TAG"
    lambroll deploy --function lambda/ingest-route53/function.json --region us-east-1 --tfstate "s3://$TF_BACKEND_BUCKET/tsujiura/aws/terraform.tfstate"
