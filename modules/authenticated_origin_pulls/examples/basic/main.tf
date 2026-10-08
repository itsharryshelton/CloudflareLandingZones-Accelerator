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

module "authenticated_origin_pulls" {
  source = "../.."

  zone_id   = "0123456789abcdef0123456789abcdef"
  zone_name = "example.com"
  enabled   = true

  # Points at a pre-uploaded certificate by ID rather than uploading one here:
  # a PEM private key, even a dummy one, would trip the repo's secret scanner.
  # The relative label also exercises hostname qualification.
  hostnames = [
    {
      hostname       = "api"
      certificate_id = "00000000-0000-4000-8000-000000000001"
    },
  ]
}
