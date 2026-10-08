<#
.SYNOPSIS
  Runs Terraform for one layer, from this machine, with the var files that
  layer takes. The bash twin is cflz.sh; keep the two in step.

.DESCRIPTION
  Each layer is a root module with its own state, and reads a different set of
  files from deployment/config/. The set is derived rather than listed: a
  config file belongs to a layer when the layer declares every variable the
  file assigns. So adding a layer or a config file needs no edit here, and a
  file that mixes two layers' variables is refused rather than half-applied.

  State is local: terraform.tfstate, in the layer's own directory. Nothing here
  configures a backend.

  The Cloudflare credential is read from the environment, one of:
    CLOUDFLARE_API_KEY + CLOUDFLARE_EMAIL   the Global API Key
    CLOUDFLARE_API_TOKEN                    a scoped API token, instead

.EXAMPLE
  .\scripts\cflz.ps1 layers

.EXAMPLE
  .\scripts\cflz.ps1 plan gateway

.EXAMPLE
  .\scripts\cflz.ps1 apply gateway

.EXAMPLE
  .\scripts\cflz.ps1 output zerotrust
#>

# No [CmdletBinding()] and no [Parameter()] attributes, on purpose: either one
# makes PowerShell reject Terraform's own flags (-out=tfplan, -target=...) as
# unknown parameters. Left plain, they fall through into $args untouched.
param(
  [string]$Command,
  [string]$Layer
)

$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot
$LayersDir = Join-Path $RepoRoot 'deployment/layers'
$ConfigDir = Join-Path $RepoRoot 'deployment/config'

function Stop-Run([string]$Message) {
  [Console]::Error.WriteLine("ERROR: $Message")
  exit 1
}

