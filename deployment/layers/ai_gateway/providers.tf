# Credentials are read from the environment - never put one in a .tf or .tfvars.
# Set one of these, not both:
#   CLOUDFLARE_API_KEY and CLOUDFLARE_EMAIL   the Global API Key
#   CLOUDFLARE_API_TOKEN                      a scoped API token
#
# The Global API Key can already do everything this layer needs. A token used
# in its place needs, at minimum:
#   AI Gateway:Edit   (the API refers to the same grant as AI Gateway Write)
#
# Either credential can read and delete every gateway's logs, and those logs
# are prompts and responses. Keep that in mind when deciding what collect_logs
# is set to.
#
# BYOK provider keys are a different permission (Secrets Store Write) and are
# not managed by this layer at all - see ai_gateway.tf.
provider "cloudflare" {}
