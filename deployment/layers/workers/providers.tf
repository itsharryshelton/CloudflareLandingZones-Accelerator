# Credentials are read from the environment - never put one in a .tf or .tfvars.
# Set one of these, not both:
#   CLOUDFLARE_API_KEY and CLOUDFLARE_EMAIL   the Global API Key
#   CLOUDFLARE_API_TOKEN                      a scoped API token
#
# The Global API Key can already do everything this layer needs. A token used
# in its place needs, at minimum:
#   Account Workers Scripts:Edit      the Worker itself, its bindings and its
#                                     cron triggers
#   Account Workers KV Storage:Edit   the namespaces, and any pairs this layer
#                                     manages
#   Account D1:Edit                   the databases; also what the migration
#                                     script runs under
#   Account Queues:Edit               the queues and their consumers
#   Zone Workers Routes:Edit          only if var.worker_scripts declares routes
#   Zone:Read                         so data.cloudflare_zone can resolve a zone
#                                     key to its ID
#   Zone DNS:Edit                     only for custom domains, which Cloudflare
#                                     implements by writing the record itself
#
# A Worker on a route sits in front of the origin for every request it matches,
# so this layer can change what a site returns without touching DNS or the
# origin. It is a bigger change than the resource list suggests.
#
# Bindings do not need scope over what they point at. Binding a KV namespace or
# an R2 bucket is a Workers Scripts operation.
provider "cloudflare" {}
