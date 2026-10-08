# Account-scoped Cloudflare Lists, one module instance per list.
#
# Modules are sourced by relative path from this repository's modules/
# directory, so a clone is self-contained and there is no tag to pin.
module "account_list" {
  source = "../../../modules/account_list"

  for_each   = var.account_lists
  account_id = var.cloudflare_account_id

  name        = each.value.name
  kind        = each.value.kind
  description = each.value.description

  manage_items      = each.value.manage_items
  items             = each.value.items
  max_managed_items = each.value.max_managed_items
}
