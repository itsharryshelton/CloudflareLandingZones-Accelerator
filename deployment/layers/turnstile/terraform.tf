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
  # THIS LAYER'S STATE HOLDS EVERY WIDGET'S SECRET KEY in plain text, because
  # Terraform records what the API returned. That key is the whole of the
  # server-side half of Turnstile: anyone holding it can forge a passing
  # /siteverify response for any form the widget protects. It cannot be rotated
  # in place either - a new secret means a new widget, and a new widget means a
  # new sitekey and a redeploy of every page embedding it. Treat a leak of this
  # state, or of a saved plan of this layer, accordingly.
  #
  # Losing this state is the other failure mode worth naming. A rebuilt state
  # creates fresh widgets with fresh sitekeys while the live pages still carry
  # the old ones, which fails every challenge on every protected form at once.
  # Adopt the existing widgets instead - see imports.tf.
}
