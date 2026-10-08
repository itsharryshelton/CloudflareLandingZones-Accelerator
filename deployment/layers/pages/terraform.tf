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
  # THIS LAYER'S STATE HOLDS EVERY PAGES SECRET in plain text. Cloudflare never
  # returns a secret_text value, but Terraform records what it sent, so each
  # value in TF_VAR_pages_project_secrets ends up here. So does every plain env
  # var and every binding ID. Treat a leak of this state, or of a saved plan of
  # this layer, as a leak of those secrets.
  #
  # Losing this state is less severe than for turnstile but not free: a rebuilt
  # state tries to create projects that already exist, and the API refuses. Adopt
  # them instead - see imports.tf.
}
