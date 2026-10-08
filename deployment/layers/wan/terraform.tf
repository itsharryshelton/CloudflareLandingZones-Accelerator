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
  # THIS LAYER'S STATE HOLDS LIVE CREDENTIALS. Every IPsec pre-shared key supplied
  # through wan_ipsec_tunnel_psks is in it in plain text, because Cloudflare stores
  # the key and Terraform records what it sent. Marking the variable sensitive
  # keeps the value out of console output; it does not encrypt state.
  #
  # Treat a leak of this state as a network compromise rather than a configuration
  # disclosure. A PSK plus the two endpoint addresses - both also in here - is
  # everything needed to stand up the customer end of a tunnel into the estate.
  # Rotate every PSK it contains, at both ends. Keep the state file off shared
  # drives, and remember that a saved plan file is exactly as sensitive.
}
