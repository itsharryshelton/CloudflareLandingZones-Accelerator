#!/usr/bin/env bash

# resource-tags.sh [manifest_dir]
#
# Makes the Cloudflare resource tags on the account match what the tagging
# layers - zones, zerotrust, r2 and workers - output after an apply.
#
#   $ scripts/resource-tags.sh              # every tagging layer applied so far
#   $ DRY_RUN=1 scripts/resource-tags.sh    # report what would change, write nothing
#
# With no argument it reads `terraform output -json resource_tags` from each
# layer's local state. Pass a directory of manifest files to tag from those
# instead.
#
# WHY THIS IS NOT TERRAFORM
# -------------------------
# The Cloudflare provider has no tagging resource (none as of 5.24.0). The
# Tagging API is in public beta.
#
# WHAT IT DOES TO A RESOURCE
# --------------------------
# Cloudflare's PUT replaces a resource's whole tag set; there is no PATCH. So a
# tag added in the dashboard to a resource in a manifest is removed here. A
# resource NOT in any manifest is never touched - a Worker deployed with
# wrangler from its own repository, a zone owned elsewhere, anything these
# layers were not told about.
#
# Reads first and writes only what differs, so a run with nothing to change
# makes no writes and says so. A 500 on the read is taken to mean "never
# tagged", which is the beta's answer for that case. The PUT that follows is
# idempotent, so a genuine 500 costs one redundant write, never a wrong one.
#
# MANIFEST SHAPE - one file per layer, from `terraform output -json resource_tags`
#   { "account_id": "<32 hex>", "layer": "zones",
#     "resources": [ { "address": "zones.example_com", "resource_type": "zone",
#                      "resource_id": "<id>", "zone_id": "<id>" or null,
#                      "tags": { "environment": "prod" } } ] }
#
# A resource with a zone_id is tagged through /zones/<zone_id>/tags, anything
# else through /accounts/<account_id>/tags - Cloudflare splits the resource
# types that way, and the layer that knows the type sets the field.
#
# Reads from the environment:
#   CLOUDFLARE_API_KEY and CLOUDFLARE_EMAIL, or CLOUDFLARE_API_TOKEN
#                          the credential the Terraform run used. Required.
#   CLOUDFLARE_ACCOUNT_ID  the account every manifest must name. Defaults to
#                          cloudflare_account_id in deployment/config/account.tfvars.
#   DRY_RUN                1 = read and report what would change, write nothing.
#   CF_API_BASE            API root. Cloudflare's by default; set for testing.
#   REQUEST_INTERVAL       seconds between API calls. See below.

set -euo pipefail

# shellcheck source=scripts/_common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

require_bash4
require_tools curl jq
require_cloudflare_credential
resolve_account_id

MANIFEST_DIR="${1:-}"
DRY_RUN="${DRY_RUN:-0}"
CF_API_BASE="${CF_API_BASE:-https://api.cloudflare.com/client/v4}"

# Cloudflare allows 1200 requests per 5 minutes per credential, which is 4/s. A
# fixed interval keeps this script under that ceiling on its own. It draws on
# the same budget as Terraform, though, so run it once an apply has finished
# rather than alongside one.
REQUEST_INTERVAL="${REQUEST_INTERVAL:-0.3}"
MAX_RETRIES="${MAX_RETRIES:-5}"

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

