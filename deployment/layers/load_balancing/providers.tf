# Credentials are read from the environment - never put one in a .tf or .tfvars.
# Set one of these, not both:
#   CLOUDFLARE_API_KEY and CLOUDFLARE_EMAIL   the Global API Key
#   CLOUDFLARE_API_TOKEN                      a scoped API token
#
# The Global API Key can already do everything this layer needs. A token used
# in its place needs, at minimum:
#   Account Load Balancers:Edit   monitors and pools are account-scoped
#   Zone Load Balancers:Edit
#   Zone:Read                     so data.cloudflare_zone can resolve a domain
#                                 to its ID
provider "cloudflare" {}
