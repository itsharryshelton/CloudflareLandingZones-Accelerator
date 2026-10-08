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
  # THIS LAYER'S STATE HOLDS THIRD-PARTY CREDENTIALS. Every service provider
  # integration's secret - an Intune app registration's client secret, a
  # CrowdStrike API client, a SentinelOne service user's API token, an Access
  # service token for a custom integration - is recorded in plain text, because
  # Terraform records what it sent. Each one reads device inventory out of an
  # MDM or EDR. Treat a leak of this state, or of a saved plan of this layer, as
  # a compromise of every one of them, and rotate them at the provider.
}
