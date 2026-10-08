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
  # THIS LAYER'S STATE HOLDS PRIVATE KEYS. Every client certificate uploaded
  # through var.origin_pull_certificates is recorded with its private key in
  # plain text, because Terraform records what it sent. Each one is an identity
  # the origin is being told to trust, so anyone holding this state - or a saved
  # plan of this layer - can present it and be accepted by that origin as though
  # they were the Cloudflare edge. Treat a leak of either as a compromise of
  # every certificate in it: revoke, upload a replacement, and only then remove
  # the old one from the origin's trust store.
}
