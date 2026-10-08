# Credentials are read from the environment - never put one in a .tf or .tfvars.
# Set one of these, not both:
#   CLOUDFLARE_API_KEY and CLOUDFLARE_EMAIL   the Global API Key
#   CLOUDFLARE_API_TOKEN                      a scoped API token
#
# The Global API Key can already do everything this layer needs. A token used
# in its place needs, at minimum:
#   Zone:Edit, DNS:Edit, Zone Settings:Edit
#   Bot Management:Edit           only if bot management is configured
#   Billing:Read, Billing:Write   only with manage_zone_subscriptions (or a
#                                 per-zone manage_subscription), because the
#                                 layer then changes rate plans
#
# The Global API Key always carries its user's billing rights, so
# manage_zone_subscriptions is the only thing standing between a zone_tier edit
# and a changed invoice. Leave it false unless a plan change is the point of
# the run.
provider "cloudflare" {}
