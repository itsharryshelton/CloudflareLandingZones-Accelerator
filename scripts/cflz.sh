#!/usr/bin/env bash

# cflz.sh <command> <layer> [terraform arguments...]
#
# Runs Terraform for one layer, from this machine, with the var files that
# layer takes. The PowerShell twin is cflz.ps1; keep the two in step.
#
#   $ scripts/cflz.sh layers              # every layer, and the config it reads
#   $ scripts/cflz.sh plan gateway
#   $ scripts/cflz.sh apply gateway
#   $ scripts/cflz.sh output zerotrust
#
# <command> is any Terraform subcommand, passed straight through. Anything
# after the layer name goes to Terraform untouched.
#
# WHY A WRAPPER
# -------------
# Each layer is a root module with its own state, and reads a different set of
# files from deployment/config/. The set is derived rather than listed: a
# config file belongs to a layer when the layer declares every variable the
# file assigns. So adding a layer or a config file needs no edit here, and a
# file that mixes two layers' variables is refused rather than half-applied.
#
# State is local: terraform.tfstate, in the layer's own directory. Nothing here
# configures a backend.
#
# Written for bash 3.2, which is what macOS ships, so no mapfile and no
# associative arrays.

set -euo pipefail

# shellcheck source=scripts/_common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

usage() {
  cat >&2 <<'EOF'
usage: cflz.sh layers
       cflz.sh <terraform command> <layer> [terraform arguments...]

examples:
  cflz.sh plan gateway
  cflz.sh apply gateway
  cflz.sh output zerotrust
EOF
  exit 2
}

# Top-level variable assignments in a tfvars file. Anchored at column 0 so
# nested object keys, which are always indented in this repository, are ignored.
tfvars_assignments() {
  grep -oE '^[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*=' "$1" 2>/dev/null |
    sed 's/[[:space:]]*=$//' | LC_ALL=C sort -u
}

layer_declares_var() {
  grep -hqE "^variable[[:space:]]+\"$2\"[[:space:]]*\{" "$LAYERS_DIR/$1"/*.tf 2>/dev/null
}

# Prints the config files a layer takes, one path per line.
layer_varfiles() {
  local layer="$1" varfile v assigned declared undeclared
  for varfile in "$CONFIG_DIR"/*.tfvars; do
    [[ -e "$varfile" ]] || continue
    # *.local.tfvars is a gitignored scratch file and is never picked up.
    case "$(basename "$varfile")" in *.local.tfvars) continue ;; esac

    assigned="$(tfvars_assignments "$varfile")"
    # A file that assigns nothing is a commented-out template. Passing it buys
    # nothing, so it is skipped and the command line stays readable.
    [[ -n "$assigned" ]] || continue

    declared=0
    undeclared=0
    for v in $assigned; do
      if layer_declares_var "$layer" "$v"; then
        declared=$((declared + 1))
      else
        undeclared=$((undeclared + 1))
      fi
    done

    if [[ $undeclared -eq 0 ]]; then
      echo "$varfile"
    elif [[ $declared -gt 0 ]]; then
      # -var-file does not merge, so a file shared between two layers cannot be
      # split at run time. It has to be split on disk.
      echo "ERROR: $varfile assigns variables from more than one layer." >&2
      echo "       $layer declares $declared of them: $(echo $assigned)" >&2
      echo "       Split it so each file's variables belong to a single layer." >&2
      return 1
    fi
  done
}

list_layers() {
  local dir layer needs files
  printf '%-20s %-12s %s\n' "LAYER" "NEEDS ZONES" "CONFIG FILES"
  for dir in "$LAYERS_DIR"/*/; do
    layer="$(basename "$dir")"
    # A layer that resolves a zone by name cannot plan until the zones layer
    # has created it.
    if grep -qE '^[[:space:]]*data[[:space:]]+"cloudflare_zone"' "$dir"*.tf 2>/dev/null; then
      needs="yes"
    else
      needs="-"
    fi
    files="$(layer_varfiles "$layer" | sed 's|.*/||' | tr '\n' ' ')"
    printf '%-20s %-12s %s\n' "$layer" "$needs" "$files"
  done
}

COMMAND="${1:-}"
case "$COMMAND" in
  "" | -h | --help | help) usage ;;
  layers)
    list_layers
    exit 0
    ;;
esac

LAYER="${2:-}"
[[ -n "$LAYER" ]] || usage
LAYER_DIR="$LAYERS_DIR/$LAYER"
[[ -d "$LAYER_DIR" ]] || die "no such layer '$LAYER'. Run 'cflz.sh layers' to list them"
shift 2

require_tools terraform

needs_vars=false
needs_api=false
case "$COMMAND" in
  plan | apply | destroy | import | refresh)
    needs_vars=true
    needs_api=true
    ;;
  console) needs_vars=true ;;
esac

# `apply <planfile>`: a saved plan already carries its variables, and Terraform
# refuses -var-file alongside one. A bare argument is taken to be that file, so
# write flags as -target=addr rather than -target addr.
if [[ "$COMMAND" == "apply" ]]; then
  for arg in "$@"; do
    [[ "$arg" == -* ]] || needs_vars=false
  done
fi

if $needs_api; then
  require_cloudflare_credential
fi

# Terraform is run from inside the layer rather than with -chdir, so relative
# paths in its arguments and in the layer's file() calls mean the same thing
# here as they do in a hand-typed run.
cd "$LAYER_DIR"

# Everything this script says itself goes to stderr, init's output included, so
# stdout is Terraform's alone and `cflz.sh output <layer> -json | jq` works.
if [[ "$COMMAND" != "init" && ! -d .terraform ]]; then
  echo "==> terraform init ($LAYER)" >&2
  terraform init -input=false >&2
fi

tf_args=()
if $needs_vars; then
  [[ -f "$CONFIG_DIR/account.tfvars" ]] || die "deployment/config/account.tfvars is missing - every layer reads the account ID from it"
  varfiles="$(layer_varfiles "$LAYER")"
  while IFS= read -r varfile; do
    [[ -n "$varfile" ]] || continue
    tf_args+=("-var-file=../../config/$(basename "$varfile")")
  done <<<"$varfiles"
fi

echo "==> terraform $COMMAND ($LAYER)" >&2
for arg in ${tf_args[@]+"${tf_args[@]}"}; do
  echo "    $arg" >&2
done

exec terraform "$COMMAND" ${tf_args[@]+"${tf_args[@]}"} "$@"
