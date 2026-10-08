# Credentials are read from the environment - never put one in a .tf or .tfvars.
# Set one of these, not both:
#   CLOUDFLARE_API_KEY and CLOUDFLARE_EMAIL   the Global API Key
#   CLOUDFLARE_API_TOKEN                      a scoped API token
#
# The Global API Key can already do everything this layer needs. A token used
# in its place needs, at minimum:
#   Account  Cloudflare Pages:Edit  - projects, their deployment configs and
#                                     custom domains
#   Zone     Zone:Read              - so data.cloudflare_zone can resolve a key
#                                     to its ID; only if a custom domain names a
#                                     zone_key
#   Zone     DNS:Edit               - the CNAME behind each such custom domain
#
# Pages:Edit is bigger than it reads. It can change what a production site
# serves - by repointing the Git source, or by a Direct Upload of any build -
# and it can read every project's plain env vars.
#
# Access applications for these projects are written by the zerotrust layer;
# this layer only reports the hostnames they must cover (see outputs.tf).
provider "cloudflare" {}
