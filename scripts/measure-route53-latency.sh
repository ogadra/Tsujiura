#!/usr/bin/env bash
# Measures how long a Route53 query takes to become readable in DynamoDB.
# usage: scripts/measure-route53-latency.sh [count] [timeout seconds]
set -euo pipefail

domain=tsujiura.ogadra.net
count="${1:-20}"
timeout_ms="$((${2:-300} * 1000))"
table="${RESULTS_TABLE_NAME:?RESULTS_TABLE_NAME must be set}"
region="${RESULTS_TABLE_REGION:?RESULTS_TABLE_REGION must be set}"

zone_id="$(aws route53 list-hosted-zones-by-name --dns-name "$domain" --query "HostedZones[?Name=='$domain.'] | [0].Id" --output text)"
nameserver="$(aws route53 get-hosted-zone --id "$zone_id" --query 'DelegationSet.NameServers[0]' --output text)"

delays=()
timeouts=0
printf 'sample\ttoken\tqueried_at\tdelay_ms\n'
for ((sample = 1; sample <= count; sample++)); do
  token="$(cat /proc/sys/kernel/random/uuid)"
  started_at="$(date +%s%3N)"
  # Asking the name server directly keeps the query away from Cloud DNS.
  dig +short "@$nameserver" "$token.$domain" A >/dev/null

  while true; do
    queried_at="$(aws dynamodb get-item --region "$region" --table-name "$table" --consistent-read \
      --key "{\"token\":{\"S\":\"$token\"}}" --query 'Item.queriedAt.S' --output text)"
    delay_ms="$(($(date +%s%3N) - started_at))"
    if [ -n "$queried_at" ] && [ "$queried_at" != None ]; then
      delays+=("$delay_ms")
      printf '%d\t%s\t%s\t%d\n' "$sample" "$token" "$queried_at" "$delay_ms"
      break
    fi
    if [ "$delay_ms" -ge "$timeout_ms" ]; then
      timeouts=$((timeouts + 1))
      printf '%d\t%s\ttimeout\t-\n' "$sample" "$token"
      break
    fi
    sleep 1
  done
done

if [ "${#delays[@]}" -eq 0 ]; then
  echo "Error: no sample reached DynamoDB" >&2
  exit 1
fi
mapfile -t sorted < <(printf '%s\n' "${delays[@]}" | sort -n)
n="${#sorted[@]}"
printf 'samples=%d timeouts=%d min=%d median=%d p95=%d max=%d\n' "$n" "$timeouts" \
  "${sorted[0]}" "${sorted[$(((n - 1) / 2))]}" "${sorted[$(((n * 95 + 99) / 100 - 1))]}" "${sorted[$((n - 1))]}"
