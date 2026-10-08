# Logpush: Cloudflare's logs - every HTTP request and firewall event on a zone,
# the account audit trail, Gateway and Access activity - pushed in batches to a
# SIEM or an object store as they are produced.
#
# ENTERPRISE ONLY
#
# One module instance per job.
#
# Modules are sourced by relative path from this repository's modules/
# directory, so a clone is self-contained and there is no tag to pin.
module "logpush_jobs" {
  source = "../../../modules/logpush_job"

  for_each = local.logpush_jobs

  # Exactly one of the two. zone_key -> zone ID, resolved in zone_lookup.tf.
  account_id = each.value.zone_id == null ? var.cloudflare_account_id : null
  zone_id    = each.value.zone_id

  name    = each.value.name
  dataset = each.value.dataset
  kind    = each.value.kind
  enabled = each.value.enabled
  filter  = each.value.filter

  # From logpush.tfvars or TF_VAR_logpush_destination_secrets, never both - see locals.tf.
  destination_conf    = local.destination_confs[each.key]
  ownership_challenge = lookup(var.logpush_ownership_challenges, each.key, null)

  max_upload_bytes            = each.value.max_upload_bytes
  max_upload_interval_seconds = each.value.max_upload_interval_seconds
  max_upload_records          = each.value.max_upload_records

  output_options = each.value.output_options
}
