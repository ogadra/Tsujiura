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
    frontend_repository="$(terraform -chdir=terraform/aws output -raw frontend_repository_url)"
    export IMAGE_TAG="$(git rev-parse --short HEAD)"
    aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin "${ingest_repository%%/*}"
    docker build --platform linux/amd64 --provenance=false -f lambda/ingest-route53/Dockerfile -t "$ingest_repository:$IMAGE_TAG" .
    docker push "$ingest_repository:$IMAGE_TAG"
    lambroll deploy --function lambda/ingest-route53/function.json --region us-east-1 --tfstate "s3://$TF_BACKEND_BUCKET/tsujiura/aws/terraform.tfstate"
    aws ecr get-login-password --region ap-northeast-1 | docker login --username AWS --password-stdin "${result_api_repository%%/*}"
    docker build --platform linux/amd64 --provenance=false -f lambda/result-api/Dockerfile -t "$result_api_repository:$IMAGE_TAG" .
    docker push "$result_api_repository:$IMAGE_TAG"
    export GOOGLE_CLOUD_PROJECT="$(terraform -chdir=terraform/google-cloud output -raw project_id)"
    export GOOGLE_WORKLOAD_IDENTITY_AUDIENCE="$(terraform -chdir=terraform/google-cloud output -raw result_api_workload_identity_audience)"
    export GOOGLE_SERVICE_ACCOUNT="$(terraform -chdir=terraform/google-cloud output -raw result_api_service_account)"
    lambroll deploy --function lambda/result-api/function.json --region ap-northeast-1 --tfstate "s3://$TF_BACKEND_BUCKET/tsujiura/aws/terraform.tfstate"
    aws ecr get-login-password --region ap-northeast-1 | docker login --username AWS --password-stdin "${frontend_repository%%/*}"
    docker build --platform linux/amd64 --provenance=false -f lambda/frontend/Dockerfile -t "$frontend_repository:$IMAGE_TAG" .
    docker push "$frontend_repository:$IMAGE_TAG"
    lambroll deploy --function lambda/frontend/function.json --region ap-northeast-1 --tfstate "s3://$TF_BACKEND_BUCKET/tsujiura/aws/terraform.tfstate"

_deploy-google-cloud:
    #!/usr/bin/env bash
    set -euo pipefail
    : "${TF_BACKEND_BUCKET:?TF_BACKEND_BUCKET must be set}"
    ingest_service_account="$(terraform -chdir=terraform/google-cloud output -raw ingest_cloud_dns_service_account)"
    trigger_service_account="$(terraform -chdir=terraform/google-cloud output -raw ingest_cloud_dns_trigger_service_account)"
    topic="$(terraform -chdir=terraform/google-cloud output -raw dns_query_logs_topic)"
    asn_bucket="$(terraform -chdir=terraform/google-cloud output -raw asn_bucket)"
    result_api_service_account="$(terraform -chdir=terraform/google-cloud output -raw result_api_service_account)"
    frontend_service_account="$(terraform -chdir=terraform/google-cloud output -raw frontend_service_account)"
    build_service_account="$(terraform -chdir=terraform/google-cloud output -raw build_service_account)"
    results_table_name="$(terraform -chdir=terraform/aws output -raw results_table_name)"
    results_table_region="$(terraform -chdir=terraform/aws output -raw results_table_region)"
    role_arn="$(terraform -chdir=terraform/aws output -raw google_cloud_result_api_role_arn)"
    ingest_source_dir="$(mktemp -d)"
    result_api_source_dir="$(mktemp -d)"
    frontend_source_dir="$(mktemp -d)"
    trap 'rm -rf "$ingest_source_dir" "$result_api_source_dir" "$frontend_source_dir"' EXIT
    cp -r go.mod go.sum internal functions/ingest-cloud-dns/. "$ingest_source_dir"
    cp -r go.mod go.sum internal functions/result-api/. "$result_api_source_dir"
    cp -r go.mod go.sum web functions/frontend/. "$frontend_source_dir"
    gcloud functions deploy tsujiura-ingest-cloud-dns \
      --gen2 \
      --region=asia-northeast1 \
      --runtime=go127 \
      --source="$ingest_source_dir" \
      --entry-point=IngestCloudDNS \
      --build-service-account="$build_service_account" \
      --trigger-topic="$topic" \
      --trigger-service-account="$trigger_service_account" \
      --service-account="$ingest_service_account" \
      --no-allow-unauthenticated \
      --retry \
      --set-env-vars="FIRESTORE_COLLECTION=results,ASN_BUCKET=$asn_bucket"
    gcloud functions deploy tsujiura-result-api \
      --gen2 \
      --region=asia-northeast1 \
      --runtime=go127 \
      --source="$result_api_source_dir" \
      --entry-point=ResultAPI \
      --build-service-account="$build_service_account" \
      --trigger-http \
      --service-account="$result_api_service_account" \
      --no-allow-unauthenticated \
      --ingress-settings=internal-and-gclb \
      --set-env-vars="FIRESTORE_COLLECTION=results,RESULTS_TABLE_NAME=$results_table_name,RESULTS_TABLE_REGION=$results_table_region,RESULTS_TABLE_ROLE_ARN=$role_arn"
    gcloud functions deploy tsujiura-frontend \
      --gen2 \
      --region=asia-northeast1 \
      --runtime=go127 \
      --source="$frontend_source_dir" \
      --entry-point=Frontend \
      --build-service-account="$build_service_account" \
      --trigger-http \
      --service-account="$frontend_service_account" \
      --no-allow-unauthenticated \
      --ingress-settings=internal-and-gclb

