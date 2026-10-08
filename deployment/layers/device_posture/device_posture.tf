# CF1 Device Posture
#
# Its own layer rather than part of zerotrust, because two layers consume it:
# Access policies in zerotrust and Gateway policies in gateway both take a
# posture rule's ID.
#
# One module instance for the account.
#
# Modules are sourced by relative path from this repository's modules/
# directory, so a clone is self-contained and there is no tag to pin.
module "device_posture" {
  source = "../../../modules/device_posture"

  account_id = var.cloudflare_account_id

  integrations = local.integrations
  rules        = local.rules
}
