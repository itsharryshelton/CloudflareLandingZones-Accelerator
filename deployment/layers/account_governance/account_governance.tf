# Account memberships, user groups and group membership.
#
# One module instance, because one Cloudflare account is one set of people.
# There is no for_each here: the deployment is one account, and its ID comes
# from config/account.tfvars.
#
# Modules are sourced by relative path from this repository's modules/
# directory, so a clone is self-contained and there is no tag to pin.
module "account_governance" {
  source = "../../../modules/account_governance"

  account_id = var.cloudflare_account_id

  members     = local.members
  user_groups = local.user_groups
}
