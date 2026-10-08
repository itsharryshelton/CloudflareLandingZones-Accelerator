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

module "dns_records" {
  source = "../.."

  zone_id     = "0123456789abcdef0123456789abcdef"
  domain_name = "example.com"

  # "@", a relative label, an already-qualified name and an MX, so every branch
  # of the name qualification and the priority rule are exercised - plus a CNAME
  # targeting "@", for the content normalisation.
  records = [
    {
      name    = "@"
      type    = "A"
      content = "192.0.2.10"
      proxied = true
    },
    {
      name    = "www"
      type    = "CNAME"
      content = "@"
      proxied = true
      comment = "Marketing site"
    },
    {
      name    = "api.example.com"
      type    = "AAAA"
      content = "2001:db8::10"
      ttl     = 300
    },
    {
      name     = "@"
      type     = "MX"
      content  = "mail.example.net"
      priority = 10
      ttl      = 3600
    },
  ]
}
