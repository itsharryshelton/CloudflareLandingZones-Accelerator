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

module "gateway" {
  source = "../.."

  account_id = "0123456789abcdef0123456789abcdef"

  # One policy per builder, so the per-type action and selector checks all run.
  # Precedences are unique account-wide, as Cloudflare requires.
  policies = [
    {
      name       = "Block security threats"
      type       = "dns"
      action     = "block"
      precedence = 10
      match = {
        security_category_ids = [68, 80]
      }
      settings = {
        block_page_enabled = true
      }
    },
    {
      name       = "Block outbound SMTP"
      type       = "network"
      action     = "block"
      precedence = 20
      match = {
        destination_ports = [25]
        protocols         = ["tcp"]
      }
    },
    {
      name       = "Block executable downloads"
      type       = "http"
      action     = "block"
      precedence = 30
      match = {
        download_file_types = ["exe"]
      }
    },
  ]

  # TLS decryption on, so the HTTP policy passes the uninspected-policy guard;
  # the managed CA is generated here rather than named by ID.
  settings = {
    tls_decrypt  = { enabled = true }
    activity_log = { enabled = true }
  }

  inspection_certificate = {}
}
