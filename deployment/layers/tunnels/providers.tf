# Credentials are read from the environment - never put one in a .tf or .tfvars.
# Set one of these, not both:
#   CLOUDFLARE_API_KEY and CLOUDFLARE_EMAIL   the Global API Key
#   CLOUDFLARE_API_TOKEN                      a scoped API token
#
# The Global API Key can already do everything this layer needs. A token used
# in its place needs, at minimum:
#   Account  Cloudflare Tunnel:Edit - tunnels, their remote configuration, private
#                                     network routes and virtual networks
#
# Public hostnames need two more, and only if an ingress rule names a zone_key:
#   Zone     Zone:Read              - so data.cloudflare_zone can resolve a key to its ID
#   Zone     DNS:Edit               - to write the proxied CNAME that points the
#                                     hostname at the tunnel
#
# What this layer can do is worth stating plainly. It can publish any internal
# service on a public hostname and route any private range to any connector.
# Who may reach either is decided in zerotrust and gateway, not here.
provider "cloudflare" {}
