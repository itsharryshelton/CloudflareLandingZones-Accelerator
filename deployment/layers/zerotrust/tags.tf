# Cloudflare resource tags for the Access applications this layer owns.
#
# The provider has no tagging resource yet, so nothing here calls the Tagging
# API. This resolves each application's complete tag set from var.resource_tags
# and outputs it with the application ID; scripts/resource-tags.sh, run by hand
# after the apply, writes it with the same credential Terraform used. The
# precedence rules are in config/tags.tfvars.
#
# These are resource tags, not the Access tags in access_applications[*].tags -
# those group applications inside the Zero Trust dashboard and are a separate
# feature with a separate API.
#
# When the provider ships a tagging resource, for_each it over
# local.access_application_resource_tags here and retire the script.

locals {
  # Merged last, so a config file cannot make a resource read as another
  # layer's. It records where a resource came from and nothing more: no tag
  # claims Terraform still manages it, because after handover it does not.
  fixed_tags = {
    layer = basename(abspath(path.module))
  }

  # Every application, not only those tags.tfvars lists: the fixed key is
  # what a `tag=!layer` filter relies on to find one this baseline did not
  # create.
  access_application_resource_tags = {
    for key in keys(var.access_applications) : key => {
      for k, v in merge(
        var.resource_tags.defaults,
        var.resource_tags.access_applications.defaults,
        lookup(var.resource_tags.access_applications.resources, key, {}),
        local.fixed_tags,
      ) : k => v if v != null
    }
  }

  # Preflight checks here. The shared settings and this layer's own section
  # only - another layer's section is that layer's to report.
  resource_tag_sources = merge(
    { "resource_tags.defaults" = var.resource_tags.defaults },
    { "resource_tags.access_applications.defaults" = var.resource_tags.access_applications.defaults },
    { for key, tags in var.resource_tags.access_applications.resources : "resource_tags.access_applications.resources.${key}" => tags },
  )

  resource_tag_problems = sort(concat(
    [
      for key in keys(var.resource_tags.access_applications.resources) : "resource_tags.access_applications.resources.${key} names no application in var.access_applications"
      if !contains(keys(var.access_applications), key)
    ],
    flatten([
      for path, tags in local.resource_tag_sources : concat(
        # ASCII only. Stricter than the API, which also takes letters from other
        # scripts, but a key somebody has to type into a filter should not need them.
        [for k in keys(tags) : "${path}: \"${k}\" is not a valid tag key (letters, digits, _ . - only, at most 256)" if !can(regex("^[a-zA-Z0-9_.-]{1,256}$", k))],
        [for k in keys(tags) : "${path}: \"${k}\" is set by the layer and cannot be set here" if contains(keys(local.fixed_tags), k)],
        [for k, v in { for k, v in tags : k => v if v != null } : "${path}.${k} is longer than 1024 characters" if length(v) > 1024],
        [
          for k, v in { for k, v in tags : k => v if v != null } :
          "${path}.${k} = \"${v}\" is not one of: ${join(", ", var.resource_tags.allowed_values[k])}"
          if contains(keys(var.resource_tags.allowed_values), k) && !contains(lookup(var.resource_tags.allowed_values, k, []), v)
        ],
      )
    ]),
  ))
}

output "resource_tags" {
  description = "Tag manifest for scripts/resource-tags.sh: every Access application this layer owns, its ID, and the complete tag set it should carry. Read from state after apply, when the IDs are known."
  value = {
    account_id = var.cloudflare_account_id
    layer      = local.fixed_tags.layer
    resources = [
      for key in sort(keys(local.access_application_resource_tags)) : {
        address       = "access_applications.${key}"
        resource_type = "access_application"
        # The module keys applications by normalised name, not by this layer's key.
        resource_id = module.zerotrust.access_applications[lower(trimspace(var.access_applications[key].name))].id
        zone_id     = null
        tags        = local.access_application_resource_tags[key]
      }
    ]
  }
}
