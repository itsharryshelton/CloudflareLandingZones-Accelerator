#!/usr/bin/env bash

# _common.sh - sourced by the other scripts in this directory, never run.
#
# Holds the two things every script has to agree on: where the repository is,
# and which Cloudflare credential a run uses. The Accelerator runs on one
# credential for every layer, read from the environment:
#
#   CLOUDFLARE_API_KEY + CLOUDFLARE_EMAIL   the Global API Key
#   CLOUDFLARE_API_TOKEN                    a scoped API token, instead
#
# Exactly one of the two. With both set, the Terraform provider, wrangler and
# curl would not all pick the same one, and the run would be half one identity
# and half another.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LAYERS_DIR="$REPO_ROOT/deployment/layers"
CONFIG_DIR="$REPO_ROOT/deployment/config"

die() {
  echo "ERROR: $*" >&2
  exit 1
}

# The post-apply scripts use associative arrays and mapfile. macOS still ships
# bash 3.2, which has neither and fails on them with a syntax error that names
# neither.
require_bash4() {
  if ((BASH_VERSINFO[0] < 4)); then
    die "$(basename "$0") needs bash 4 or newer; this is $BASH_VERSION (on macOS: brew install bash)"
  fi
}

require_tools() {
  local tool
  for tool in "$@"; do
    command -v "$tool" >/dev/null || die "$tool is not on PATH"
  done
}

# A value pasted from a dashboard or a Windows clipboard often carries a
# trailing newline or carriage return. Cloudflare answers that with a generic
# authentication error, so it is caught here, where the cause can be named.
_reject_whitespace() {
  local name="$1" value="${!1:-}"
  if [[ "$value" =~ [[:space:]] ]]; then
    die "$name contains whitespace or a line ending - set it again from the dashboard's own copy button"
  fi
}

require_cloudflare_credential() {
  local have_token=false have_key=false
  [[ -n "${CLOUDFLARE_API_TOKEN:-}" ]] && have_token=true
  [[ -n "${CLOUDFLARE_API_KEY:-}" || -n "${CLOUDFLARE_EMAIL:-}" ]] && have_key=true

  if $have_token && $have_key; then
    die "both CLOUDFLARE_API_TOKEN and CLOUDFLARE_API_KEY/CLOUDFLARE_EMAIL are set - unset one, so every tool uses the same credential"
  fi

  if $have_token; then
    _reject_whitespace CLOUDFLARE_API_TOKEN
    return 0
  fi

  if [[ -n "${CLOUDFLARE_API_KEY:-}" && -n "${CLOUDFLARE_EMAIL:-}" ]]; then
    _reject_whitespace CLOUDFLARE_API_KEY
    _reject_whitespace CLOUDFLARE_EMAIL
    return 0
  fi

  if $have_key; then
    die "the Global API Key needs both CLOUDFLARE_API_KEY and CLOUDFLARE_EMAIL - only one of them is set"
  fi

  die "no Cloudflare credential in the environment. Set CLOUDFLARE_API_KEY and CLOUDFLARE_EMAIL (Global API Key), or CLOUDFLARE_API_TOKEN. See VARIABLES_AND_SECRETS.md"
}

# The account ID is configuration, already in deployment/config/account.tfvars,
# so the scripts read it from there rather than asking for it a second time.
# CLOUDFLARE_ACCOUNT_ID in the environment wins, for the rare run that needs it.
resolve_account_id() {
  if [[ -z "${CLOUDFLARE_ACCOUNT_ID:-}" ]]; then
    CLOUDFLARE_ACCOUNT_ID="$(sed -nE 's/^cloudflare_account_id[[:space:]]*=[[:space:]]*"([0-9a-fA-F]{32})".*/\1/p' \
      "$CONFIG_DIR/account.tfvars" 2>/dev/null | head -n1)"
  fi
  [[ -n "${CLOUDFLARE_ACCOUNT_ID:-}" ]] ||
    die "no account ID: set cloudflare_account_id in deployment/config/account.tfvars, or CLOUDFLARE_ACCOUNT_ID"
  export CLOUDFLARE_ACCOUNT_ID
}