dns action side:
    #!/usr/bin/env bash
    set -euo pipefail
    shopt -s inherit_errexit
    domain="tsujiura.ogadra.net"
    case "{{action}}" in
      down | up) ;;
      *) echo "action must be down or up" >&2; exit 1 ;;
    esac
    case "{{side}}" in
      route53) records=(aws_route53_record.tsujiura_apex_ns aws_route53_record.tsujiura_soa) ;;
      cloud-dns) records=(google_dns_record_set.tsujiura_apex_ns google_dns_record_set.tsujiura_soa) ;;
      *) echo "side must be route53 or cloud-dns" >&2; exit 1 ;;
    esac
    root="terraform/dns-{{side}}"
    if [ "{{action}}" = up ] && [ "{{side}}" = cloud-dns ]; then
      : "${OGADRA_NET_TSUJIURA_ROOT:?Set OGADRA_NET_TSUJIURA_ROOT in .env to the Terraform root that delegates $domain, then run just dns up cloud-dns again}"
    fi
    plan="$(mktemp --suffix=.tfplan)"
    if [ "{{action}}" = down ]; then
      if [ "{{side}}" = route53 ]; then
        other_zones="$(gcloud dns managed-zones list --filter="dnsName=$domain." --format='value(name)' | wc -l)"
      else
        other_zones="$(aws route53 list-hosted-zones-by-name --dns-name "$domain" --query "length(HostedZones[?Name=='$domain.'])" --output text)"
      fi
      if [ "$other_zones" != 1 ]; then
        echo "The other zone of $domain is down; bring it up before taking {{side}} down" >&2
        exit 1
      fi
      terraform -chdir="$root" state rm "${records[@]}"
      terraform -chdir="$root" plan -destroy -input=false -out="$plan"
      terraform -chdir="$root" apply -input=false "$plan"
    else
      terraform -chdir="$root" plan -input=false -out="$plan"
      terraform -chdir="$root" apply -input=false "$plan"
      if [ "{{side}}" = cloud-dns ]; then
        parent="${domain#*.}"
        missing_name_servers() {
          local parent_zone_id delegated cloud_dns
          parent_zone_id="$(aws route53 list-hosted-zones-by-name --dns-name "$parent" --query "HostedZones[?Name=='$parent.'].Id" --output text)"
          delegated="$(aws route53 list-resource-record-sets --hosted-zone-id "$parent_zone_id" --query "ResourceRecordSets[?Name=='$domain.' && Type=='NS'].ResourceRecords[].Value" --output text | tr '\t' '\n' | sed 's/\.$//' | sort)"
          cloud_dns="$(gcloud dns managed-zones describe "${domain//./-}" --format='value(nameServers)' | tr ';' '\n' | sed 's/\.$//' | sort)"
          comm -13 <(echo "$delegated") <(echo "$cloud_dns")
        }
        missing="$(missing_name_servers)"
        if [ -z "$missing" ]; then
          exit 0
        fi
        delegation_plan="$(mktemp --suffix=.tfplan)"
        direnv exec "$OGADRA_NET_TSUJIURA_ROOT" terraform -chdir="$OGADRA_NET_TSUJIURA_ROOT" plan -input=false -out="$delegation_plan"
        changes="$(direnv exec "$OGADRA_NET_TSUJIURA_ROOT" terraform -chdir="$OGADRA_NET_TSUJIURA_ROOT" show -json "$delegation_plan")"
        delegation_updates="$(jq --arg domain "$domain" '[.resource_changes[] | select((.type == "aws_route53_record" or .type == "google_dns_record_set") and .change.actions == ["update"] and .change.after.type == "NS" and (.change.after.name | rtrimstr(".")) == $domain)] | length' <<<"$changes")"
        unexpected="$(jq -r --arg domain "$domain" '.resource_changes[] | select(.change.actions != ["no-op"]) | select(((.type == "aws_route53_record" or .type == "google_dns_record_set") and .change.actions == ["update"] and .change.after.type == "NS" and (.change.after.name | rtrimstr(".")) == $domain) | not) | "\(.address) (\(.change.actions | join(",")))"' <<<"$changes")"
        if [ -n "$unexpected" ]; then
          echo "The plan of $OGADRA_NET_TSUJIURA_ROOT changes more than updating the two NS records delegating $domain; settle these differences in that root, then run just dns up cloud-dns again: $unexpected" >&2
          exit 1
        fi
        if [ "$delegation_updates" != 2 ]; then
          echo "The plan of $OGADRA_NET_TSUJIURA_ROOT updates $delegation_updates of the two NS records delegating $domain; make that root update both the Route53 and Cloud DNS delegation, then run just dns up cloud-dns again" >&2
          exit 1
        fi
        direnv exec "$OGADRA_NET_TSUJIURA_ROOT" terraform -chdir="$OGADRA_NET_TSUJIURA_ROOT" apply -input=false "$delegation_plan"
        "{{just_executable()}}" dns up route53
        missing="$(missing_name_servers)"
        if [ -n "$missing" ]; then
          echo "The $parent delegation still lacks these Cloud DNS name servers after applying $OGADRA_NET_TSUJIURA_ROOT and dns route53; check both roots, then run just dns up cloud-dns again: $missing" >&2
          exit 1
        fi
      fi
    fi
