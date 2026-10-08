# Credentials are read from the environment - never put one in a .tf or .tfvars.
# Set one of these, not both:
#   CLOUDFLARE_API_KEY and CLOUDFLARE_EMAIL   the Global API Key
#   CLOUDFLARE_API_TOKEN                      a scoped API token
#
# The Global API Key can already do everything this layer needs. A token used
# in its place needs, at minimum:
#   Account Magic Transit:Edit
#
# The permission group is named after the older product and covers the whole
# /accounts/<id>/magic/ API surface.
#
# This is a networking change rather than a web one: deleting a tunnel takes a
# site off the network, and changing a static route sends a site's traffic
# somewhere else. Read the plan accordingly.
provider "cloudflare" {}
