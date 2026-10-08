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

module "zerotrust" {
  source = "../.."

  account_id = "0123456789abcdef0123456789abcdef"

  organization = {
    team_name        = "example"
    session_duration = "24h"
    is_ui_read_only  = true
  }

  # One-time PIN needs no client secret, so the fixture stays free of credentials.
  identity_providers = [
    {
      name = "Email PIN"
      type = "onetimepin"
    },
  ]

  service_tokens = [
    {
      name     = "CI deploy"
      duration = "8760h"
    },
  ]

  # Every cross-reference below is by name, so the name-to-ID resolution and
  # its unknown-reference preconditions are exercised within a single plan.
  access_groups = [
    {
      name = "Staff"
      include = {
        email_domains = ["example.com"]
      }
    },
  ]

  access_policies = [
    {
      name     = "Staff via email PIN"
      decision = "allow"
      include = {
        group_names = ["Staff"]
      }
      require = {
        login_method_names = ["Email PIN"]
      }
    },
    {
      name     = "CI service token"
      decision = "non_identity"
      include = {
        service_token_names = ["CI deploy"]
      }
    },
  ]

  access_applications = [
    {
      name         = "Internal dashboard"
      domain       = "dashboard.example.com"
      policy_names = ["Staff via email PIN", "CI service token"]
    },
  ]
}