shopt -s nullglob
if [[ -n "$MANIFEST_DIR" ]]; then
  [[ -d "$MANIFEST_DIR" ]] || die "no manifest directory at $MANIFEST_DIR"
  manifests=("$MANIFEST_DIR"/*.json)
else
  # State is the only thing that knows the resource IDs, so the manifests are
  # read out of it. A layer that has not been applied has no such output yet,
  # and is skipped rather than treated as a failure.
  require_tools terraform
  mkdir "$WORK_DIR/manifests"
  for tags_tf in "$LAYERS_DIR"/*/tags.tf; do
    layer_dir="$(dirname "$tags_tf")"
    layer="$(basename "$layer_dir")"
    if terraform -chdir="$layer_dir" output -json resource_tags >"$WORK_DIR/manifests/$layer.json" 2>/dev/null; then
      echo "read resource_tags from $layer"
    else
      rm -f "$WORK_DIR/manifests/$layer.json"
      echo "note: $layer has no resource_tags in its state - not applied yet, skipping"
    fi
  done
  manifests=("$WORK_DIR/manifests"/*.json)
fi

if [[ ${#manifests[@]} -eq 0 ]]; then
  echo "no resource tag manifests - no tagging layer has been applied"
  exit 0
fi

# The credential reaches curl through a header file rather than an argument, so
# it never appears in the process list of anything else on the machine.
AUTH_HEADER="$WORK_DIR/auth-header"
(
  umask 077
  if [[ -n "${CLOUDFLARE_API_TOKEN:-}" ]]; then
    echo "Authorization: Bearer $CLOUDFLARE_API_TOKEN"
  else
    echo "X-Auth-Email: $CLOUDFLARE_EMAIL"
    echo "X-Auth-Key: $CLOUDFLARE_API_KEY"
  fi >"$AUTH_HEADER"
)

# ---------------------------------------------------------------------------
# Validate every manifest before writing anything.
# ---------------------------------------------------------------------------
# Account first: a manifest carries resource IDs, and IDs from one account PUT
# against another would be a confusing 404 at best. Then duplicates: two layers
# claiming one resource would take turns overwriting each other's tags.
problems=0
for m in "${manifests[@]}"; do
  if ! jq -e 'type == "object" and (.resources | type == "array")' "$m" >/dev/null 2>&1; then
    echo "ERROR: $m is not a resource_tags manifest - expected an object with a resources array"
    problems=$((problems + 1))
    continue
  fi

  manifest_account="$(jq -r '.account_id // ""' "$m")"
  if [[ "$manifest_account" != "$CLOUDFLARE_ACCOUNT_ID" ]]; then
    echo "ERROR: $m is for account '$manifest_account', but this run targets $CLOUDFLARE_ACCOUNT_ID"
    problems=$((problems + 1))
  fi

  malformed="$(jq -r '
    .resources[]
    | select(
        (.resource_type | type != "string" or length == 0) or
        (.resource_id | type != "string" or length == 0) or
        (.tags | type != "object") or
        ([.tags[] | type != "string"] | any)
      )
    | .address // "(no address)"' "$m")"
  if [[ -n "$malformed" ]]; then
    echo "ERROR: $m has resources with no type, no ID or non-string tags:"
    sed 's/^/  /' <<<"$malformed"
    problems=$((problems + 1))
  fi
done

duplicates="$(jq -rs '
  [.[].resources[]?]
  | group_by([.resource_type, .resource_id])[]
  | select(length > 1)
  | map(.address) | join(", ")' "${manifests[@]}")"
if [[ -n "$duplicates" ]]; then
  echo "ERROR: more than one manifest entry tags the same resource - each would overwrite the other:"
  sed 's/^/  /' <<<"$duplicates"
  problems=$((problems + 1))
fi

if [[ $problems -gt 0 ]]; then
  echo "ERROR: $problems manifest problem(s) - no tags were written"
  exit 1
fi

# ---------------------------------------------------------------------------
# API access.
# ---------------------------------------------------------------------------
# api <method> <path> [body_file]
# Prints the HTTP status; the body is left in $WORK_DIR/response. Retries a 429
# on the API's own Retry-After, and a 502/503/504 on a short backoff. Every
# request here is a GET or an idempotent PUT, so repeating one is safe.
api() {
  local method="$1" path="$2" body="${3:-}" attempt=0 status wait
  local args=(-sS --max-time 30 -X "$method" -H "@$AUTH_HEADER"
    -o "$WORK_DIR/response" -D "$WORK_DIR/headers" -w '%{http_code}')
  if [[ -n "$body" ]]; then
    args+=(-H 'Content-Type: application/json' --data-binary "@$body")
  fi

  while :; do
    sleep "$REQUEST_INTERVAL"
    : >"$WORK_DIR/response"
    status="$(curl "${args[@]}" "$CF_API_BASE/$path" 2>"$WORK_DIR/curl-error")" || status="000"

    case "$status" in
      429 | 502 | 503 | 504)
        if [[ $attempt -lt $MAX_RETRIES ]]; then
          attempt=$((attempt + 1))
          wait="$(awk 'tolower($1) == "retry-after:" { print $2 + 0 }' "$WORK_DIR/headers" | tail -n1)"
          wait="${wait:-$((attempt * 5))}"
          echo "HTTP $status on $method $path - retrying in ${wait}s ($attempt/$MAX_RETRIES)" >&2
          sleep "$wait"
          continue
        fi
        ;;
    esac

    echo "$status"
    return 0
  done
}

# The API's own error messages, for a failure line. Never the request, which
# holds nothing secret but is not needed either.
api_errors() {
  local detail
  detail="$(jq -r '[.errors[]? | ((.code | tostring) + " " + .message)] | join("; ")' "$WORK_DIR/response" 2>/dev/null || true)"
  if [[ -z "$detail" && -s "$WORK_DIR/curl-error" ]]; then
    detail="$(head -n1 "$WORK_DIR/curl-error")"
  fi
  echo "${detail:-no error detail}"
}

uri() { jq -rn --arg v "$1" '$v | @uri'; }

# ---------------------------------------------------------------------------
# Reconcile.
# ---------------------------------------------------------------------------
# address, type, id, zone_id, tags. Tags travel base64-encoded so a tab or a
# newline in a value cannot split the row. An account-scoped resource has no
# zone_id and travels as "-" rather than as an empty field: tab is IFS
# whitespace, so `read` collapses two adjacent tabs into one and the tags would
# slide into the zone_id slot.
mapfile -t rows < <(jq -rs '
  [.[].resources[]]
  | sort_by(.address)[]
  | [.address, .resource_type, .resource_id, (.zone_id // "-"), (.tags | tojson | @base64)]
  | @tsv' "${manifests[@]}")

total=${#rows[@]}
unchanged=0
changed=0
failed=0
declare -a CHANGES=() FAILURES=()

echo "Reconciling tags on $total resource(s) from ${#manifests[@]} manifest(s)$([[ "$DRY_RUN" == "1" ]] && echo " - DRY RUN, nothing will be written")"

for row in "${rows[@]}"; do
  IFS=$'\t' read -r address rtype rid zone_id tags_b64 <<<"$row"

  if [[ "$zone_id" != "-" ]]; then
    scope="zones/$zone_id"
  else
    scope="accounts/$CLOUDFLARE_ACCOUNT_ID"
  fi

  desired="$(base64 -d <<<"$tags_b64" | jq -S -c '.')"

  status="$(api GET "$scope/tags?resource_type=$(uri "$rtype")&resource_id=$(uri "$rid")")"
  case "$status" in
    200) current="$(jq -S -c '.result.tags // {}' "$WORK_DIR/response")" ;;
    500) current='{}' ;;
    *)
      echo "ERROR: $address: reading tags failed with HTTP $status - $(api_errors)"
      FAILURES+=("$address: read HTTP $status")
      failed=$((failed + 1))
      continue
      ;;
  esac

  if [[ "$current" == "$desired" ]]; then
    unchanged=$((unchanged + 1))
    continue
  fi

  # +key=value added, -key removed, ~key=old->new changed.
  diff="$(jq -rn --argjson a "$current" --argjson b "$desired" '
    [ ($b | keys[]) as $k | select($a | has($k) | not) | "+" + $k + "=" + $b[$k] ]
    + [ ($a | keys[]) as $k | select($b | has($k) | not) | "-" + $k ]
    + [ ($b | keys[]) as $k | select(($a | has($k)) and $a[$k] != $b[$k]) | "~" + $k + "=" + $a[$k] + "->" + $b[$k] ]
    | join(" ")')"

  if [[ "$DRY_RUN" == "1" ]]; then
    echo "would tag $address: $diff"
    CHANGES+=("$address: $diff")
    changed=$((changed + 1))
    continue
  fi

  jq -n --arg t "$rtype" --arg id "$rid" --argjson tags "$desired" \
    '{resource_type: $t, resource_id: $id, tags: $tags}' >"$WORK_DIR/body.json"

  status="$(api PUT "$scope/tags" "$WORK_DIR/body.json")"
  if [[ "$status" =~ ^2 ]]; then
    echo "tagged $address: $diff"
    CHANGES+=("$address: $diff")
    changed=$((changed + 1))
  else
    echo "ERROR: $address: writing tags failed with HTTP $status - $(api_errors)"
    FAILURES+=("$address: write HTTP $status")
    failed=$((failed + 1))
  fi
done

verb="tagged"
[[ "$DRY_RUN" == "1" ]] && verb="would tag"
echo "$total resource(s): $changed $verb, $unchanged unchanged, $failed failed"

[[ $failed -eq 0 ]]
