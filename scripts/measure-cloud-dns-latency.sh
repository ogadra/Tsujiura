#!/usr/bin/env bash
# Measures the delay from a Cloud DNS query to the Firestore document the ingest function writes.
# The document's createTime stands in for the receipt, so the polling interval does not affect the delay.
set -euo pipefail

usage="usage: $0 <cloud-dns-nameserver> [count]"
nameserver="${1:?$usage}"
count="${2:-10}"
project="${GOOGLE_CLOUD_PROJECT:?GOOGLE_CLOUD_PROJECT must be set (see .env.example)}"
timeout_seconds=300

documents="https://firestore.googleapis.com/v1/projects/$project/databases/(default)/documents/results"
body="$(mktemp)"
trap 'rm -f "$body"' EXIT

delays=()
timeouts=0
printf 'token\tdelay_ms\n'
for ((i = 0; i < count; i++)); do
  token="$(cat /proc/sys/kernel/random/uuid)"
  access_token="$(gcloud auth print-access-token)"

  sent_at="$(date +%s%3N)"
  dig +short +tries=1 +time=5 "@$nameserver" "$token.tsujiura.ogadra.net" A >/dev/null

  delay=timeout
  deadline=$((SECONDS + timeout_seconds))
  while ((SECONDS < deadline)); do
    status="$(curl -sS -o "$body" -w '%{http_code}' -H "Authorization: Bearer $access_token" "$documents/$token")"
    if [ "$status" = 200 ]; then
      delay=$(($(date -d "$(jq -r .createTime "$body")" +%s%3N) - sent_at))
      break
    fi
    if [ "$status" != 404 ]; then
      echo "Error: Firestore returned $status: $(cat "$body")" >&2
      exit 1
    fi
    sleep 1
  done

  printf '%s\t%s\n' "$token" "$delay"
  if [ "$delay" = timeout ]; then
    timeouts=$((timeouts + 1))
  else
    delays+=("$delay")
  fi
done

echo "timeouts=$timeouts"
if ((${#delays[@]} > 0)); then
  printf '%s\n' "${delays[@]}" | sort -n | awk '{ v[NR] = $1 } END { printf "min=%d median=%d max=%d\n", v[1], v[int((NR + 1) / 2)], v[NR] }'
fi
