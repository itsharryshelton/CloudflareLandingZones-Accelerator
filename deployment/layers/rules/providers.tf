# Credentials are read from the environment - never put one in a .tf or .tfvars.
# Set one of these, not both:
#   CLOUDFLARE_API_KEY and CLOUDFLARE_EMAIL   the Global API Key
#   CLOUDFLARE_API_TOKEN                      a scoped API token
#
# The Global API Key can already do everything this layer needs. A token used
# in its place needs, at minimum:
#   Zone Cache Rules:Edit       the http_request_cache_settings ruleset
#   Zone Transform Rules:Edit   the http_request_late_transform ruleset
#   Zone Origin Rules:Edit      the http_request_origin ruleset
#   Zone:Read                   so data.cloudflare_zone can resolve a zone key
#                               to its ID
provider "cloudflare" {}
