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

module "pages_project" {
  source = "../.."

  account_id        = "0123456789abcdef0123456789abcdef"
  name              = "example-site"
  production_branch = "main"

  # git_source is left unset: a Direct Upload project needs no Git app
  # installed, so nothing outside the plan has to exist.

  # A plain variable and a binding, so the null-for-empty mapping and the
  # binding name checks are exercised.
  deployment_configs = {
    production = {
      compatibility_date = "2025-01-01"
      env_vars = {
        SITE_ENV = "production"
      }
      kv_namespaces = {
        CONFIG = "0123456789abcdef0123456789abcdee"
      }
    }
  }

  # A zone_id, so the domain's CNAME is planned as well as the domain itself.
  custom_domains = [
    {
      hostname = "www.example.com"
      zone_id  = "0123456789abcdef0123456789abcded"
    },
  ]
}
