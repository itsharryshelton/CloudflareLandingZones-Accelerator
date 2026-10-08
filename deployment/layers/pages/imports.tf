# Adopting Pages projects that already exist.
#
# WHY THIS FILE EXISTS
# Projects are usually created in the dashboard long before anyone writes them
# down. A project name is unique per account, so the first apply of this layer
# against an existing one does not create a duplicate - it fails, after the
# plan was approved. List what is there first:
#
#   curl -s -H "X-Auth-Email: $CLOUDFLARE_EMAIL" \
#     -H "X-Auth-Key: $CLOUDFLARE_API_KEY" \
#     "https://api.cloudflare.com/client/v4/accounts/<account_id>/pages/projects" \
#     | jq -r '.result[] | [.name, .subdomain, (.domains | join(","))] | @tsv'
#
# If that returns projects matching pages.tfvars, uncomment the blocks below.
# The project import id is "<account_id>/<project_name>" and the domain one is
# "<account_id>/<project_name>/<hostname>". `import` blocks are resolved at plan
# time, so an ordinary `cflz apply` carries the import - no separate
# `terraform import` run.
#
# A project with secret env vars cannot be imported: the API never returns the
# value, and the provider refuses. Remove the secrets in the dashboard, import,
# then let this layer set them again from TF_VAR_pages_project_secrets - which
# means a window with the secret absent. Schedule it.
#
# A CNAME that already exists for a custom domain is a dns_record import into
# module.pages_project[<key>].cloudflare_dns_record.this["<hostname>"], id
# "<zone_id>/<record_id>". Otherwise the apply tries to create a second record
# and the API refuses it.
#
# Read the first plan with these blocks in place before applying it. It
# reconciles what is at Cloudflare today against pages.tfvars, and a binding or
# env var somebody added in the dashboard shows up there as a removal.
#
# import {
#   for_each = {
#     # <logical key in pages_projects> = "<existing project name>"
#     # marketing_site = "marketing-site"
#   }
#
#   to = module.pages_project[each.key].cloudflare_pages_project.this
#   id = "${var.cloudflare_account_id}/${each.value}"
# }
#
# The domain block takes objects rather than a "<key>/<hostname>" string to
# split, because an import's `to` address may not call a function.
#
# import {
#   for_each = {
#     # <any unique label> = { project = "<logical key in pages_projects>", hostname = "<custom domain>", name = "<existing project name>" }
#     # marketing_www = { project = "marketing_site", hostname = "www.example.com", name = "marketing-site" }
#   }
#
#   to = module.pages_project[each.value.project].cloudflare_pages_domain.this[each.value.hostname]
#   id = "${var.cloudflare_account_id}/${each.value.name}/${each.value.hostname}"
# }