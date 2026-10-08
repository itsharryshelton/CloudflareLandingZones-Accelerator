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

module "transform_rules" {
  source = "../.."

  zone_id = "0123456789abcdef0123456789abcdef"

  # One rule per header operation, and one value from an expression, so every
  # branch of the header validation is exercised.
  rules = [
    {
      name       = "Tag requests for the origin"
      expression = "http.host eq \"app.example.com\""
      headers = {
        "X-Edge-Zone" = {
          operation = "set"
          value     = "example"
        }
        "X-Client-Country" = {
          operation  = "set"
          expression = "ip.src.country"
        }
      }
    },
    {
      name        = "Strip client-supplied forwarding header"
      expression  = "true"
      description = "Clients could forge it; the origin reads CF-Connecting-IP instead."
      headers = {
        "X-Forwarded-Host" = {
          operation = "remove"
        }
      }
    },
  ]
}
