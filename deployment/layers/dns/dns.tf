# DNS records
#
# Modules are sourced by relative path from this repository's modules/
# directory, so a clone is self-contained and there is no tag to pin.
module "dns" {
  source = "../../../modules/dns_records"

  for_each = local.zones_with_records

  zone_id     = data.cloudflare_zone.this[each.key].zone_id
  domain_name = each.value.domain_name

  records = each.value.dns_records
}
