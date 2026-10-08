terraform {
  # 1.12 is the floor: the modules this layer calls rely on `||` and `&&`
  # short-circuiting, which Terraform only does from 1.12. Below that, module
  # validations fail on the null inputs they were written to skip.
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
  # This layer's state holds zone IDs and the content of every DNS record it
  # manages. Treat it, and any saved plan file, as sensitive.
}
