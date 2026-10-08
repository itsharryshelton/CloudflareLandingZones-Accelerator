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

module "cache_rules" {
  source = "../.."

  zone_id = "0123456789abcdef0123456789abcdef"

  # Broad rule first and the exception after it: the last matching rule wins in
  # this phase, so the reverse order would re-enable caching on /admin.
  rules = [
    {
      name       = "Cache static assets"
      expression = "http.request.uri.path.extension in {\"css\" \"js\" \"png\" \"svg\" \"woff2\"}"
      cache      = true

      edge_ttl = {
        mode    = "override_origin"
        default = 86400
      }

      browser_ttl = {
        mode = "respect_origin"
      }

      # Folds query-string variants onto one cached object.
      cache_key = {
        custom_key = {
          query_string = {
            exclude = { all = true }
          }
        }
      }
    },
    {
      name       = "Bypass admin"
      expression = "starts_with(http.request.uri.path, \"/admin\")"
      cache      = false
    },
  ]
}
