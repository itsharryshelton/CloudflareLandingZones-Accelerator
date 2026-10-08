# Credentials are read from the environment - never put one in a .tf or .tfvars.
# Set one of these, not both:
#   CLOUDFLARE_API_KEY and CLOUDFLARE_EMAIL   the Global API Key
#   CLOUDFLARE_API_TOKEN                      a scoped API token
#
# The Global API Key can already do everything this layer needs. A token used
# in its place needs, at minimum:
#   Account  Logs:Edit - account-scoped jobs: audit_logs, gateway_*, and the
#                        other account datasets
#   Zone     Logs:Edit - zone-scoped jobs: http_requests, firewall_events, and
#                        the other zone datasets
#   Zone     Zone:Read - so data.cloudflare_zone can resolve a zone_key to its ID
#
# Cloudflare's own documentation calls Logs:Edit "Logs: Write"; it is one grant.
#
# Jobs on an Access, Gateway or DEX dataset - access_requests, gateway_dns,
# gateway_http, gateway_network, dex_application_tests, dex_device_state_events -
# need one more, and Cloudflare will not create, change or delete such a job
# without it:
#   Account  Zero Trust: PII Read
provider "cloudflare" {}