function Show-Usage {
  [Console]::Error.WriteLine(@'
usage: cflz.ps1 layers
       cflz.ps1 <terraform command> <layer> [terraform arguments...]

examples:
  cflz.ps1 plan gateway
  cflz.ps1 apply gateway
  cflz.ps1 output zerotrust
'@)
  exit 2
}

# Top-level variable assignments in a tfvars file. Anchored at column 0 so
# nested object keys, which are always indented in this repository, are ignored.
function Get-AssignedVariables([string]$Path) {
  @(Select-String -Path $Path -Pattern '^([a-zA-Z_][a-zA-Z0-9_]*)\s*=' |
      ForEach-Object { $_.Matches[0].Groups[1].Value } | Sort-Object -Unique)
}

function Get-DeclaredVariables([string]$LayerDir) {
  @(Get-ChildItem -Path $LayerDir -Filter '*.tf' -File |
      Select-String -Pattern '^variable\s+"([^"]+)"\s*\{' |
      ForEach-Object { $_.Matches[0].Groups[1].Value })
}

# Returns the config files a layer takes.
function Get-LayerVarFiles([string]$LayerName) {
  $declared = Get-DeclaredVariables (Join-Path $LayersDir $LayerName)
  $result = @()
  # Ordinal, so the order matches cflz.sh on every machine whatever its locale.
  $files = @(Get-ChildItem -Path $ConfigDir -Filter '*.tfvars' -File)
  [Array]::Sort($files, [Comparison[object]] { param($a, $b) [string]::CompareOrdinal($a.Name, $b.Name) })
  foreach ($file in $files) {
    # *.local.tfvars is a gitignored scratch file and is never picked up.
    if ($file.Name -like '*.local.tfvars') { continue }

    $assigned = Get-AssignedVariables $file.FullName
    # A file that assigns nothing is a commented-out template. Passing it buys
    # nothing, so it is skipped and the command line stays readable.
    if ($assigned.Count -eq 0) { continue }

    $matched = @($assigned | Where-Object { $declared -contains $_ })
    if ($matched.Count -eq $assigned.Count) {
      $result += $file
    }
    elseif ($matched.Count -gt 0) {
      # -var-file does not merge, so a file shared between two layers cannot be
      # split at run time. It has to be split on disk.
      Stop-Run ("$($file.FullName) assigns variables from more than one layer.`n" +
        "       $LayerName declares $($matched.Count) of them: $($assigned -join ' ')`n" +
        "       Split it so each file's variables belong to a single layer.")
    }
  }
  $result
}

function Show-Layers {
  '{0,-20} {1,-12} {2}' -f 'LAYER', 'NEEDS ZONES', 'CONFIG FILES'
  foreach ($dir in Get-ChildItem -Path $LayersDir -Directory | Sort-Object Name) {
    # A layer that resolves a zone by name cannot plan until the zones layer
    # has created it.
    $needs = '-'
    # Counted rather than -Quiet: fed from a pipeline, -Quiet answers once per
    # file, and an array of $false is still true.
    $lookups = @(Get-ChildItem -Path $dir.FullName -Filter '*.tf' -File |
        Select-String -Pattern '^\s*data\s+"cloudflare_zone"' -List)
    if ($lookups.Count -gt 0) { $needs = 'yes' }
    $files = (Get-LayerVarFiles $dir.Name | ForEach-Object { $_.Name }) -join ' '
    '{0,-20} {1,-12} {2}' -f $dir.Name, $needs, $files
  }
}

# A value pasted from a dashboard or a Windows clipboard often carries a
# trailing newline or carriage return. Cloudflare answers that with a generic
# authentication error, so it is caught here, where the cause can be named.
function Assert-NoWhitespace([string]$Name) {
  $value = [Environment]::GetEnvironmentVariable($Name)
  if ($value -match '\s') {
    Stop-Run "$Name contains whitespace or a line ending - set it again from the dashboard's own copy button"
  }
}

# Exactly one credential. With both set, the provider and the post-apply
# scripts would not all pick the same one.
function Assert-CloudflareCredential {
  $haveToken = [bool]$env:CLOUDFLARE_API_TOKEN
  $haveKey = [bool]$env:CLOUDFLARE_API_KEY -or [bool]$env:CLOUDFLARE_EMAIL

  if ($haveToken -and $haveKey) {
    Stop-Run 'both CLOUDFLARE_API_TOKEN and CLOUDFLARE_API_KEY/CLOUDFLARE_EMAIL are set - remove one, so every tool uses the same credential'
  }
  if ($haveToken) {
    Assert-NoWhitespace 'CLOUDFLARE_API_TOKEN'
    return
  }
  if ($env:CLOUDFLARE_API_KEY -and $env:CLOUDFLARE_EMAIL) {
    Assert-NoWhitespace 'CLOUDFLARE_API_KEY'
    Assert-NoWhitespace 'CLOUDFLARE_EMAIL'
    return
  }
  if ($haveKey) {
    Stop-Run 'the Global API Key needs both CLOUDFLARE_API_KEY and CLOUDFLARE_EMAIL - only one of them is set'
  }
  Stop-Run 'no Cloudflare credential in the environment. Set CLOUDFLARE_API_KEY and CLOUDFLARE_EMAIL (Global API Key), or CLOUDFLARE_API_TOKEN. See VARIABLES_AND_SECRETS.md'
}

if (-not $Command -or $Command -in @('-h', '--help', 'help')) { Show-Usage }
if ($Command -eq 'layers') {
  Show-Layers
  exit 0
}

if (-not $Layer) { Show-Usage }
$LayerDir = Join-Path $LayersDir $Layer
if (-not (Test-Path -Path $LayerDir -PathType Container)) {
  Stop-Run "no such layer '$Layer'. Run 'cflz.ps1 layers' to list them"
}
if (-not (Get-Command terraform -ErrorAction SilentlyContinue)) {
  Stop-Run 'terraform is not on PATH'
}

$needsVars = $Command -in @('plan', 'apply', 'destroy', 'import', 'refresh', 'console')
$needsApi = $Command -in @('plan', 'apply', 'destroy', 'import', 'refresh')

# `apply <planfile>`: a saved plan already carries its variables, and Terraform
# refuses -var-file alongside one. A bare argument is taken to be that file, so
# write flags as -target=addr rather than -target addr.
if ($Command -eq 'apply' -and @($args | Where-Object { "$_" -notlike '-*' }).Count -gt 0) {
  $needsVars = $false
}

if ($needsApi) { Assert-CloudflareCredential }

$tfArgs = @()
if ($needsVars) {
  if (-not (Test-Path -Path (Join-Path $ConfigDir 'account.tfvars'))) {
    Stop-Run 'deployment/config/account.tfvars is missing - every layer reads the account ID from it'
  }
  $tfArgs = @(Get-LayerVarFiles $Layer | ForEach-Object { "-var-file=../../config/$($_.Name)" })
}

# Terraform is run from inside the layer rather than with -chdir, so relative
# paths in its arguments and in the layer's file() calls mean the same thing
# here as they do in a hand-typed run.
Push-Location $LayerDir
try {
  # Everything this script says itself goes to stderr, init's output included,
  # so stdout is Terraform's alone and `cflz.ps1 output <layer> -json` can be
  # piped straight into ConvertFrom-Json.
  if ($Command -ne 'init' -and -not (Test-Path -Path '.terraform')) {
    [Console]::Error.WriteLine("==> terraform init ($Layer)")
    & terraform init '-input=false' | ForEach-Object { [Console]::Error.WriteLine($_) }
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  }

  [Console]::Error.WriteLine("==> terraform $Command ($Layer)")
  $tfArgs | ForEach-Object { [Console]::Error.WriteLine("    $_") }

  & terraform $Command @tfArgs @args
  exit $LASTEXITCODE
}
finally {
  Pop-Location
}
