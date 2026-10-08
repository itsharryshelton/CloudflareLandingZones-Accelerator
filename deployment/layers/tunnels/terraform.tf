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
  # THIS LAYER'S STATE HOLDS NO CONNECTOR CREDENTIAL. No tunnel secret is sent, so
  # Cloudflare generates one it never returns, and the connector token is never
  # read. What state does hold is a map of the internal estate: every published
  # hostname, the internal service URL behind it, and every private range and
  # the tunnel that reaches it. Keep it as private as any other layer's.
}
