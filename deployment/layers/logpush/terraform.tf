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
  # THIS LAYER'S STATE HOLDS DESTINATION CREDENTIALS. A destination supplied
  # through logpush_destination_secrets - R2 access keys, a Splunk HEC token, a
  # Datadog API key, an Azure SAS - is recorded in plain text, because Terraform
  # records what it sent, and so is every ownership challenge token. Anyone who
  # can read this state can write into every log destination it names. Treat it,
  # and every saved plan of this layer, as credential material.
}
