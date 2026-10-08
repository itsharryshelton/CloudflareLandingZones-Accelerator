# Credentials are read from the environment - never put one in a .tf or .tfvars.
# Set one of these, not both:
#   CLOUDFLARE_API_KEY and CLOUDFLARE_EMAIL   the Global API Key
#   CLOUDFLARE_API_TOKEN                      a scoped API token
#
# The Global API Key can already do everything this layer needs. A token used
# in its place needs, at minimum:
#   SSL and Certificates:Edit   the zone-level setting, the client certificates
#                               and the per-hostname associations all sit behind
#                               this one grant
#   Zone:Read                   so data.cloudflare_zone can resolve a zone key
#                               to its ID
#
# The certificates themselves do not come through the Cloudflare credential.
# They arrive as TF_VAR_origin_pull_certificates. See variables.tf.
provider "cloudflare" {}
