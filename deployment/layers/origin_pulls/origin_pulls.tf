# Authenticated Origin Pulls: the client certificate the Cloudflare edge
# presents to the origin, zone-wide and per hostname.
#
# Its own layer rather than part of zones, because its state holds private
# keys, and putting them in the state that also owns every zone would make the
# most sensitive state in the repository the one most people need to plan
# against.
#
# One module instance per zone.
#
# Modules are sourced by relative path from this repository's modules/
# directory, so a clone is self-contained and there is no tag to pin.
module "origin_pulls" {
  source = "../../../modules/authenticated_origin_pulls"

  for_each = local.origin_pulls

  zone_id   = data.cloudflare_zone.this[each.key].zone_id
  zone_name = each.value.domain_name

  enabled               = each.value.enabled
  zone_certificate      = each.value.zone_certificate
  hostname_certificates = each.value.hostname_certificates
  hostnames             = each.value.hostnames

  origin_pull_ca_certificate = each.value.origin_pull_ca_certificate
}
