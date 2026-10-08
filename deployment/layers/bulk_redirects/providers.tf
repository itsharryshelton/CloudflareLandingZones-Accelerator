# Credentials are read from the environment - never put one in a .tf or .tfvars.
# Set one of these, not both:
#   CLOUDFLARE_API_KEY and CLOUDFLARE_EMAIL   the Global API Key
#   CLOUDFLARE_API_TOKEN                      a scoped API token
#
# The Global API Key can already do everything this layer needs. A token used
# in its place needs, at minimum:
#   Account Filter Lists:Edit   the Bulk Redirect Lists, and any rows this layer
#                               manages inline
#   Account Rulesets:Edit       the http_request_redirect entry-point ruleset
#                               that switches each list on
#
# Nothing at zone scope. Bulk Redirects are an account-level product: each row
# carries its own hostname, and the rule is evaluated for every zone in the
# account, so this layer can redirect any hostname the account serves.
provider "cloudflare" {}
