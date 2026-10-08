# Minimal usage example: a root module that plans this module on its own.
#
# It is planned with a dummy credential and no state, so it must stay
# offline-plannable: no data sources, and every input a literal. The IDs are
# placeholders from no real account; keep them that way so the example stays
# customer-agnostic.
#
# When you copy this directory to modules/<name>, keep examples/basic and fill in
# the module block below so the plan creates at least one of each resource the
# module manages. A module with required inputs and no example cannot be planned on its own.

terraform {
  required_version = ">= 1.12.0"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.7"
    }
  }
}

# Reads its credential from the environment. An offline plan only creates, so
# a dummy CLOUDFLARE_API_TOKEN is enough.
provider "cloudflare" {}

module "template" {
  source = "../.."

  # zone_id    = "0123456789abcdef0123456789abcdef"
  # account_id = "0123456789abcdef0123456789abcdef"
}
