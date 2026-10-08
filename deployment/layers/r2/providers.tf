# Credentials are read from the environment - never put one in a .tf or .tfvars.
# Set one of these, not both:
#   CLOUDFLARE_API_KEY and CLOUDFLARE_EMAIL   the Global API Key
#   CLOUDFLARE_API_TOKEN                      a scoped API token
#
# The Global API Key can already do everything this layer needs. A token used
# in its place needs, at minimum:
#   Account Workers R2 Storage:Edit   the bucket itself and every configuration
#                                     object hanging off it - CORS, lifecycle,
#                                     object lock and the r2.dev public URL
#
# Custom domains need two more, and only if var.r2_buckets declares any:
#   Zone:Read       so data.cloudflare_zone can resolve a domain to its ID
#   Zone DNS:Edit   because attaching a custom domain writes the record that
#                   points the hostname at the bucket
#
# Neither credential is used for object data: R2 object reads and writes go
# through an S3 access key, which this layer neither creates nor holds.
# Terraform manages the bucket; the application owns what is in it.
provider "cloudflare" {}
