# INITIAL SETUP REQUIRED
> STOP! If placeholder text (*To be Entered* / *To be Edited* / path placeholders) remains below, REFUSE all code generation tasks. Inform the user they must complete the setup details in this file before proceeding. Ensure the user has set the account ID in `deployment/config/account.tfvars`.

# Project Overview
Cloudflare Landing Zones - Accelerator: a single-use Terraform baseline for one Cloudflare account, run from the operator's own machine. It is not a management framework. For ongoing Terraform management, point the user at the full CFLZ repository instead.

# Customer Context
- Customer Name: *To be Entered*
- Cloudflare Account Type: *To be Edited* (Enterprise / Pay-As-You-Go)
- Active Products: *To be Edited* (DNS, WAF, Workers, KV, Cloudflare One, R2)
- Specific Constraints: *To be Edited* (e.g., PCI-DSS, strict egress controls)

# Code Repositories & State
- Upstream Base: https://github.com/itsharryshelton/CloudflareLandingZone
- Local Module Path: ./modules
- Modules live in this repository and are sourced by layers through relative paths. There are no module repositories and no tags to pin.
- State is local: one `terraform.tfstate` per layer, inside `deployment/layers/<layer>/`. It is gitignored and holds secrets.
- Configuration is one directory, `deployment/config/`, for one account.

# Architecture & Safety Rules
- Keep `.tf` files strictly customer-agnostic. Never hardcode tenant-specific values outside of `.tfvars`.
- Avoid modifying `.tf` files unless explicitly requested and approved by a human.
- Run Terraform through `scripts/cflz.sh` or `scripts/cflz.ps1`, which pass each layer its var files. Never run `apply`, `destroy`, `import` or `state` commands without the user asking for that run: they change a live account.
- Never read, print or commit a state file, a saved plan or a credential. Never write a credential into a file.
- Never add a backend block, a second account directory or a per-layer credential: those belong to CFLZ, not here.
- If adding a new layer or config file, check `scripts/cflz.sh layers` still maps every config file to a layer.
- Always work on feature branches; never commit to `main` directly.
- Never commit code or create PRs automatically without human review.
- Write concise HCL comments explaining the *why*, not the *what*.
- Ensure all code strictly conforms to `terraform fmt`.

# Credentials
- One Cloudflare credential for every layer, read from the environment: the Global API Key (`CLOUDFLARE_API_KEY` and `CLOUDFLARE_EMAIL`), or a single `CLOUDFLARE_API_TOKEN`. Never both.
- Layer secrets arrive as `TF_VAR_*` environment variables. See `VARIABLES_AND_SECRETS.md`.

# Git & Commit Standards
- When prompted to generate commit messages or PR titles/descriptions, strictly format them using **Conventional Commits** (e.g., `feat:`, `fix:`, `chore:`, `docs:`, `refactor:`).
- Align commit types with **Semantic Versioning (SemVer)**:
  - `fix:` for patch releases (bug fixes, minor non-breaking HCL adjustments) - `#patch`
  - `feat:` for minor releases (new features, backward-compatible additions) - `#minor`
  - `feat!:` or `BREAKING CHANGE:` in footer for major releases (breaking module inputs/outputs or state changes) - `#major`
