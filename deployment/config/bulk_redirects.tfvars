# Bulk Redirects. Consumed by the bulk_redirects layer only.
#
#   scripts/cflz.sh plan bulk_redirects
#
# Bulk Redirects match URL redirects at Cloudflare before reaching a Worker or
# origin - with no invocation, no KV read, and no per-request cost.

# Lists
# `manage_items` defaults to false: Terraform provisions the list container and
# large datasets are loaded outside Terraform, through the Lists API.
# Setting `manage_items = true` instructs Terraform to manage inline rows directly.

bulk_redirect_lists = {
  # Example 1: Large redirect dataset loaded outside Terraform (unmanaged rows in Terraform)
  marketing_campaigns = {
    name        = "redirects_marketing_campaigns"
    description = "Marketing and campaign redirects. Rows loaded outside Terraform."
  }

  # Example 2: Small set of static vanity URL redirects managed directly in Terraform
  vanity_urls = {
    name         = "redirects_vanity_urls"
    description  = "Static vanity redirects managed directly in Terraform."
    manage_items = true

    items = [
      {
        source_url            = "example.com/docs"
        target_url            = "https://example.com/documentation"
        status_code           = 301
        preserve_query_string = true
        comment               = "Redirect legacy documentation path"
      },
      {
        source_url            = "www.example.com/promo"
        target_url            = "https://www.example.com/promotions"
        status_code           = 302
        preserve_query_string = true
        subpath_matching      = true
        preserve_path_suffix  = true
        comment               = "Temporary promotion redirect with subpath preservation"
      },
    ]
  }
}

# Rules - evaluated in sequence
# Cloudflare stops at the first matching redirect rule.
# Every rule is scoped to its zone or specific hostnames for blast radius control.

bulk_redirect_rules = [
  {
    list_key        = "vanity_urls"
    description     = "Vanity URLs for example.com"
    scope_zone_keys = ["primary"]
  },
  {
    list_key        = "marketing_campaigns"
    description     = "Marketing campaign redirects for example.com"
    scope_zone_keys = ["primary"]
  },
]
