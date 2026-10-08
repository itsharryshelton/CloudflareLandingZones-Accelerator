# Cloudflare Pages projects: static and Jamstack front ends, their branch
# deployment rules, runtime bindings and custom domains.
#
# Its own layer rather than part of workers. A Pages project is a separate
# product, and keeping it apart means a change to what a site serves is planned
# against its own state and cannot also rewrite the Workers in front of the API
# it calls.
#
# Access is deliberately not here. Protecting an internal portal is a zerotrust
# layer change; the pages_access_applications output is the hand-over, shaped
# to paste straight into zerotrust.tfvars.
#
# Modules are sourced by relative path from this repository's modules/
# directory, so a clone is self-contained and there is no tag to pin.
module "pages_project" {
  source = "../../../modules/pages_project"

  for_each = local.projects

  account_id        = var.cloudflare_account_id
  name              = each.value.name
  production_branch = each.value.production_branch

  git_source         = each.value.git_source
  build_config       = each.value.build_config
  deployment_configs = each.value.deployment_configs

  # Looked up by key rather than carried in local.projects, which is iterated
  # by for_each and so must stay non-sensitive. try() so a missing secret fails
  # in preflight, which names it, rather than here as a bare index error.
  secret_env_vars = {
    production = { for name in each.value.secret_names.production : name => try(var.pages_project_secrets[each.key].production[name], null) }
    preview    = { for name in each.value.secret_names.preview : name => try(var.pages_project_secrets[each.key].preview[name], null) }
  }

  # zone_key -> zone ID, resolved in zone_lookup.tf.
  custom_domains = each.value.custom_domains
}
