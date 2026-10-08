# Minimal usage example: a root module that plans this module on its own.
#
# It is planned with a dummy credential and no state, so it must stay
# offline-plannable: no data sources, and every input a literal. The IDs are
# placeholders from no real account; keep them that way so the example stays
# customer-agnostic.

terraform {
  required_version = ">= 1.12.0"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.7"
    }
  }
}

# Reads its credential from the environment. An offline plan only creates, so
# a dummy CLOUDFLARE_API_TOKEN is enough.
provider "cloudflare" {}

module "queue" {
  source = "../.."

  account_id = "0123456789abcdef0123456789abcdef"
  queue_name = "example-jobs"

  settings = {
    message_retention_period = 345600
  }

  # A push consumer, so the consumer resource and its preconditions are planned.
  # The Worker is named literally here; a layer passes the deployed Worker's name.
  consumer = {
    type              = "worker"
    script_name       = "example-consumer"
    dead_letter_queue = "example-jobs-dlq"
    settings = {
      batch_size  = 10
      max_retries = 3
      retry_delay = 30
    }
  }
}
