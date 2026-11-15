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
