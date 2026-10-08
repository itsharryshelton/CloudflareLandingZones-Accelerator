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
  # This layer's state holds no credentials, but it does hold the complete egress
  # filtering posture of the estate: every category and application that is
  # inspected or bypassed, every DLP profile in force, and every internal range
  # named in a source or destination selector. Read as a whole it is a map of
  # what is watched and what is not, which is exactly what somebody planning to
  # move data out would want. Keep the state file private and treat a saved plan
  # file the same way.
}
