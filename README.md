# Cloudflare Landing Zones - Accelerator

Deploy a known-good Cloudflare baseline into one account, from your own machine, in an afternoon - Gateway policies, Access applications, device posture, WAF rules, DNS and the rest - then hand the account over and carry on in the dashboard.

The Accelerator is the [Cloudflare Landing Zones (CFLZ)](https://github.com/itsharryshelton/CloudflareLandingZone) modules and layers with the platform around them taken away: no pipeline, no remote state, no token per layer. What is left is the part that speeds up a delivery project.

> [!IMPORTANT]
> **This repository is designed to be used once.** It builds the baseline and then gets out of the way. It is not a way to manage Cloudflare with Terraform: there is no drift detection, no approval gate, no shared state and no separation of duties, and the first dashboard edit after handover makes the Terraform here out of date.
>
> If you want Terraform to keep owning the configuration - GitOps, reviewed plans, least-privilege tokens, more than one account - use the full [Cloudflare Landing Zones](https://github.com/itsharryshelton/CloudflareLandingZone) repository instead. It is built for exactly that.

## Accelerator or CFLZ?

| | Accelerator (this repository) | [CFLZ](https://github.com/itsharryshelton/CloudflareLandingZone) |
|---|---|---|
| Purpose | Stand up a baseline during a project, then stop | Run Cloudflare as code, indefinitely |
| Who runs Terraform | You, on your machine | GitHub Actions, after a reviewed plan |
| Accounts | One | Many, one config tree each |
| Credential | One: the Global API Key (or a single API token) | One scoped token per layer, per account |
| State | Local file in each layer directory | Cloudflare R2, locked, one key per account and layer |
| Modules | In this repository, by relative path | Published repositories, pinned by tag |
| After go-live | The customer works in the dashboard | Every change is a pull request |

The Terraform is the same in both, so a customer who later decides they do want full management has not been taken down a dead end: the same `.tfvars` drop into a CFLZ deployment.

## What it deploys

Each layer is a self-contained Terraform root module with its own state. Run the ones the project needs and ignore the rest - a layer you never run deploys nothing.

```text
Account-wide
├── account_governance   (Account members, user groups and their RBAC policies)
├── zerotrust            (Zero Trust organisation, IdPs, Access groups, policies and applications, service tokens)
├── device_posture       (Device posture checks, MDM and EDR integrations such as Intune and CrowdStrike)
├── tunnels              (Cloudflare Tunnels, public hostnames, private network routes)
├── gateway              (SWG egress filtering: DNS, network, and HTTP)
├── lists                (Account-wide IP, ASN and hostname lists that WAF rules reference)
├── bulk_redirects       (Account-wide URL redirect lists and the rules that apply them)
├── logpush              (Log streams: audit, Gateway and zone logs to a SIEM or R2 - Enterprise)
├── turnstile            (Turnstile widgets: the CAPTCHA replacement embedded in a form)
├── ai_gateway           (AI Gateway: LLM traffic proxy - logging, caching, rate and spend limits, DLP, guardrails, dynamic routes)
└── wan                  (Cloudflare WAN IPsec and GRE tunnels, BGP, static routes)

Per zone
├── zones                (Zone lifecycle, rate plans, TLS posture and settings, bot management)
├── dns                  (DNS records)
├── waf                  (Firewall rules, rate limiting, managed rulesets, bot traffic rules)
├── rules                (Cache, request header transform and origin rules)
├── load_balancing       (Health monitors, origin pools, failover logic)
├── origin_pulls         (Authenticated Origin Pulls: edge-to-origin mTLS, zone-wide and per hostname)
├── workers              (Workers, KV, D1, queues, routes, custom domains, cron triggers)
├── pages                (Pages projects: Jamstack front ends, branch deploys, bindings, custom domains)
└── r2                   (Buckets, CORS, lifecycle and retention rules, custom domains)
```

[deployment/README.md](deployment/README.md) documents every layer: its inputs, its baseline, and the guardrails that fail a plan.

## Before you start

| You need | Why |
|---|---|
| [Terraform](https://developer.hashicorp.com/terraform/install) 1.12 or newer, 64-bit | The modules rely on `\|\|` and `&&` short-circuiting, which arrived in 1.12. The Cloudflare provider publishes no 32-bit Windows build, so check `terraform version` says `windows_amd64`, not `windows_386` - on the 32-bit one, `init` fails with `Incompatible provider version` |
| A Cloudflare credential for the target account | See [Credentials](#credentials) |
| The account ID | Goes in `deployment/config/account.tfvars` |
| bash 4+, `jq`, `curl` and Node.js | Only for the optional [post-apply scripts](#after-an-apply). On Windows, run those from Git Bash or WSL |

## Quick start

**1. Clone the repository** somewhere private. Do not push a filled-in copy to a public repository: the config will carry the customer's account ID, domains and network ranges.

**2. Set the account.** Put the customer's account ID in [deployment/config/account.tfvars](deployment/config/account.tfvars).

**3. Edit the config for the layers you are deploying.** Every file in [deployment/config/](deployment/config/) is a worked example with placeholder values - `example.com`, RFC 5737 addresses, made-up IDs. A layer applies whatever its files say, so replace the examples with the customer's values before you run it. You never need to edit a `.tf` file.

**4. Put the credential in your shell**, for this session only.

```bash
# bash - read -s keeps the key out of your shell history
export CLOUDFLARE_EMAIL="you@example.com"
read -rs CLOUDFLARE_API_KEY && export CLOUDFLARE_API_KEY
```

```powershell
# PowerShell 7.1+ - -MaskInput keeps the key off the screen and out of history
$env:CLOUDFLARE_EMAIL = "you@example.com"
$env:CLOUDFLARE_API_KEY = Read-Host "Global API Key" -MaskInput
```

**5. Plan, read the plan, apply.** The wrapper finds the right var files for the layer and runs `terraform init` the first time.

```bash
scripts/cflz.sh layers            # every layer, and the config files it reads
scripts/cflz.sh plan gateway
scripts/cflz.sh apply gateway     # shows the plan again and asks before changing anything
```

```powershell
.\scripts\cflz.ps1 layers
.\scripts\cflz.ps1 plan gateway
.\scripts\cflz.ps1 apply gateway
```

Anything after the layer name goes straight to Terraform (`scripts/cflz.sh plan dns -out=tfplan`), and any Terraform command works (`scripts/cflz.sh output zerotrust`). If your clone did not keep the scripts executable, run them as `bash scripts/cflz.sh ...`.

**6. Hand over**, then follow [When the project is finished](#when-the-project-is-finished).

### What order to run layers in

Most layers are independent. Three dependencies are real:

- **A layer marked `NEEDS ZONES` in `cflz layers`** looks its zones up by name in the account, from the inventory in `zones.tfvars`. The zone has to exist first. For a new zone, apply `zones` before `dns`, `waf`, `rules` and the rest. For a zone the customer already has, list it in `zones.tfvars` and do **not** run the `zones` layer - that layer creates zones, and would try to create one that is already there.
- **`lists` before `waf`**, when a WAF rule names a list.
- **`device_posture` before `zerotrust` or `gateway`**, when a policy requires a posture check: the policy needs the rule's ID, which exists only after the apply.

`zerotrust` also expects the hostnames its Access applications protect to be on zones in the account, and the Zero Trust organisation (the team name) to have been created in the dashboard already.

A typical Zero Trust baseline is `device_posture`, then `gateway`, then `zerotrust`, with `tunnels` if the project publishes private applications.

### After an apply

Three things Terraform cannot do are done by scripts, run by hand once the apply has finished. They read the same credential from your shell.

| Script | When | What it does |
|---|---|---|
| [`scripts/resource-tags.sh`](scripts/resource-tags.sh) | After `zones`, `zerotrust`, `r2` or `workers`, if you use `tags.tfvars` | Writes Cloudflare resource tags - the provider has no tagging resource yet |
| [`scripts/d1-migrations.sh`](scripts/d1-migrations.sh) | After `workers`, if it declares D1 databases | Applies the SQL migrations under `layers/workers/migrations/` |
| [`scripts/kv-bulk-load.sh`](scripts/kv-bulk-load.sh) | After `workers`, if it has bulk KV datasets | Loads `layers/workers/data/bulk/*.json` into their namespaces |

A fourth, [`scripts/cf-api-throttle.py`](scripts/cf-api-throttle.py), is a local rate limiter for the rare run that needs one - see [API rate limiting](deployment/README.md#api-rate-limiting).

## Credentials

The Accelerator uses **one credential for every layer**, read from environment variables. Nothing goes in a `.tf` or `.tfvars` file.

| Option | Set | Notes |
|---|---|---|
| Global API Key (default) | `CLOUDFLARE_API_KEY` and `CLOUDFLARE_EMAIL` | **My Profile → API Tokens → Global API Key** |
| A single API token | `CLOUDFLARE_API_TOKEN` | Needs the permissions of every layer you run - each layer's `providers.tf` lists its own |

Set one, not both. `cflz` refuses to run with both, or with neither.

> [!WARNING]
> **A Global API Key is everything its user is.** It reaches every account that user is a member of - which, for a consultant, can mean every customer - with every permission they hold, including billing and membership, and it cannot be scoped or given an expiry. Treat it accordingly:
>
> - Prefer a key belonging to a user in the customer's own account, created for the project, over your own.
> - Keep it in the shell session that needs it. Not in a file, not in a profile script, not in a ticket.
> - If it may have been exposed, **roll it** from the same dashboard page. That invalidates the old key at once.
> - If the customer's security policy rules a Global API Key out, use an API token: the Terraform is identical either way.

A few layers also take a secret of their own - an identity provider's client secret, a Logpush destination, a tunnel pre-shared key - as a `TF_VAR_*` environment variable. [VARIABLES_AND_SECRETS.md](VARIABLES_AND_SECRETS.md) lists them all.

## State

Terraform records what it created in a state file. Here that file is local: `terraform.tfstate`, inside each layer's directory under [deployment/layers/](deployment/layers/). `.gitignore` keeps it out of version control.

Two things about it matter.

**It is sensitive.** State holds everything Terraform sent and received, in plain text: resolved IDs, DNS records, rule expressions, and for some layers live secrets - Access service token secrets and identity provider secrets in `zerotrust`, Turnstile secret keys, Logpush destination credentials, WAN pre-shared keys. Each layer's `terraform.tf` says what its state holds. A saved plan file is exactly as sensitive.

**It is the only link between this repository and the account.** While you still have it, you can change or remove what you deployed by editing the config and applying again. Without it, Terraform knows nothing of what exists, and a fresh apply would try to create everything a second time.

## When the project is finished

The baseline is deployed and the customer is taking over in the dashboard. Close the Terraform down deliberately:

1. **Collect what has to be handed over** while the state is still there: `scripts/cflz.sh output <layer>` prints each layer's outputs - nameservers, sitekeys, tunnel IDs, service token client IDs.
2. **Stop applying.** From the first dashboard edit onwards, the config here no longer describes the account, and another `apply` would put it back the way the `.tfvars` say - undoing the customer's changes without asking them.
3. **Decide what happens to the state files.** Keep them, encrypted and with the project's other handover material, for as long as you might be asked to adjust or roll back the baseline. Delete them once that window has closed. Deleting state removes nothing from Cloudflare.
4. **Delete saved plan files** (`tfplan`, `*.tfplan`) and any file you wrote a secret to.
5. **Clear the credential**: close the shell, or unset `CLOUDFLARE_API_KEY`, `CLOUDFLARE_EMAIL` and every `TF_VAR_*`. Roll the Global API Key if it was created for the project, and remove the project user if there was one.
6. **Tell the customer what was built and how.** Nothing in the account marks a resource as Terraform-managed, because after handover none is: everything here is edited in the dashboard like any other resource. Resources tagged by `scripts/resource-tags.sh` carry `layer = <layer>`, which records where they came from and nothing more.

If, at this point, the answer to "who changes this next?" is "we would like it to stay in code", that is the moment to move to [CFLZ](https://github.com/itsharryshelton/CloudflareLandingZone) rather than to keep running the Accelerator.

## Repository structure

```text
├── modules/                   # Agnostic building blocks (flat arguments, real IDs)
├── deployment/
│   ├── layers/                # One Terraform root module per product, each with its own local state
│   └── config/                # The deployment's configuration - the only directory you edit
└── scripts/                   # cflz, the wrapper that runs a layer, and the post-apply helpers
```

- `modules/`: reusable modules that know nothing about accounts, keys or layers. Layers source them by relative path, so a clone is self-contained.
- `deployment/layers/`: the layers. Each composes modules, resolves logical keys to Cloudflare IDs and enforces guardrails at plan time.
- `deployment/config/`: `.tfvars` only. One file per layer, plus `account.tfvars`, `zones.tfvars` and `tags.tfvars`, which several layers read.
- `scripts/`: [`cflz.sh`](scripts/cflz.sh) and [`cflz.ps1`](scripts/cflz.ps1) do the same job in bash and PowerShell.

## Documentation

| Document | For |
|---|---|
| [deployment/README.md](deployment/README.md) | How layers and config fit together, and each layer's inputs, baseline and guardrails |
| [VARIABLES_AND_SECRETS.md](VARIABLES_AND_SECRETS.md) | Every environment variable a run reads: the credential, and each layer's secrets |
| [modules/README.md](modules/README.md) | What the modules are, and the rules for calling and writing one |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Changing the Terraform rather than the configuration |
| [deployment/layers/workers/migrations/README.md](deployment/layers/workers/migrations/README.md) | D1 schema migrations: naming, and how they are applied |
| [deployment/layers/workers/data/kv/README.md](deployment/layers/workers/data/kv/README.md) | KV data: what Terraform owns, and bulk datasets loaded after apply |
| [deployment/layers/origin_pulls/ca/README.md](deployment/layers/origin_pulls/ca/README.md) | The vendored Cloudflare Origin Pull CA, and refreshing it |
| [CFLZ Wiki](https://github.com/itsharryshelton/CloudflareLandingZone/wiki) | Task guides written for CFLZ: adding a zone, a record, a WAF rule. The `.tfvars` syntax is the same here; the paths are `deployment/config/` rather than `deployment/accounts/<account>/`, and there is no pipeline |

> ## A Note on Feature Coverage & Maintenance
> This project gives you a solid starting point for a Cloudflare baseline, but it doesn't cover every single Cloudflare feature out of the box. You may find that a specific deployment needs a `.tf` file tweaking to add a variable or support another resource.
>
> While core capabilities are tested, I can't test every edge case or keep up with every provider update instantly. If you hit a gap, find a bug, or want to add a feature, please check out [`CONTRIBUTING.md`](CONTRIBUTING.md) and submit a Pull Request!
> The Terraform here follows [CFLZ](https://github.com/itsharryshelton/CloudflareLandingZone), which is where the modules and layers are developed. I do not have a timeline for features, I add when I have the time or think needs adding next; any requests please submit.

## Licence

Distributed under the Apache License 2.0 - See [LICENSE](LICENSE) and [NOTICE](NOTICE).

### Open-Source & BSL Considerations
- Apache-2.0 License: You are free to copy, modify, and run this code for commercial clients privately without triggering file-level copyleft obligations (unlike MPL-2.0).
- Terraform BSL / OpenTofu: Terraform (v1.6+) is licensed under the Business Source License (BSL 1.1) by IBM. The Accelerator relies on standard HCL features, but is developed and tested only against Terraform. OpenTofu (MPL-2.0) is untested. Before relying on it, check that your OpenTofu version satisfies `required_version = ">= 1.12.0"`, which OpenTofu compares with its own version number, and that it short-circuits `||` and `&&`, which the guardrails rely on.
