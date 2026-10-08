terraform {
  required_version = ">= 1.12.0"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.7"
    }
  }

  # ---------------------------------------------------------------------------
  # State: local, next to this file
  # ---------------------------------------------------------------------------
  # No backend is declared, so `terraform init` uses the local backend and
  # writes terraform.tfstate into this directory. The Accelerator deploys a
  # baseline once, from a workstation, so there is no pipeline or second
  # operator to share state with. .gitignore keeps the file out of version
  # control; the root README covers what to do with it after handover.
  #
  # This layer holds the account's single http_request_redirect entry-point
  # ruleset. Two states declaring that ruleset overwrite each other's rules on
  # alternate applies with no error from either, so it must live here and nowhere
  # else - including any hand-run Terraform.
}
