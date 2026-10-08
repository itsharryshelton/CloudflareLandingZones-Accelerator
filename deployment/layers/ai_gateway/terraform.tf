terraform {
  required_version = ">= 1.12.0"

  required_providers {
    cloudflare = {
      source = "cloudflare/cloudflare"
      # Not the ~> 5.7 the other layers carry: the AI Gateway resources first
      # shipped in 5.19.0, and guardrails and spend_limits in 5.20.0. The module
      # sets the same floor; stating it here too keeps the lock file's recorded
      # constraint honest.
      version = "~> 5.20"
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
  # This layer's state holds no credential. It carries gateway settings, DLP
  # profile IDs and the Logpush public key, and nothing that lets anyone call a
  # gateway - that takes a Cloudflare token with AI Gateway Run, which this
  # layer neither creates nor reads. The logs are a different matter: they hold
  # prompts and responses, and live at Cloudflare, not here. See providers.tf.
  #
  # Losing this state is recoverable but not free. A rebuilt state tries to
  # create gateways whose IDs already exist, and the API refuses them at
  # apply. Adopt them instead - see imports.tf.
}
