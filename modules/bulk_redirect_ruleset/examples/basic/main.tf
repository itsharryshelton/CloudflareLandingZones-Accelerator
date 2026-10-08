# Minimal usage example: a root module that plans this module on its own.
#
# It is planned with a dummy credential and no state, so it must stay
# offline-plannable: no data sources, and every input a literal. The IDs are
# placeholders from no real account; keep them that way so the example stays
# customer-agnostic.

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

module "bulk_redirect_ruleset" {
  source = "../.."

  account_id = "0123456789abcdef0123456789abcdef"

  # The lists are referenced by name only, so they need not exist for a plan.
  # One unscoped rule and one scoped, so both expression shapes are built.
  rules = [
    {
      list_name   = "marketing_redirects"
      description = "Retired campaign URLs"
    },
    {
      list_name       = "brand_b_redirects"
      scope_hostnames = ["www.example.net"]
      scope_domains   = ["example.org"]
    },
  ]
}
