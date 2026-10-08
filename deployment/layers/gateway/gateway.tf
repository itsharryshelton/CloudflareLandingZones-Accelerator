# Cloudflare Gateway (Secure Web Gateway): the DNS, network and HTTP policies
#
# One module instance. Gateway is account-scoped - no zone is involved - so
# there is no for_each here: the deployment is one account, and its ID comes
# from config/account.tfvars.
#
# Modules are sourced by relative path from this repository's modules/
# directory, so a clone is self-contained and there is no tag to pin.
module "gateway" {
  source = "../../../modules/gateway"

  account_id = var.cloudflare_account_id

  policies = local.gateway_policies

  # Account-level configuration, not a rule. Cloudflare keeps one of these per
  # account and it always exists, so it has to be imported before it is managed
  # here - see "Account Settings & TLS Decryption" in deployment/README.md -
  # or the first apply writes it from this configuration alone.
  settings = var.gateway_settings

  # The CA Gateway presents when it decrypts. Cloudflare provisions no
  # certificate with the account, so inspection cannot be enabled until one is
  # generated and activated - the module does both and points the configuration
  # above at the result.
  inspection_certificate = var.gateway_inspection_certificate

  allow_antivirus_fail_closed     = var.allow_antivirus_fail_closed
  allow_uninspected_http_policies = var.allow_uninspected_http_policies
}
