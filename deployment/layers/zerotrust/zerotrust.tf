# Zero Trust Access: the organization, its login methods, its audiences and the
# applications behind it.
#
# One module instance for the account, because one Cloudflare account is one
# Zero Trust organization. There is no for_each here: the account is the run,
# and its ID comes from config/account.tfvars.
#
# Modules are sourced by relative path from this repository's modules/
# directory, so a clone is self-contained and there is no tag to pin.
module "zerotrust" {
  source = "../../../modules/zerotrust"

  account_id = var.cloudflare_account_id

  organization        = local.organization
  identity_providers  = local.identity_providers
  service_tokens      = local.service_tokens
  access_groups       = local.access_groups
  access_policies     = local.access_policies
  access_applications = local.access_applications
}
