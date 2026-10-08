# Cloudflare Turnstile widgets.
#
# Its own layer rather than part of waf, because a widget is not a rule and is
# not zone-scoped: it is a key pair plus a hostname list, consumed by a page and
# a backend that Terraform does not manage. Nothing else in this repository
# reads it, and it reads nothing - which is the point. An apply here can never
# propose a change to a zone, a ruleset or a DNS record.
#
# It also means the layer cannot verify the thing that actually matters. Whether
# a form is protected depends on the sitekey pasted into the page and the secret
# configured in the backend, and neither is visible from here. See outputs.tf
# for the values to hand over, and imports.tf before a first apply.
#
# Modules are sourced by relative path from this repository's modules/
# directory, so a clone is self-contained and there is no tag to pin.
module "turnstile" {
  source = "../../../modules/turnstile"

  account_id = var.cloudflare_account_id

  widgets                = local.widgets
  max_domains_per_widget = var.max_domains_per_widget
}
