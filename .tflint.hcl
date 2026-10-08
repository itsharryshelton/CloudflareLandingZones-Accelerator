# TFLint configuration, shared by every layer and module.
#
# Run it from the repository root with the config passed by absolute path, so
# `--recursive` keeps using it as it descends into each directory rather than
# falling back to defaults:
#
#   TFLINT_CONFIG_FILE="$PWD/.tflint.hcl" tflint --recursive

config {
  # Every module is sourced by a relative path inside this repository, so
  # `local` is all there is to descend into, and it needs no `terraform init`.
  call_module_type = "local"
}

plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

# A layer's variables are its operator interface - the tfvars an engineer writes
# are validated against these, so an undocumented or untyped one is a trap.
rule "terraform_documented_variables" {
  enabled = true
}

rule "terraform_documented_outputs" {
  enabled = true
}

rule "terraform_typed_variables" {
  enabled = true
}

rule "terraform_naming_convention" {
  enabled = true
}

# Both are pinned per layer in terraform.tf. Drifting off a pin is how a state
# file gets written by a provider version nobody chose.
rule "terraform_required_version" {
  enabled = true
}

rule "terraform_required_providers" {
  enabled = true
}
