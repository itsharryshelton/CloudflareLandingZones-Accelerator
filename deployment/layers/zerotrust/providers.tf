# Credentials are read from the environment - never put one in a .tf or .tfvars.
# Set one of these, not both:
#   CLOUDFLARE_API_KEY and CLOUDFLARE_EMAIL   the Global API Key
#   CLOUDFLARE_API_TOKEN                      a scoped API token
#
# The Global API Key can already do everything this layer needs. A token used
# in its place needs, at minimum:
#   Access: Organizations, Identity Providers, and Groups:Edit
#   Access: Apps and Policies:Edit
#   Access: Service Tokens:Edit
#
# One secret does not come through the Cloudflare credential. An identity
# provider's OAuth client secret - the Entra ID app registration's - arrives
# separately as TF_VAR_identity_provider_secrets. See variables.tf.
provider "cloudflare" {}
