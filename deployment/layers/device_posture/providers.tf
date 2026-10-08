# Credentials are read from the environment - never put one in a .tf or .tfvars.
# Set one of these, not both:
#   CLOUDFLARE_API_KEY and CLOUDFLARE_EMAIL   the Global API Key
#   CLOUDFLARE_API_TOKEN                      a scoped API token
#
# The Global API Key can already do everything this layer needs. A token used
# in its place needs, at minimum:
#   Zero Trust:Edit   (the API refers to the same grant as Zero Trust Write)
#
# The third-party credentials an integration connects with do not come through
# the Cloudflare credential. They arrive as
# TF_VAR_device_posture_integration_secrets. See variables.tf.
provider "cloudflare" {}
