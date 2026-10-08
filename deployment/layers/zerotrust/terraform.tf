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
  # THIS LAYER'S STATE HOLDS LIVE CREDENTIALS. Every service token's client
  # secret is in it in plain text, because Cloudflare shows a generated secret
  # once and Terraform records what it received. So is every identity provider's
  # OAuth client secret, including the Entra ID one, because Terraform records
  # what it sent. Marking them sensitive hides them from console output; it does
  # not encrypt state.
  #
  # Treat a leak of this state as a credential compromise, not a configuration
  # disclosure: rotate every service token and every identity provider secret it
  # contains. Keep the state file off shared drives, and remember that a saved
  # plan file is exactly as sensitive.
}
