# Cloudflare WAN: the GRE and IPsec tunnels between the customer's sites and
# Cloudflare's edge, and the static routes that decide what goes down them.
#
# Modules are sourced by relative path from this repository's modules/
# directory, so a clone is self-contained and there is no tag to pin.
module "wan" {
  source = "../../../modules/wan"

  # Cloudflare WAN is account-scoped. No zone is involved, so this layer resolves nothing by name and makes no API call at plan time.
  account_id = var.cloudflare_account_id

  gre_tunnels   = local.gre_tunnels
  ipsec_tunnels = local.ipsec_tunnels

  # tunnel_key -> tunnel name, and from there to the customer end of the tunnel's /31, resolved in locals.tf.
  static_routes = local.static_routes
}
