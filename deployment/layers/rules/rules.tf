# Cache, transform and origin rulesets, per zone.
#
# Modules are sourced by relative path from this repository's modules/
# directory, so a clone is self-contained and there is no tag to pin.

# http_request_cache_settings.
module "cache_rules" {
  source = "../../../modules/cache_rules"

  for_each = local.cache_policies
  zone_id  = data.cloudflare_zone.this[each.value.zone_key].id

  rules = local.cache_rules_for_module[each.key]

  ruleset_name = coalesce(
    each.value.cache_ruleset_name,
    "Cache rules - ${var.zones[each.value.zone_key].domain_name}",
  )
}

# http_request_late_transform.
module "transform_rules" {
  source = "../../../modules/transform_rules"

  for_each = local.transform_policies
  zone_id  = data.cloudflare_zone.this[each.value.zone_key].id

  rules = each.value.transform_rules

  ruleset_name = coalesce(
    each.value.transform_ruleset_name,
    "Request headers - ${var.zones[each.value.zone_key].domain_name}",
  )
}

# http_request_origin.
module "origin_rules" {
  source = "../../../modules/origin_rules"

  for_each = local.origin_policies
  zone_id  = data.cloudflare_zone.this[each.value.zone_key].id

  rules = each.value.origin_rules

  ruleset_name = coalesce(
    each.value.origin_ruleset_name,
    "Origin rules - ${var.zones[each.value.zone_key].domain_name}",
  )
}
