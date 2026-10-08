# `deployment` - layers and config

Everything you run and everything you edit lives here. The modules under [../modules/](../modules/) stay agnostic: flat arguments, real IDs, one resource group each, no knowledge of accounts, keys or profiles. A deployment is configured entirely in the `.tfvars` files under `config/`. You should not need to edit a `.tf` file, and a change to one belongs in a pull request to this repository rather than in one customer's copy - see [CONTRIBUTING.md](../CONTRIBUTING.md).

> [!IMPORTANT]
> The Accelerator deploys a baseline once, from your own machine, into one account. It is not a way to keep managing Cloudflare with Terraform - see [When the project is finished](../README.md#when-the-project-is-finished). For that, use [Cloudflare Landing Zones](https://github.com/itsharryshelton/CloudflareLandingZone), which adds the pipeline, the remote state and the per-layer tokens this repository deliberately leaves out.

## Directory Structure

```text
deployment/
├── layers/                            # code, one root module per product
│   ├── account_governance/            # own state: members, user groups, RBAC
│   ├── ai_gateway/                    # own state: AI gateways, caching, rate and spend limits, DLP, guardrails, dynamic routes
│   ├── bulk_redirects/                # own state: URL redirect lists and execution ruleset
│   ├── device_posture/                # own state: device posture checks, MDM and EDR integrations
│   ├── dns/                           # own state: per-zone DNS records
│   ├── gateway/                       # own state: SWG egress filtering, TLS inspection, root CA
│   ├── lists/                         # own state: account-level IP, ASN and hostname lists
│   ├── load_balancing/                # own state: monitors, pools, zone load balancers
│   ├── logpush/                       # own state: Logpush jobs, account and zone log streams
│   ├── origin_pulls/                  # own state: Authenticated Origin Pulls, client certificates, per-hostname edge-to-origin mTLS
│   ├── pages/                         # own state: Pages projects, branch deployment rules, bindings, custom domains
│   ├── r2/                            # own state: buckets, CORS, lifecycle, retention, domains
│   ├── rules/                         # own state: cache rules, transform rules, origin rules
│   ├── tunnels/                       # own state: Cloudflare Tunnels, public hostnames, private network routes
│   ├── turnstile/                     # own state: Turnstile widgets, the sitekey and secret a form is protected by
│   ├── waf/                           # own state: firewall custom rules, rate limiting, managed rulesets, bot traffic rules
│   ├── wan/                           # own state: Cloudflare WAN IPsec and GRE tunnels, BGP, static routes
│   ├── workers/                       # own state: Worker scripts, KV namespaces, D1 databases, queues, routes, crons
│   ├── zerotrust/                     # own state: Zero Trust organisation, IdPs, Access groups, policies, applications, service tokens
│   └── zones/                         # own state: zones, TLS posture, settings, bot management
└── config/                            # the deployment's configuration, for its one account
    ├── account.tfvars                 # account id       -> every layer
    ├── account_governance.tfvars      # dashboard access -> account_governance
    ├── ai_gateway.tfvars              # LLM proxies      -> ai_gateway
    ├── bulk_redirects.tfvars          # URL redirects    -> bulk_redirects
    ├── device_posture.tfvars          # posture checks   -> device_posture
    ├── dns.tfvars                     # DNS records      -> dns
    ├── gateway.tfvars                 # egress filtering -> gateway
    ├── lists.tfvars                   # shared lists     -> lists
    ├── load_balancing.tfvars          # load balancers   -> load_balancing
    ├── logpush.tfvars                 # log streams      -> logpush
    ├── origin_pulls.tfvars            # origin mTLS      -> origin_pulls
    ├── pages.tfvars                   # Jamstack sites   -> pages
    ├── r2.tfvars                      # object storage   -> r2
    ├── rules.tfvars                   # traffic rules    -> rules
    ├── tags.tfvars                    # resource tags    -> zones, zerotrust, r2, workers
    ├── tunnels.tfvars                 # Cloudflare Tunnel -> tunnels
    ├── turnstile.tfvars               # Turnstile widgets -> turnstile
    ├── waf.tfvars                     # firewall rules   -> waf
    ├── wan.tfvars                     # site tunnels     -> wan
    ├── workers.tfvars                 # edge compute, KV, D1, queues -> workers
    ├── zerotrust.tfvars               # Access posture   -> zerotrust
    ├── zone_config.tfvars             # zone settings    -> zones
    └── zones.tfvars                   # zone inventory   -> zones, bulk_redirects, dns, waf, lb, logpush, origin_pulls, pages, r2, rules, tunnels, workers
```

Each layer is a root module with its own state file, holding `terraform.tf`, `providers.tf`, `variables.tf`, `locals*.tf`, one `<subject>.tf`, `preflight.tf`, `outputs.tf` and its own `defaults.auto.tfvars` where baselines apply. Where they apply, a layer also carries `zone_lookup.tf` (or another `*_lookup.tf`) for the names it resolves through the API, `tags.tf` for [resource tags](#resource-tags), and `imports.tf` for adopting what already exists at Cloudflare.

Every `module` block points at [../modules/](../modules/) by relative path, so a clone of this repository is everything a run needs.

Every file in `config/` ships as a worked example with placeholder values. A layer applies whatever its files say, so replace the examples before running it. A layer you never run deploys nothing, whatever its config file holds.

## Running a layer

[`scripts/cflz.sh`](../scripts/cflz.sh) and [`scripts/cflz.ps1`](../scripts/cflz.ps1) run Terraform for one layer. They do the same thing in bash and PowerShell.

```bash
scripts/cflz.sh layers                  # every layer, and the config files it reads
scripts/cflz.sh plan gateway
scripts/cflz.sh apply gateway           # plans again, shows it, and asks before changing anything
scripts/cflz.sh output zerotrust
```

The first argument is any Terraform subcommand, the second is a layer, and everything after that goes to Terraform untouched. The wrapper adds three things:

1. **`terraform init`**, the first time a layer is used. State is local, so there is nothing to configure.
2. **The layer's `-var-file` arguments**, for `plan`, `apply`, `destroy`, `import`, `refresh` and `console`. A config file belongs to a layer when the layer declares every variable the file assigns, so the set is derived, not listed - see the [mapping](#layer-variable-file-mapping) below.
3. **A credential check**, before any command that calls Cloudflare: exactly one of the Global API Key (`CLOUDFLARE_API_KEY` and `CLOUDFLARE_EMAIL`) or `CLOUDFLARE_API_TOKEN` must be in the environment. See [VARIABLES_AND_SECRETS.md](../VARIABLES_AND_SECRETS.md).

To apply exactly the plan you read, save it and apply the file:

```bash
scripts/cflz.sh plan dns -out=tfplan
scripts/cflz.sh apply dns tfplan
```

A saved plan holds everything the state does, secrets included. Delete it once it has been applied.

`scripts/cflz.sh destroy <layer>` removes everything in that layer's state. It is the rollback for a baseline that should not have gone in, and it is as destructive as it reads: destroying `zones` deletes the zones and every DNS record in them.

Nothing stops you running Terraform by hand; the wrapper only saves typing:

```bash
cd deployment/layers/gateway
terraform init
terraform plan -var-file=../../config/account.tfvars -var-file=../../config/gateway.tfvars
```

### Layer Variable File Mapping

The config files and secret environment variables each layer reads. Only `account.tfvars`, and `zones.tfvars` for a layer that declares `zones`, are required: every other variable has a default, in the layer or its `defaults.auto.tfvars`, so a file that is missing, or that assigns nothing, is simply not passed.

| Layer                | `-var-file` Arguments                                                 | Secret Environment Variables                                                        |
| ----------------------| -----------------------------------------------------------------------| -------------------------------------------------------------------------------------|
| `account_governance` | `account.tfvars`, `account_governance.tfvars`                         | None                                                                                |
| `ai_gateway`         | `account.tfvars`, `ai_gateway.tfvars`                                 | None (BYOK provider keys live in Secrets Store and are added outside Terraform)     |
| `bulk_redirects`     | `account.tfvars`, `zones.tfvars`, `bulk_redirects.tfvars`             | None                                                                                |
| `device_posture`     | `account.tfvars`, `device_posture.tfvars`                             | `TF_VAR_device_posture_integration_secrets` (only where an integration is declared) |
| `dns`                | `account.tfvars`, `zones.tfvars`, `dns.tfvars`                        | None                                                                                |
| `gateway`            | `account.tfvars`, `gateway.tfvars`                                    | None                                                                                |
| `lists`              | `account.tfvars`, `lists.tfvars`                                      | None                                                                                |
| `load_balancing`     | `account.tfvars`, `zones.tfvars`, `load_balancing.tfvars`             | None                                                                                |
| `logpush`            | `account.tfvars`, `zones.tfvars`, `logpush.tfvars`                    | `TF_VAR_logpush_destination_secrets`, `TF_VAR_logpush_ownership_challenges`         |
| `origin_pulls`       | `account.tfvars`, `zones.tfvars`, `origin_pulls.tfvars`               | `TF_VAR_origin_pull_certificates` (only where a zone uploads a certificate of its own) |
| `pages`              | `account.tfvars`, `zones.tfvars`, `pages.tfvars`                      | `TF_VAR_pages_project_secrets` (only where a project lists `secret_names`)          |
| `r2`                 | `account.tfvars`, `zones.tfvars`, `r2.tfvars`, `tags.tfvars`          | None                                                                                |
| `rules`              | `account.tfvars`, `zones.tfvars`, `rules.tfvars`                      | None                                                                                |
| `tunnels`            | `account.tfvars`, `zones.tfvars`, `tunnels.tfvars`                    | None (no tunnel secret is sent and no connector token is read)                      |
| `turnstile`          | `account.tfvars`, `turnstile.tfvars`                                  | None (Cloudflare issues the widget secret, and it lands in this layer's state)      |
| `waf`                | `account.tfvars`, `zones.tfvars`, `waf.tfvars`                        | None                                                                                |
| `wan`                | `account.tfvars`, `wan.tfvars`                                        | `TF_VAR_wan_ipsec_tunnel_psks`, `TF_VAR_wan_bgp_md5_keys`                           |
| `workers`            | `account.tfvars`, `zones.tfvars`, `workers.tfvars`, `tags.tfvars`     | None (Worker secrets use Secrets Store)                                             |
| `zerotrust`          | `account.tfvars`, `zerotrust.tfvars`, `tags.tfvars`                   | `TF_VAR_identity_provider_secrets` (only where an OAuth-type provider is declared)  |
| `zones`              | `account.tfvars`, `zones.tfvars`, `zone_config.tfvars`, `tags.tfvars` | None                                                                                |

Like `zones.tfvars`, `tags.tfvars` reaches several layers: it assigns `resource_tags`, which `zones`, `zerotrust`, `r2` and `workers` each declare and each read their own section of. See [Resource tags](#resource-tags).

## Apply Order

Layers are named after the Cloudflare product they manage, with no numeric prefixes, and most can be applied in any order or not at all. The order that does matter comes from what one layer has to find already in the account:

```
Apply first, where used
├── zones                              (creates the zones every zone-reading layer looks up by name)
├── lists                              (named lists exist before a waf rule references them)
└── device_posture                     (posture rule IDs exist before a zerotrust or gateway policy names them)

Independent
├── account_governance                 (members, user groups and RBAC)
├── ai_gateway                         (reached by URL, attached to no zone)
├── bulk_redirects                     (account-scoped redirect lists and rules)
├── gateway                            (account-scoped SWG policies, TLS decryption settings, root CA)
├── turnstile                          (account-scoped widgets, attached to no zone)
└── wan                                (account-scoped WAN tunnels and static routes)

After the zones they name exist
├── dns                                (resolves zone IDs via data source; creates DNS records)
├── load_balancing                     (resolves zone IDs; provisions origin pools and health monitors)
├── logpush                            (resolves zone IDs for zone-scoped jobs; pushes logs to a SIEM or storage)
├── origin_pulls                       (resolves zone IDs; enables Authenticated Origin Pulls and uploads client certificates)
├── pages                              (resolves zone IDs; writes the proxied CNAME behind each custom domain)
├── r2                                 (provisions buckets; binds custom domains to existing zones)
├── rules                              (resolves zone IDs; manages cache, transform, and origin rules)
├── tunnels                            (resolves zone IDs; publishes tunnel hostnames as proxied CNAMEs)
├── waf                                (resolves zone IDs; consumes account lists)
├── workers                            (resolves zone IDs; binds script routes and custom domains; provisions KV, D1 and queues)
└── zerotrust                          (Access applications are addressed by hostname, on a zone in the account)
```

`scripts/cflz.sh layers` marks the zone-reading layers `NEEDS ZONES`. It derives that from the source - a `data "cloudflare_zone"` block - so `zerotrust`, which needs its hostnames' zones without ever reading one, is not marked.

- **The zone only has to exist in the account.** A zone-reading layer resolves each zone by domain name and account ID, from the inventory in `zones.tfvars`. Whether the `zones` layer created it is irrelevant. For a customer who already has their zones, list them in `zones.tfvars` and leave the `zones` layer alone: it creates zones, and its plan for one that already exists is a create the API refuses.
- **A new zone and its records cannot be planned together.** Until `zones` has been applied, the `dns`, `waf` and other zone-reading plans fail on the lookup. Apply `zones`, then plan the rest.
- **`origin_pulls` belongs behind `zones` for a second reason:** the zone's SSL mode has to be `full` or `strict` before authenticating to the origin means anything.
- **`account_governance` changes who can do what in the account** - potentially including the user whose Global API Key the run is using. Read that plan with the credential in mind.

## Why split this way

**Product isolation over combined states.** A WAF, DNS, or load balancer apply cannot propose destroying a zone, because zones are not in its state. Zone deletion is the most destructive failure mode in Cloudflare, as it immediately cascades to eliminate all DNS records. It also means a project deploys only what it needs: a Zero Trust baseline is three layers, and the other seventeen never run.

**Zone as a `for_each` key, not a directory.** Maintaining a directory per zone would mean onboarding a zone requires adding duplicated `.tf` orchestrator files. Adding a zone here needs only a `zones.tfvars` entry; `zone_config.tfvars` overrides its baseline, and `dns.tfvars` holds its records.

**DNS separated from Zone lifecycle.** Zone lifecycle management (creation, rate plan subscription, TLS minimum versions, and security level) is separated from DNS record management, so a record change cannot trigger zone-level recreation or setting drift.

One thing the split does not give you here is separation of credentials. Every layer runs on the same Global API Key or token, so nothing but the state boundary stands between a layer and the rest of the account. Where that separation matters, it is what [CFLZ](https://github.com/itsharryshelton/CloudflareLandingZone) is for.

## Layers do not read each other's state

The `dns`, `waf`, `load_balancing`, `logpush`, `origin_pulls`, `pages`, `r2`, `rules`, `tunnels`, and `workers` layers resolve a zone key to a zone ID using `data "cloudflare_zone"` filtered by name and account ID, rather than reading `terraform_remote_state`. State files remain completely decoupled: any layer can be applied, re-initialised, or thrown away without affecting the others.

This design requires the Cloudflare API to be accessible at plan time for those layers, and plans will fail if the zone does not yet exist.

`account_governance` queries the API to resolve role, permission group, and resource group names to IDs. `zerotrust` queries the account's existing Zero Trust organisation, to adopt its team name when `zero_trust_team_name` is unset and to refuse an unintended rename when it is set. `gateway` dynamically resolves Cloudflare's content categories, security categories, and application catalogues so that configuration files reference human-readable names like `"Microsoft 365"` rather than arbitrary IDs like `606`.

`wan`, `bulk_redirects`, `lists`, `turnstile`, `ai_gateway`, and `device_posture` are completely account-scoped and contain no zone data sources.

### Reading a layer's outputs

Several hand-overs in this document are a layer output: `name_servers`, `device_posture_rule_ids`, `origin_trust_bundles`, `turnstile_sitekeys`, `pages_access_applications`, `ai_gateway_endpoints`. `terraform apply` prints every root output under `Outputs:` when it finishes, sensitive ones as `<sensitive>`. To read them again later, while the layer's state still exists:

```bash
scripts/cflz.sh output <layer>                    # every output
scripts/cflz.sh output <layer> -json <name>       # one output, as JSON, sensitive values included
```

Collect every output a hand-over needs before the state files are archived or deleted - see [When the project is finished](../README.md#when-the-project-is-finished).

## Config precedence

Lowest precedence first:

1. `layers/<layer>/defaults.auto.tfvars`: the baseline, auto-loaded from the layer's working directory. Customer-agnostic.
2. `local.auto.tfvars` in a layer directory: a local experiment. Auto-loaded after `defaults.auto.tfvars`, because Terraform reads `*.auto.tfvars` files in lexical order, so it overrides the baseline. Strictly Gitignored.
3. `config/*.tfvars`: passed explicitly with `-var-file` flags, which Terraform reads after every `*.auto.tfvars`, so they override both. That includes the guardrails: an `allow_*` variable set in a config file relaxes it for this deployment, so treat such a line as a policy exception and write down why it is there.

Terraform `-var-file` arguments do not merge maps across files: if two files define the same variable, the last file wins wholesale. Configuration is therefore partitioned by variable: `zones.tfvars` owns the zone inventory, `zone_config.tfvars` owns zone settings, `dns.tfvars` owns DNS records, and `waf.tfvars` owns firewall rules. No two files define the same top-level variable, and `cflz` refuses to run a layer against a file that mixes its variables with another layer's.

## What is committed

Layer defaults are customer-agnostic. Once filled in, the config files contain an account ID, domain names, IP address ranges, and routing topologies. This is operational configuration, not secret material, but it is a customer's: commit it only to a private repository.

The following must never be written to a file in this repository. They are environment variables, set in the shell that runs `cflz` - see [VARIABLES_AND_SECRETS.md](../VARIABLES_AND_SECRETS.md):

```bash
export CLOUDFLARE_EMAIL="<the user the Global API Key belongs to>"
export CLOUDFLARE_API_KEY="<Global API Key>"
export TF_VAR_identity_provider_secrets='{"entra_id":"<oauth_client_secret>"}'
export TF_VAR_wan_ipsec_tunnel_psks='{"london_primary":"<pre_shared_key>"}'
export TF_VAR_wan_bgp_md5_keys='{"<peering tunnel key>":"<md5_key>"}'
export TF_VAR_logpush_destination_secrets='{"audit_archive":"r2://<bucket>/audit/{DATE}?account-id=<id>&access-key-id=<key_id>&secret-access-key=<secret>"}'
export TF_VAR_logpush_ownership_challenges='{"primary_http_requests":"<challenge_token>"}'
export TF_VAR_device_posture_integration_secrets='{"intune":{"client_secret":"<entra_app_client_secret>"}}'
export TF_VAR_origin_pull_certificates='{"api_origin":{"certificate":"<client_certificate_pem>","private_key":"<private_key_pem>"}}'
export TF_VAR_pages_project_secrets='{"admin_portal":{"production":{"SESSION_SECRET":"<value>"}}}'
```

Written like that they also land in your shell history; [Setting a secret safely](../VARIABLES_AND_SECRETS.md#setting-a-secret-safely) shows how to avoid it.

`.gitignore` enforces default-deny rules for `*.tfvars`, with explicit whitelisting for `layers/*/defaults.auto.tfvars` and `config/*.tfvars`. It explicitly re-denies `**/terraform.tfvars`, `**/local.auto.tfvars`, and `**/*.local.tfvars`, and it excludes every state file and saved plan.

## State

State is local. Each layer declares no backend, so `terraform init` uses Terraform's local backend and the layer's state is `terraform.tfstate` in its own directory: `deployment/layers/zones/terraform.tfstate`, `deployment/layers/gateway/terraform.tfstate`, and so on. One file per layer, none shared, none remote.

That is the right shape for a deployment one person runs once, and the wrong one for anything longer-lived: nobody else can see the state, nothing locks it against a second machine, and nothing backs it up. Three consequences worth knowing:

- **It holds secrets in plain text**, as every Terraform state does. Each layer's `terraform.tf` says what its own state carries. `.gitignore` excludes it; your backups, your sync client and your laptop's disk encryption are yours to check.
- **Lose it and Terraform forgets the layer.** Nothing at Cloudflare changes, but a later apply plans to create everything again, and for most resources the API refuses the duplicate. The layers with an `imports.tf` describe how to adopt what exists.
- **Keeping it is what makes a change or a rollback possible.** While the file exists, editing the config and applying again changes the baseline in place, and `destroy` removes it.

What to do with the state files at the end of a project is in the root README: [When the project is finished](../README.md#when-the-project-is-finished).

Every layer enforces `required_version = ">= 1.12.0"`, because the modules rely on `||` and `&&` short-circuiting.

## API rate limiting

Cloudflare allows **1200 API requests per five minutes per credential**. A baseline of policies and applications is nowhere near that. A layer with hundreds of resources is: the `zones` layer holds one `cloudflare_zone`, one `cloudflare_zone_rules` and a handful of `cloudflare_zone_setting` resources per zone, a large `dns.tfvars` is one request per record, and every one of them is a GET again on every refresh.

The Cloudflare provider used to pace itself: `rps`, `retries`, `min_backoff` and `max_backoff` were provider arguments in 4.x. The 5.x rewrite dropped all four and never replaced them, so a 5.x provider has **no rate limiting and no 429 retry at all** ([cloudflare/terraform-provider-cloudflare#5505](https://github.com/cloudflare/terraform-provider-cloudflare/issues/5505)). Without something in front of it, a large layer fails partway through with

```
429 {"code":971,"message":"Please wait and consider throttling your request speed"}
```

reported as `failed to make http request` against whichever resource was in flight.

For those runs, [`scripts/cf-api-throttle.py`](../scripts/cf-api-throttle.py) is a loopback HTTP listener that paces every request through a shared token bucket and retries any 429 that still gets through, honouring the API's own `Retry-After`. Terraform sees a slow API rather than a rate-limited one. It needs Python 3 and nothing else. Start it in one terminal and leave it running (`python` rather than `python3` on most Windows installs):

```bash
python3 scripts/cf-api-throttle.py --rps 3.5 --port 8787
```

and point the provider at it in the terminal that runs `cflz`:

```bash
export CLOUDFLARE_BASE_URL="http://127.0.0.1:8787/client/v4"
scripts/cflz.sh apply dns -parallelism=4
```

```powershell
$env:CLOUDFLARE_BASE_URL = "http://127.0.0.1:8787/client/v4"
.\scripts\cflz.ps1 apply dns -parallelism=4
```

| Setting | Default | What it does |
|---|---|---|
| `--rps` | `3.5` | Sustained requests per second. 1200/5min is 4.0/s; 3.5 leaves headroom for anything else using the same credential - including you, in the dashboard. |
| `-parallelism` (Terraform's) | `10` | Secondary: it caps concurrent resources, not request rate. `4` means a run whose limiter has died degrades gently instead of burning the budget in a minute. |

The consequence is that such a run is **slow by design**. The rate limit sets a floor: a refresh of *n* resources cannot finish faster than `n / rps` seconds. Raising `--rps` above 4.0 does not make it faster, it makes it fail. Stop the limiter with Ctrl+C when the run is done and it prints what it absorbed; a non-zero `429s_absorbed` means `--rps` is too high for that credential. Unset `CLOUDFLARE_BASE_URL` afterwards, or the next run fails to connect.

Every proxied request carries the Cloudflare credential, so the limiter handles a live secret. It binds `127.0.0.1` only, logs no headers or bodies, and writes nothing to disk.

The post-apply scripts pace themselves: `resource-tags.sh` with a fixed interval between calls, and the two wrangler scripts in a handful of bulk calls. They draw on the same 1200, so run them after an apply has finished rather than alongside one.

## Resource tags

Zones, Access applications, R2 buckets, KV namespaces, D1 databases, queues and Workers can carry [Cloudflare resource tags](https://developers.cloudflare.com/resource-tagging/) - `environment`, `team`, and anything else the customer wants to filter or report by. The Cloudflare provider has no tagging resource yet (none as of 5.24.0) and the Tagging API is in public beta, so tags are written by [`scripts/resource-tags.sh`](../scripts/resource-tags.sh) rather than by Terraform. Terraform still decides what they are:

1. **`config/tags.tfvars`** assigns one variable, `resource_tags`: account-wide defaults, the values a key may take, and per-type defaults and per-resource tags keyed by the same logical keys as the other tfvars. Its header carries the precedence rules.
2. **Each tagging layer** - `zones`, `zerotrust`, `r2`, `workers` - declares that variable, validates the shared settings and its own section at plan time (unknown resource keys, malformed tag keys, values outside `allowed_values`), and outputs the complete tag set of every resource it owns, with its ID, as `resource_tags`. See `tags.tf` in each. Every resource also carries `layer = <layer>`, which tfvars cannot override: it records which layer deployed the resource, and makes no claim that Terraform still manages it.
3. **The script**, run by hand after an apply, reads that output from each tagging layer's state and makes Cloudflare match it. It reads each resource's tags and writes only the ones that differ, so a run with nothing to change writes nothing.

```bash
DRY_RUN=1 scripts/resource-tags.sh      # report what would change
scripts/resource-tags.sh                # write it
```

It is a bash script and needs bash 4 or newer, `curl`, `jq` and `terraform`; on Windows run it from Git Bash or WSL. It uses the same credential as the Terraform run. Tagging is optional: a deployment that never runs the script has no tags and loses nothing else.

- **Cloudflare replaces a resource's whole tag set on every write.** A tag added in the dashboard to a resource in the manifest is removed the next time the script runs. Resources outside the manifests - Workers deployed with wrangler, say - are never touched.
- **DNS records are not tagged.** An account can hold thousands, and the beta caps an account at 10,000 tags.
- **A layer that has not been applied is skipped**, because it has no output to read. Run the script again after it has.
- **To tag another layer's resources**, declare `resource_tags` there and add a `tags.tf` that outputs the same shape. The script finds tagging layers by that file, so it needs no edit.

## Notes

**A plan that removes a zone setting shows destroys, and they are safe.** `cloudflare_zone_setting` has no delete operation - the provider's `Delete` is an empty function - so a destroy drops the resource from Terraform state and leaves the value exactly as it is at Cloudflare. Dropping one setting from the baseline therefore plans one destroy per zone. Read the resource addresses: `module.zones[...].cloudflare_zone_setting.this["..."]` is this case, `module.zones[...].cloudflare_zone.this` is the dangerous one - a zone, and every DNS record in it.

**A config file that assigns nothing is legal.** `load_balancing.tfvars`, for example, can be left entirely commented out as a template. `cflz` skips such a file - passing it to Terraform buys nothing. A file that assigns a variable no layer declares is passed to no layer, and shows against none in `cflz layers`: that is the sign of a typo in a variable name.

**An interrupted run can leave the state locked.** Terraform's local backend takes a lock for the length of a run. Killing the process - closing the terminal mid-apply, say - can leave it behind, and the next run of that layer stops with `Error acquiring the state lock` and a lock ID. Check nothing is still running, then release it with `scripts/cflz.sh force-unlock <layer> <ID>`. If it was an **apply** that died, read the next plan carefully before approving it: the lock says nothing about how far the interrupted apply got; the plan does.

**`Module not installed` or `Module source has changed` means a stale `.terraform` directory.** `cflz` runs `terraform init` only when a layer has no `.terraform` directory at all. One left over from an earlier checkout, or from before a module was added, needs refreshing by hand: `scripts/cflz.sh init <layer>`. Deleting the directory does the same and costs only a provider download.

**Lint rules live in [`.tflint.hcl`](../.tflint.hcl) at the repository root.** Pass it to `tflint` by absolute path so `--recursive` keeps using it as it descends into each layer instead of silently linting with defaults.

## Referring to other resources

Resources reference each other by logical key, never by physical Cloudflare ID. A WAF policy specifies `zone_key = "primary"`, which the layer resolves to a zone ID. Logical keys represent permanent identity: renaming a key causes Terraform to destroy and recreate the underlying resource.

`preflight.tf` in each layer, together with variable validations and module preconditions, enforces guardrails at plan time. A check that expresses a policy rather than a structural fault usually has an `allow_*` switch in the layer's defaults. A selection of what fails the plan - each layer's section below has the rest:
- Every layer: a key reference - `zone_key`, `tunnel_key`, `member_keys`, `policy_keys` and the like - that names nothing, with an explicit error.
- `zones`: a `zone_config` entry referencing an undeclared zone.
- `account_governance`: an unknown role, permission group or resource group name; a restricted role; a member email outside `allowed_email_domains`.
- `zerotrust`: an unintended team-name change; an Access policy using a restricted decision (`bypass`); an `include` rule admitting an email outside `allowed_email_domains`; an OAuth identity provider without its secret, or a secret with no provider.
- `device_posture`: a firewall check that passes a disabled firewall, a binary check with no signing thumbprint, a posture result that expires in less than twice its polling period, or a service provider integration missing a setting or its credential.
- `gateway`: a category or application name that does not resolve; a custom policy in the reserved precedence band; two policies sharing a precedence; an HTTP rule while TLS decryption is off or unmanaged.
- `waf` and `rules`: two policies for the same zone; an unknown baseline name or a baseline missing its input; managed rulesets or bot traffic below the zone tier they need; a cache rule that could cache a personalised response.
- `load_balancing`, `pages`, `r2`, `tunnels`, `workers`: a hostname outside the zone its `zone_key` names.
- `r2`: public `.r2.dev` access, wildcard CORS, or a bucket-wide deleting lifecycle rule.
- `workers`: a queue that dead letters into itself; a queue with no consumer, or a consumer with no dead letter queue; a D1 database in a `jurisdiction` with read replication on; a `secret_text` binding; a Worker with no compatibility date or with observability off.
- `wan`: a static route to an unmanaged tunnel or next hop, a prefix reachable over one tunnel, a public or default route, or a tunnel with health checks off.
- `tunnels`: a route naming an undeclared tunnel, a public or default private network route, or an origin with TLS verification off.
- `logpush`: a zone-scoped job on a zone below Enterprise, a dataset pushed from the wrong scope, or a credential committed in a Logpush destination.

---

## Zones

The `zones` layer manages zone lifecycle, rate plan subscriptions, TLS posture, zone settings and, where a zone or the account asks for it, bot management. Adding a zone needs only a `zones.tfvars` entry: with no `zone_config` entry it gets the platform baseline, and its records go in `dns.tfvars`.

```hcl
# config/zones.tfvars
zones = {
  primary = {
    domain_name = "example.com"
    zone_tier   = "business"
  }
  internal = {
    domain_name = "example.net"
  }
}
```

```hcl
# config/zone_config.tfvars
zone_config = {
  primary = {
    ssl_mode         = "strict"
    min_tls_version  = "1.2"
    always_use_https = "on"
    zone_settings    = { security_level = "high" }
  }
}
```

A `zone_config` entry may also set `zone_type` (`full`, `partial`, `secondary` or `internal`), `paused`, `tls_1_3`, `manage_subscription` and `bot_management`. Any other zone setting goes in `zone_settings` as `setting_id = value`, merged over `default_zone_settings`; the dedicated fields above win over a `zone_settings` key of the same name. Every zone also gets `zone_base`'s own baseline: `automatic_https_rewrites`, `opportunistic_encryption`, `browser_check` and `http3` on. A zone's `bot_management` block replaces `default_bot_management` wholesale rather than merging with it, and a field the zone's `zone_tier` does not support fails the plan.

Removing a setting or a `bot_management` block does not revert it. Neither has a delete operation at Cloudflare, so the planned destroy only drops it from state, and the last applied value stays live on the zone - see the [Notes](#notes) on planned destroys.

A new zone stays `pending` until the registrar points at the nameservers in this layer's `name_servers` output.

`zone_config.<key>.dns_records` still exists, from before DNS moved to its own layer: records declared there are created by the `zones` layer, in its state. Keep each zone's records in exactly one layer; new records belong in `dns.tfvars`.

### Governing defaults

| Setting | Default | Effect |
|---|---|---|
| `default_ssl_mode` | `"strict"` | Requires valid SSL certificates on origins. Prevents interception between Cloudflare edge and origin. |
| `default_min_tls_version` | `"1.2"` | Rejects legacy TLS 1.0 and 1.1 connections edge-wide. |
| `default_tls_1_3` | `"on"` | Enables TLS 1.3 without 0-RTT by default (0-RTT requires idempotent origins). |
| `default_always_use_https` | `"on"` | Automatically redirects HTTP requests to HTTPS with a 301 redirect. |
| `default_zone_settings` | `{ security_level = "medium" }` | Settings every zone gets, beneath its own `zone_settings`. |
| `default_zone_tier` | `"free"` | The plan assumed for a zone with no `zone_tier`. It decides which bot management fields are allowed, and is the plan bought when a subscription is managed. |
| `default_bot_management` | `null` | No bot management resource is created, and the zone's current bot settings are left alone, unless a zone sets `bot_management`. |
| `manage_zone_subscriptions` | `false` | Billing safeguard. When false, Terraform does not change a zone's rate plan; a zone can override it with `zone_config.<key>.manage_subscription`. When on, `zone_tier` is the plan bought, the plan shows a `BILLING` warning rather than failing, and the run needs Billing Read and Write - on a separate token, per the layer's `providers.tf`. |
| `default_subscription_frequency` | `"monthly"` | Billing frequency for a managed subscription: `weekly`, `monthly`, `quarterly` or `yearly`. Ignored unless the subscription is managed. |

---

## DNS

The `dns` layer manages DNS records independently of zone containers. Isolating DNS records into its own layer prevents routine record updates from introducing drift or risk to zone settings.

```hcl
# config/dns.tfvars
dns_config = {
  primary = {
    dns_records = [
      { name = "@", type = "A", content = "203.0.113.10", ttl = 1, proxied = true },
      { name = "www", type = "CNAME", content = "example.com", ttl = 1, proxied = true },
      { name = "@", type = "MX", content = "mail.example.com", ttl = 3600, priority = 10 },
      { name = "@", type = "TXT", content = "v=spf1 include:_spf.example.com -all", ttl = 3600 },
      { name = "_dmarc", type = "TXT", content = "v=DMARC1; p=reject; rua=mailto:dmarc@example.com", ttl = 3600 },
    ]
  }
}
```

### Key Considerations
- `dns_config` is keyed by the zone keys in `zones.tfvars`; an unknown key fails the plan. Only zones with at least one record are looked up.
- `proxied = true` requires `ttl = 1` (automatic TTL). Proxying is supported only on `A`, `AAAA`, and `CNAME` records. Otherwise `ttl` is `1` or 30 to 86400 seconds, and `MX`, `SRV` and `URI` records need a `priority`. A record may also carry a `comment` and `tags`.
- Names can be specified as `"@"`, relative (`"www"`), or fully qualified (`"www.example.com"`). The module normalises them automatically. Declaring both relative and fully qualified variations of the same record causes a plan validation failure.
- A record is identified by its type, fully qualified name and content, so reordering the list changes nothing. Changing any of those three plans a destroy and a create rather than an in-place update.
- Records another layer or Cloudflare writes are not declared in `dns.tfvars`: the CNAMEs `tunnels` and `pages` create for published hostnames and custom domains, and the records Cloudflare manages for R2 and Worker custom domains. The DNS module manages only declared records and will not prune unmanaged ones.

---

## WAF Baseline

The `waf` layer manages custom firewall rules, rate limiting, managed rulesets and per-category bot traffic rules, one `waf_policies` entry per zone. Operators select baseline security policies by name rather than writing complex wirefilter expressions manually.

```hcl
# config/waf.tfvars
waf_trusted_ip_ranges = ["203.0.113.0/24"] # block_admin_from_untrusted needs it

waf_policies = {
  primary = {
    zone_key              = "primary"
    baseline_custom_rules = ["block_admin_from_untrusted", "block_known_exploit_paths"]
    baseline_rate_limits  = ["auth_brute_force", "api_general"]
  }
}
```

The baseline catalogue is defined in `layers/waf/locals.waf.tf` and parameterised via variables: `waf_trusted_ip_ranges`, `waf_admin_paths`, `waf_blocked_countries` and `waf_ip_blocklist_name` for the custom rules, and `waf_managed_rules_action`, `waf_owasp_paranoia_level`, `waf_owasp_score_threshold` and `waf_owasp_action` for the managed rulesets, and `waf_html_submission_paths`, `waf_html_submission_methods` and `waf_html_submission_skip_rule_ids` for the managed exceptions. Beyond the catalogue, a policy takes the tenant's own `custom_block_rules`, `rate_limiting_rules` and `managed_exceptions`, and raw `managed_rulesets` IDs. An unknown baseline name fails the plan.

### Custom rules

| Name | Action | Requires |
|---|---|---|
| `block_admin_from_untrusted` | `block` | `waf_trusted_ip_ranges` |
| `geoblock_countries` | `block` | `waf_blocked_countries` |
| `block_listed_ips` | `block` | `waf_ip_blocklist_name` - the `name` of a list the `lists` layer creates |
| `block_known_exploit_paths` | `block` | None |
| `challenge_undisclosed_bots` | `managed_challenge` | `waf_trusted_ip_ranges` |
| `log_trusted_admin_access` | `log` | `waf_trusted_ip_ranges` |

`waf_admin_paths` defaults to eight paths, `/user/login`, `/user/password` and `/user/register` among them, so `block_admin_from_untrusted` blocks those login pages for every address outside `waf_trusted_ip_ranges`. Trim the list where that is wrong for a site.

### Rate limits

All four count over a 60-second window, per client IP per data centre.

| Name | Mitigation | Notes |
|---|---|---|
| `auth_brute_force` | `block` | 20 requests to a path containing `/login` or `/auth`; blocks for 600 seconds. |
| `api_general` | `managed_challenge` | 600 requests under `/api/`; challenges for 60 seconds. |
| `origin_error_shield` | `block` | 50 origin responses of 500 or above, `/healthz` excluded; blocks for 60 seconds. |
| `observe_only` | `log` | 1000 requests, `/healthz` excluded. Measures traffic before enforcement. The module forces `mitigation_timeout = 0` for every `log` rate limit. |

### Managed rulesets and bot traffic

`baseline_managed_rulesets` selects `cloudflare_managed` and `owasp_core` into the `http_request_firewall_managed` phase. A zone below `managed_rules_min_tier` - `enterprise` in the platform defaults - fails the plan. Cloudflare deploys a managed entry point on every paid zone when it is created, and the `import` block in `layers/waf/imports.tf` adopts it automatically.

`bot_traffic` sets an action - `allow`, `log`, `managed_challenge`, `js_challenge`, `challenge` or `block` - for verified bots in Cloudflare's `search`, `agent` and `training` categories, with per-category `category_overrides`. A bot that does not declare itself has no category and is unaffected. A zone below `bot_traffic_min_tier` (`pro`) fails the plan. Zone-wide Bot Fight Mode and bot management settings, `ai_bots_protection` included, belong to the `zones` layer.

### Managed exceptions

An exception turns off specific managed rules for narrowly scoped traffic, such as a route that accepts HTML by design, while every other managed rule keeps running. Exceptions are skip rules placed at the top of the `http_request_firewall_managed` entry point, ahead of the execute rules. A skip in `custom_block_rules` cannot do this: Cloudflare only accepts a skip naming individual rulesets or rules in the phase that executes them, so from the custom phase the only option is `skip.phases`, which drops every managed ruleset at once.

```hcl
# config/waf.tfvars
waf_html_submission_paths = [
  "/templates/new",
  "/templates/[0-9]+",
]

waf_policies = {
  primary = {
    zone_key                  = "primary"
    baseline_managed_rulesets = ["cloudflare_managed", "owasp_core"]
    baseline_managed_exceptions = {
      html_submission = { hostnames = ["app.example.com"] }
    }
  }
}
```

| Name | Matches | Skips |
|---|---|---|
| `html_submission` | A `waf_html_submission_methods` request (`POST` by default) to a `waf_html_submission_paths` route on the listed `hostnames` | The OWASP anomaly verdict, and the Cloudflare Managed rules in `waf_html_submission_skip_rule_ids`. The rest of the Cloudflare Managed Ruleset, SQLi and RCE rules included, still runs. |

The routes are application-specific, so `waf_html_submission_paths` has no baseline default and is set in `waf.tfvars`. Each entry is a regular expression anchored at both ends, so it matches one route shape; anything in front of the route, such as a version or locale prefix, has to be part of the pattern.

`hostnames` is required and should only name hosts behind Cloudflare Access: the exception relies on Access, not the WAF, to keep anonymous traffic away from these routes. An exception only skips rulesets its own policy executes, and one left with nothing to skip fails the plan. Exceptions are always logged, so they show in Security Events.

`waf_html_submission_skip_rule_ids` starts empty, so out of the box the exception only skips the OWASP verdict. Add a Cloudflare Managed rule to it when Security Events shows it blocking a legitimate submission, taking the Rule ID from the event. Rule IDs are the same in every account, so the list can live in `layers/waf/defaults.auto.tfvars` or in `waf.tfvars`. Cloudflare keeps adding signatures, so expect to append to it over time. Do not widen the exception to a whole hostname.

**Automatic Colocation Characteristic:** Cloudflare tracks zone-level rate limits per data centre colocation, rejecting rate limiting rules that omit `cf.colo.id` (API error 20155). The layer automatically appends `cf.colo.id` to all rate limiting rules, eliminating manual configuration errors.

**Rule Evaluation Order:** the custom ruleset runs `bot_traffic` rules first, then the baseline, then the tenant's `custom_block_rules`, so a tenant rule - a skip included - cannot undo a baseline block that has already matched. Two exceptions: a `bot_traffic` `allow` is written as a skip of the rest of the custom ruleset, so matching bots are exempt from the baseline custom rules; and a tenant skip using `skip.phases` can skip the rate limiting and managed phases, where the baseline rate limits and managed rulesets run. Managed exceptions sit in the managed phase itself, ahead of the managed rulesets.

**Validation Guardrails:** A baseline rule selected without its input fails the plan: `waf_trusted_ip_ranges`, `waf_blocked_countries` or `waf_ip_blocklist_name`, per the table above. For example, enabling `block_admin_from_untrusted` with an empty `waf_trusted_ip_ranges` would generate a rule blocking all admin access globally, including internal operations. `waf_admin_paths` is not checked, so keep it non-empty: empty, the admin rules produce an expression Cloudflare rejects at apply.

### Governing defaults

| Setting | Default | Effect |
|---|---|---|
| `waf_trusted_ip_ranges` | `[]` | Must be set before selecting any rule that reads it. |
| `waf_blocked_countries` | `[]` | Must be set before selecting `geoblock_countries`. |
| `waf_ip_blocklist_name` | `null` | Must be set before selecting `block_listed_ips`. |
| `waf_html_submission_paths` | `[]` | Must be set before selecting `html_submission`. |
| `waf_html_submission_methods` | `["POST"]` | Methods `html_submission` covers. Add `PUT` or `PATCH` for routes that take them. |
| `waf_html_submission_skip_rule_ids` | `[]` | Cloudflare Managed rules `html_submission` skips. Append from Security Events. |
| `default_zone_tier` | `"free"` | The plan assumed for a zone with no `zone_tier` in `zones.tfvars`, for the two tier gates below. |
| `managed_rules_min_tier` | `"enterprise"` | Minimum zone plan for managed rulesets. |
| `bot_traffic_min_tier` | `"pro"` | Minimum zone plan for `bot_traffic`. |
| `waf_owasp_paranoia_level` | `1` | OWASP rules above this paranoia level are disabled. |
| `waf_owasp_score_threshold` | `40` | OWASP anomaly score that triggers the action. |
| `waf_managed_rules_action`, `waf_owasp_action` | `null` | Leaves each ruleset's rules on the action Cloudflare ships. |

---

## Account Governance

The `account_governance` layer manages account-level membership, user groups, and role-based access control (RBAC). Changes here affect who can access the Cloudflare dashboard.

```hcl
account_members = {
  dns_operator = { email = "dns.operator@example.com" }
}

user_groups = {
  dns_operators = {
    name        = "DNS Operators"
    member_keys = ["dns_operator"]
    policies = [
      { permission_group_names = ["DNS Write", "Zone Read"] },
    ]
  }
}
```

Role, permission group, and resource group IDs are account-specific. The layer dynamically resolves human-readable names to IDs at plan time (`permission_lookup.tf`). An unknown role or resource group name fails the plan and lists the names the account has; an unknown permission group name fails the plan and points at the dashboard catalogue. Where a name is ambiguous, `role_ids`, `permission_group_ids` and `resource_group_ids` take the ID instead, merged with the names.

- A policy is `access = "allow"` by default; `"deny"` is supported, and Cloudflare evaluates deny first. A policy that names no resource group covers the whole account, which needs exactly one account-scoped resource group to resolve.
- Deleting a member revokes their access on the next apply, and changing an email revokes the old address and sends a fresh invitation. An invitee shows as pending in the `member_statuses` output until they accept.
- Renaming a group's `name` recreates the group, and its members lose its permissions until the new one exists.
- `member_ids` adds people managed outside Terraform to a group. This layer never revokes them.

### Governing defaults

| Setting | Default | Effect |
|---|---|---|
| `default_role_names` | `["Minimal Account Access"]` | Members that set no `role_names` receive these roles, in addition to any `role_ids`. Permissions are then granted predictably through user groups. |
| `restricted_role_names` | `["Super Administrator - All Privileges"]` | Fails the plan if a member is given this role, by name or ID. Granting Super Administrator requires an explicit exception. User group policies are not checked against it. |
| `allowed_email_domains` | `[]` (any) | Restricts member invitations to corporate email domains, matched exactly on the part after `@`, so each subdomain needs its own entry. Mistyped external addresses fail at plan time. |

### Out of Scope
- **API Tokens:** API tokens represent credentials and must never enter Terraform state.
- **Account Resource:** The layer manages memberships and groups, but does not own the account resource itself.

---

## R2

The `r2` layer provisions object storage buckets, CORS configurations, lifecycle rules, object retention locks, and custom domains.

```hcl
r2_buckets = {
  public_assets = {
    name = "example-public-assets"

    cors_rules = [
      {
        allowed_origins = ["https://app.example.com"]
        allowed_methods = ["GET", "HEAD"]
        max_age_seconds = 3600
      },
    ]

    lifecycle_rules = [
      { id = "expire-raw", prefix = "raw/", delete_objects_after_days = 30 },
    ]

    custom_domains = [
      { zone_key = "primary", hostname = "assets.example.com" },
    ]
  }
}
```

A bucket that declares `lifecycle_rules` replaces `default_lifecycle_rules` rather than adding to it, so the example above loses the default rule that aborts incomplete multipart uploads after 7 days. Declare that rule again alongside your own, as `config/r2.tfvars` does, or set `lifecycle_rules = []` to opt out deliberately.

The lifecycle and lock resources own each bucket's whole rule list, and every bucket declares its `r2.dev` setting, so a rule added or a switch flipped in the dashboard is reverted on the next apply. Each lock rule sets exactly one of `retain_for_days`, `retain_until_date` or `retain_indefinitely`.

### Provider 5.x Native Resources
Older Cloudflare Terraform patterns used the AWS provider for R2 bucket lifecycles and CORS. This layer relies exclusively on native Cloudflare provider resources: `cloudflare_r2_bucket`, `cloudflare_r2_bucket_cors`, `cloudflare_r2_bucket_lifecycle`, `cloudflare_r2_bucket_lock`, `cloudflare_r2_managed_domain` and `cloudflare_r2_custom_domain`. The layer needs no S3 access key at all.

### Governing defaults

| Setting | Default | Effect |
|---|---|---|
| `allow_public_r2_dev_domains` | `false` | Fails the plan if a bucket requests an unauthenticated, uncached `pub-<hash>.r2.dev` public URL. Public assets should be served via `custom_domains` behind Cloudflare cache and WAF. |
| `allow_wildcard_cors_origins` | `false` | Fails the plan if any CORS rule's `allowed_origins` contains `"*"`, preventing unauthorised cross-origin data exposure. |
| `allow_bucket_wide_object_expiry` | `false` | Fails the plan if an enabled lifecycle rule that deletes objects has an empty or omitted prefix, preventing accidental bucket-wide object deletion. Multipart aborts and storage class transitions may use an empty prefix. |
| `default_custom_domain_min_tls` | `"1.2"` | Minimum TLS for a custom domain that sets no `min_tls` of its own. A default, not a floor: a domain can still set a lower one. |
| `default_lifecycle_rules` | abort incomplete multipart uploads after 7 days | Applied to every bucket that declares no `lifecycle_rules`. |
| `default_storage_class` | `"Standard"` | For a bucket that states none. `default_bucket_location` and `default_jurisdiction` are `null`, leaving both to Cloudflare. |

The plan also fails for a custom domain outside its zone, a bucket name or custom domain hostname used twice, a deleting lifecycle rule that overlaps a lock prefix, and an Infrequent Access transition on a bucket already in that class.

---

## Zero Trust

The `zerotrust` layer manages Cloudflare Access: the Zero Trust organisation (team name, plus the account-wide session, seat and dashboard-lock settings), identity providers, service tokens, access groups, reusable access policies and access applications.

```hcl
identity_providers = {
  entra_id = {
    name   = "Entra ID"
    type   = "azureAD"
    config = { client_id = "<application id>", directory_id = "<tenant id>", support_groups = true }
  }
}

access_groups = {
  platform_engineers = {
    name = "Platform Engineers"
    include = {
      entra_groups = [
        { identity_provider_key = "entra_id", group_id = "<entra_group_object_id>" },
      ]
    }
  }
}

access_policies = {
  platform_engineers_mfa = {
    name     = "Platform Engineers with MFA"
    decision = "allow"
    include  = { group_keys = ["platform_engineers"] }
    require  = { auth_methods = ["mfa"] }
  }
}

access_applications = {
  grafana = {
    name        = "Grafana"
    domain      = "grafana.example.com"
    policy_keys = ["platform_engineers_mfa"]
  }
}
```

An Entra group rule matches nobody unless its identity provider sets `support_groups = true`.

### Team Name Management
A Cloudflare Zero Trust organisation must exist before Access resources can be provisioned, and Terraform cannot create one: on an account without it, every plan of this layer fails on the organisation lookup. Choose the team name once, outside Terraform - in the Zero Trust dashboard, or with `POST /accounts/<account_id>/access/organizations`.

From then on the layer always adopts the existing organisation (read in `organization_lookup.tf`) and owns its settings. The first apply overwrites the dashboard's session, seat and login values with this layer's, and sets the display name to `zero_trust_organization_name` - the team name when that is unset. Leave `zero_trust_team_name` unset to keep the current team name, or set it to assert it. Renaming an existing team domain breaks active Access URLs and WARP registrations, so a value that differs from the current name fails the plan unless `allow_team_name_change = true`. Set that for the renaming run only, then set it back.

### Secrets Injection
Identity provider client secrets (such as Microsoft Entra ID application registration secrets) must never be committed to `.tfvars` files. They are supplied as an environment variable in the shell that runs `cflz`, keyed by the `identity_providers` key:

```bash
export TF_VAR_identity_provider_secrets='{"entra_id":"<the_secret>"}'
```

The plan fails for an OAuth-type provider (`azureAD`, `oidc`, `okta`, `google` and the like) with no secret, and for a secret whose key matches no provider. A config that declares no OAuth-type provider needs no variable at all: SAML and the one-time PIN take no secret.

Service token client secrets are generated by Cloudflare and held in plain text in this layer's state, and in any saved plan. No output exposes them - only `service_token_client_ids` and `service_token_expires_at`. Cloudflare shows a service token's secret once, at creation, so the state is the only place to read one for hand-over. From inside `deployment/layers/zerotrust`, while the state still exists:

```bash
terraform show -json | jq -r '.values.root_module.child_modules[]
  | select(.address == "module.zerotrust") | .resources[]
  | select(.type == "cloudflare_zero_trust_access_service_token") | "\(.index): \(.values.client_secret)"'
```

Access applications carry [resource tags](#resource-tags) from the `access_applications` section of `tags.tfvars`, separate from the Access tags in `access_applications[*].tags`.

### Governing defaults

| Setting | Default | Effect |
|---|---|---|
| `restricted_policy_decisions` | `["bypass"]` | Fails the plan if an Access policy uses `bypass`, which removes authentication entirely. `bypass` combined with `include.everyone` is refused whatever this says. |
| `allowed_email_domains` | `[]` (any) | When set, fails the plan if an `include` rule in an access group or policy admits an `emails` address or `email_domains` entry outside the list. `exclude` and `require` are not checked. |
| `lock_dashboard_to_read_only` | `false` | When enabled, locks the Zero Trust dashboard to read-only, establishing GitOps as the sole modification route. `ui_read_only_toggle_reason` records why it was lifted. |
| `default_session_duration` | `"24h"` | Default session lifespan before re-authentication is required. |
| `default_warp_auth_session_duration` | `"24h"` | The same, for sessions authenticated through the WARP client. |
| `user_seat_expiration_inactive_time` | `"730h"` | How long an inactive user keeps a seat. Cloudflare's minimum. |
| `auto_redirect_to_identity` | `false` | Whether the login page skips straight to the only identity provider. |
| `allow_authenticate_via_warp` | `false` | Whether a WARP session satisfies Access without a separate login. |
| `allow_team_name_change` | `false` | Fails the plan if `zero_trust_team_name` differs from the current team name. |
| `default_service_token_duration` | `"8760h"` | Validity for a service token that sets no `duration`: one year. A token may still set its own, including `"forever"`, and nothing refuses it. |

---

## Device Posture

The `device_posture` layer manages the checks a device must pass before an Access or Gateway policy lets it through - Cloudflare One Client checks run on the device (client running, OS version, disk encryption, firewall, a signed EDR binary, a corporate serial number) - and the service provider integrations that read a verdict from an MDM or EDR: Intune, CrowdStrike, SentinelOne, Kolide, Tanium, Workspace ONE, Uptycs or a custom API.

It is deliberately separate from `zerotrust`. Two layers consume a posture rule - Access policies in `zerotrust` and Gateway policies in `gateway`. Apply it before either: a policy can only name a rule by an ID read after this layer has applied. It also keeps the MDM and EDR credentials out of `zerotrust` state, which already holds identity provider secrets and service tokens.

Uptycs can be connected as an integration, but no posture rule type reads it yet.

```hcl
# config/device_posture.tfvars - the integration needs TF_VAR_device_posture_integration_secrets
device_posture_rules = {
  require_client = { name = "Cloudflare One Client Running", type = "warp" }

  windows_supported_build = {
    name      = "Windows 11 23H2 or Later"
    type      = "os_version"
    platforms = ["windows"]
    input     = { operating_system = "windows", operator = ">=", version = "10.0.22631" }
  }

  intune_compliant = {
    name            = "Intune Compliant"
    type            = "intune"
    integration_key = "intune"
    input           = { compliance_status = "compliant" }
  }
}

device_posture_integrations = {
  intune = {
    name   = "Microsoft Intune"
    type   = "intune"
    config = { client_id = "<application id>", customer_id = "<tenant id>" }
  }
}
```

### Referencing a Rule
Neither consuming layer can read this layer's state, so a rule is referenced by ID: apply it, read `device_posture_rule_ids` from this layer's outputs (see [Reading a layer's outputs](#reading-a-layers-outputs)), and put the ID in a rule set's `device_posture_ids` in `zerotrust.tfvars` - `access_policies.<key>.require.device_posture_ids`, for instance - or in `gateway_policies.<key>.device_posture_check_ids` in `gateway.tfvars`.

Renaming a rule replaces it and changes its ID. Removing one that a policy still names leaves the policy requiring a check nothing can pass - so take it out in two steps. Remove the reference from `zerotrust.tfvars` or `gateway.tfvars` and apply that layer, then remove the rule and apply this one.

### Secrets Injection
An integration's credential never goes in `.tfvars`. It is supplied as an environment variable in the shell that runs `cflz`, keyed by integration:

```bash
export TF_VAR_device_posture_integration_secrets='{"intune":{"client_secret":"<entra_app_client_secret>"}}'
```

The plan fails for an integration missing a setting or credential its type needs, and for a credential no integration reads. Cloudflare tests the connection on create, so a wrong credential still fails at apply. The example `device_posture.tfvars` keeps its integrations commented out, so the layer plans as shipped with no secret set.

| Integration type | `config` it needs | Secret keys |
|---|---|---|
| `intune` | `client_id`, `customer_id` | `client_secret` |
| `crowdstrike_s2s` | `client_id`, `customer_id`, `api_url` | `client_secret` |
| `kolide` | nothing | `client_secret` |
| `sentinelone_s2s`, `tanium_s2s` | `api_url` | `client_secret` |
| `workspace_one` | `client_id`, `api_url`, `auth_url` | `client_secret` |
| `uptycs` | `customer_id` | `client_key`, `client_secret` |
| `custom_s2s` | `api_url`, `access_client_id` | `access_client_secret` |

### Governing defaults

| Setting                         | Default      | Effect |
| ---------------------------------| --------------| --------|
| `default_posture_schedule`      | `"5m"`       | Client re-check interval, stated explicitly as Cloudflare's own default. Applied to device checks other than `warp`, `gateway` and `tanium`. |
| `default_integration_interval`  | `"10m"`      | How often Cloudflare polls a service provider. |
| `derive_posture_expiration`     | `true`       | A rule with no expiration gets twice its polling period: its schedule for a device check, or its integration's interval for a service provider check. Without one, a device that stops reporting keeps its last pass indefinitely. `warp` and `gateway` checks, and rules that read through an `integration_id`, get none. |
| `require_signed_binary_checks`  | `true`       | Fails the plan for a `file`, `application`, `sentinelone` or `carbonblack` check with no `input.thumbprint`, which any file at that path would pass. A `file` check with `exists = false` is exempt. |
| `restricted_posture_rule_types` | `["tanium"]` | Refuses the legacy Access-only Tanium check, which Gateway cannot evaluate. |

Whatever `derive_posture_expiration` says, an explicit expiration shorter than twice the polling period fails the plan.

A firewall check with `enabled = false` always fails the plan: it passes only devices whose firewall is off.

### Out of Scope
- **Zero Trust lists:** the serial number or device ID list a `serial_number` or `unique_client_id` check reads is maintained outside Terraform, and referenced by `list_id`.
- **Client certificates:** the signing certificate a `client_certificate_v2` check validates against is uploaded separately, and referenced by `certificate_id`.
- **WARP client deployment and device profiles.**

---

## Cloudflare Tunnel

The `tunnels` layer manages Cloudflare Tunnels: outbound-only `cloudflared` connectors that publish origins on a private network without opening an inbound port, the proxied DNS record behind each published hostname, and the private network routes and virtual networks WARP clients reach through a tunnel.

It is deliberately separate from `zerotrust`. Access decides *who* may reach an application; a tunnel decides *what* is reachable at all. Separate state means an Access policy change cannot delete a tunnel, and a tunnel change cannot loosen a policy.

```hcl
# config/tunnels.tfvars
cloudflare_tunnels = {
  london_dc = {
    name = "lon-dc-01"
    ingress = [
      { hostname = "grafana.example.com", zone_key = "primary", path = "^/api/", service = "http://grafana-api.internal:3000" },
      { hostname = "grafana.example.com", zone_key = "primary", service = "http://grafana.internal:3000" },
    ]
  }
  manchester_dc = { name = "man-dc-01" }
}

tunnel_virtual_networks = {
  manchester = { name = "man-dc" }
}

tunnel_routes = {
  london_servers     = { network = "172.16.10.0/24", tunnel_key = "london_dc" }
  manchester_servers = { network = "172.16.10.0/24", tunnel_key = "manchester_dc", virtual_network_key = "manchester" }
}
```

### Public Hostnames
Ingress rules are evaluated in order and the first match wins, so a path-specific rule goes above the bare hostname it narrows. A catch-all rule (`default_catch_all_service`, a 404 by default, or the tunnel's own `catch_all_service`) is appended automatically, because `cloudflared` requires the last rule to match everything. A hostname may appear in one tunnel only.

A tunnel can also set its own `config_src`. One set to `"local"` takes its rules from the connector's own config file, so it must declare no `ingress` - the plan fails if it does - and it gets no remote configuration, no catch-all and no CNAMEs from this layer.

Every rule with a `zone_key` gets its proxied CNAME (`<tunnel-id>.cfargotunnel.com`) created in that zone by this layer, in the same apply as the tunnel, so a hostname cannot exist without the record that routes to it. Do not also declare that record in `dns.tfvars`: Cloudflare refuses a second record of the same name.

A published hostname is reachable by anybody on the internet unless an Access application in `zerotrust` covers it. This layer cannot see that layer's state, so it cannot check. Pair every hostname with an application there, and set `origin_request.access` so `cloudflared` also validates the Access token at the origin.

### Connector Tokens
No tunnel secret is sent, so Cloudflare generates one it never returns, and the layer never reads the connector token. State and outputs hold nothing that can run a connector, and this layer takes no `TF_VAR_` secret. Fetch a token when installing a connector - from the dashboard, `cloudflared tunnel token <tunnel-id>`, or `GET /accounts/<account_id>/cfd_tunnel/<tunnel_id>/token` - and deliver it to the host through a secret store. A tunnel shows `inactive` until a connector runs.

Redundancy is more connectors on one tunnel, not more tunnels: run `cloudflared` with the same token on a second host.

### Out of Scope
- **Running `cloudflared`:** connectors are deployed on the origin network by whatever manages those hosts.
- **Who may use a route:** a private network route makes a range reachable by an enrolled device. Restricting it to people is a Gateway network policy or an Access application with a private destination.

### Governing defaults

| Setting | Default | Effect |
|---|---|---|
| `default_tunnel_config_src` | `"cloudflare"` | Remotely managed: the ingress rules here are what every connector runs, and a dashboard edit shows up as drift. |
| `default_catch_all_service` | `"http_status:404"` | Unmatched requests get a 404 rather than falling through to a real service. |
| `allow_no_tls_verify` | `false` | Fails the plan if an origin setting disables certificate verification. Use `ca_pool` or `origin_server_name` instead. |
| `allow_unmanaged_tunnel_hostnames` | `false` | Fails the plan if an ingress rule has no `zone_key`, since nothing would route the hostname to the tunnel. |
| `allow_default_tunnel_route` | `false` | Prohibits `0.0.0.0/0` or `::/0` tunnel routes, which would make one connector the internet egress for every WARP device. |
| `allow_public_tunnel_route_prefixes` | `false` | Restricts tunnel routes to RFC 1918, RFC 6598 or IPv6 ULA ranges. |

---

## Logpush

The `logpush` layer manages Logpush jobs: one dataset, pushed from an account or a zone, to one destination - a SIEM, an HTTP endpoint or an object store. It is how Cloudflare's logs leave Cloudflare: the account audit trail, Gateway and Access activity, and every HTTP request and firewall event on a zone.

> **Enterprise only.** Cloudflare refuses a Logpush job on any other plan. On an account without it, leave `logpush_jobs = {}`.

```hcl
# config/logpush.tfvars
logpush_jobs = {
  audit_archive = {
    dataset = "audit_logs"
    # No destination_conf: an R2 URI carries its access key, so it arrives in TF_VAR_logpush_destination_secrets
    output_options = {
      field_names = ["When", "ActionType", "ActorEmail", "ActorIP", "ResourceType", "ResourceID"]
    }
  }

  primary_http_requests = {
    dataset          = "http_requests"
    zone_key         = "primary" # zones.tfvars must give this zone zone_tier = "enterprise"
    destination_conf = "s3://example-com-logs/http_requests/{DATE}?region=eu-west-2&sse=AES256"
    filter = <<-JSON
      {"where":{"and":[{"key":"ClientRequestPath","operator":"!eq","value":"/healthz"}]}}
    JSON
    output_options = {
      field_names = ["EdgeStartTimestamp", "RayID", "ClientIP", "ClientRequestHost", "ClientRequestURI", "EdgeResponseStatus"]
    }
  }
}
```

### Scope
Each dataset is produced per zone (`http_requests`, `dns_logs`, ...) or per account (`audit_logs`, `gateway_dns`, `access_requests`, ...), and a few, such as `firewall_events`, at both. A job for a zone dataset names a `zone_key`; a job for an account dataset does not. The catalogue that decides which is `logpush_zone_datasets` and `logpush_account_datasets` in `layers/logpush/variables.tf`, and a job in the wrong scope, or on a dataset in neither list, fails the plan rather than the apply.

A zone-scoped job also needs its zone on Enterprise. The layer reads `zone_tier` from `zones.tfvars` and fails the plan below `logpush_min_zone_tier`, so declare the zone's real plan there. A zone with no `zone_tier` counts as `default_zone_tier`, which is `free`, and fails.

`output_options.field_names` is required on every job. Cloudflare has no "all fields" option, and each dataset's page in the Logpush documentation lists its fields.

### Destinations and Secrets
A destination with no credential in its URI - S3, Google Cloud Storage - is committed as `destination_conf`. One that carries a credential - R2 access keys, a Splunk HEC token, a Datadog API key, an Azure SAS, an HTTP auth header - is not: the job leaves `destination_conf` out, and the whole URI is supplied at plan time, keyed by job:

```bash
export TF_VAR_logpush_destination_secrets='{"audit_archive":"r2://<bucket>/audit/{DATE}?account-id=<id>&access-key-id=<key_id>&secret-access-key=<secret>"}'
```

The plan fails on a credential-shaped `destination_conf` in a `.tfvars`, on a job with neither or both, and on a secret keyed to no job.

Where Cloudflare asks for proof of control before it will push - object stores such as S3 and Google Cloud Storage - it writes a challenge file into the destination, and the file's contents go in `TF_VAR_logpush_ownership_challenges` under the job's key. A challenge keyed to no job fails the plan.

Set both in the shell that runs `cflz plan` and `cflz apply`. Both reach state, and any saved plan, in plain text.

### Governing defaults

| Setting | Default | Effect |
|---|---|---|
| `default_logpush_job_enabled` | `true` | A declared job pushes. The provider's own default is disabled, which looks configured and ships nothing. |
| `default_logpush_timestamp_format` | `"rfc3339"` | Parsed by every SIEM without a custom rule, and what a dashboard-built job uses. The API's own default is `unixnano`. |
| `default_logpush_output_type` | `"ndjson"` | One record format across every job. |
| `default_cve_2021_44228_redaction` | `true` | Rewrites `${` to `x{` in the output, so a Log4Shell lookup string a client sent never reaches a downstream log processor intact. |
| `logpush_min_zone_tier` | `"enterprise"` | Fails the plan for a zone-scoped job on a lower plan, which Cloudflare would refuse at apply. |
| `required_logpush_account_datasets` | `[]` | Account datasets the account must push, e.g. `["audit_logs"]`. Empty by default because Logpush is Enterprise-only. |
| `allow_logpush_sampling` | `false` | Fails the plan if a job samples its output. A sampled log drops the event that matters as readily as any other. |
| `allow_insecure_logpush_destinations` | `false` | Fails the plan for a plain `http://` destination or `insecure-skip-verify=true`, checked against secret destinations too. |

### Out of Scope
- **The destination itself:** buckets, bucket policies, SIEM indexes and HEC tokens are created where they live. An R2 log bucket can come from the `r2` layer; its access key cannot, by design.
- **Ownership challenge automation:** the token is read out of the destination, which this layer holds no credential for.

---

## Gateway (Secure Web Gateway)

The `gateway` layer manages outbound corporate egress filtering: DNS policies, network L4 policies, HTTP L7 inspection rules, account-level Gateway settings, and automated root CA certificate lifecycle.

### Three Enforcement Pipelines

| Pipeline | Inspection Point | Visibility Scope | Typical Actions |
|---|---|---|---|
| `dns` | Resolves query prior to connection | Hostname only. Blind to payload or path | `allow`, `block`, `override`, `safesearch`, `ytrestricted` |
| `network` | L4 connection (TCP/UDP/ICMP) | Ports, IP addresses, TLS SNI | `allow`, `block`, `l4_override` |
| `http` | Decrypted L7 HTTP/HTTPS traffic | Full URL path, query strings, headers, body | `allow`, `block`, `on`, `off`, `scan`, `noscan`, `isolate`, `noisolate`, `quarantine`, `redirect` |

An action from another pipeline fails the plan. `override`, `l4_override`, `quarantine` and `redirect` each need their matching `settings` block. Selectors are per pipeline too: `domains` and `hosts` on `dns` and `http`; `sni_domains`, `sni_hosts`, `destination_ports` and `protocols` on `network` only; methods, file types and DLP profiles on `http` only. A policy with no selector fails unless it sets `match_all_traffic = true`, which `allow`, `off`, `noscan` and `noisolate` may not. `device_posture_check_ids` sits on the policy itself, not under `match`.

### Precedence Architecture
Gateway evaluates policies in ascending precedence order within each pipeline. Lower precedence numbers execute first.

Precedence is allocated across the whole account, though, not per pipeline: no two Gateway policies of any type may share a number, and a duplicate fails the plan. Numbers below `reserved_precedence_ceiling` (default `100`) are strictly reserved for platform baseline policies, which use 10 to 60. Custom rules in account configuration must specify precedence values of 100 or higher, with recommended intervals of 100 to permit future rule insertion.

```hcl
gateway_policies = {
  allow_sanctioned_smtp = {
    name       = "Allow Sanctioned SMTP Relay"
    type       = "network"
    action     = "allow"
    precedence = 100
    match = {
      destination_ip_cidrs = ["203.0.113.25/32"]
      destination_ports    = [587]
      protocols            = ["tcp"]
    }
  }

  block_direct_smtp = {
    name       = "Block Direct Outbound SMTP"
    type       = "network"
    action     = "block"
    precedence = 200
    match      = { destination_ports = [25, 465, 587], protocols = ["tcp"] }
  }
}
```

### Account Settings & TLS Decryption
`gateway_settings = null`, the platform default, leaves the account's Gateway settings unmanaged, and the dashboard stays authoritative. The settings object already exists on every Zero Trust account, so to manage it, import it first, at `module.gateway.cloudflare_zero_trust_gateway_settings.this["<account_id>"]` - without the import, the first apply writes it from this configuration alone and drops whatever the dashboard held.

The `gateway_settings` object configures account-wide Gateway posture:
- `tls_decrypt.enabled`: Controls whether Gateway intercepts and decrypts outbound HTTPS connections.
- `protocol_detection.enabled`: Identifies protocols from packet contents rather than relying solely on destination ports.
- `antivirus`: Configures scanning of uploaded and downloaded files.

```hcl
gateway_settings = {
  tls_decrypt        = { enabled = true }
  protocol_detection = { enabled = true }
  activity_log       = { enabled = true }
  antivirus = {
    enabled_download_phase = true
    enabled_upload_phase   = true
    fail_closed            = false
  }
}

gateway_inspection_certificate = {
  validity_period_days = 1826 # 5 years
}
```

### Automated Root CA Lifecycle
Enabling TLS decryption without an active root CA certificate causes Cloudflare API error 400 (code 2211). Setting `gateway_inspection_certificate` has Cloudflare generate and activate a root CA for the account and, when `gateway_settings` is managed, points `gateway_settings.certificate.id` at it. Do not also set `certificate.id` - the plan fails if both are set.

Activation is asynchronous. Wait for the `inspection_certificate_binding_status` output to read `available`, distribute `inspection_certificate_pem` to all managed endpoints (via Microsoft Intune, Group Policy, or MDM) to prevent untrusted certificate warnings across user devices, and only then enable `tls_decrypt.enabled`, in a later change. Nothing renews the root: watch `inspection_certificate_expires_on`. Changing `validity_period_days` replaces it, creating the new root before destroying the old.

### Baseline Policies
The platform baseline is a catalogue of six policies in `layers/gateway/locals.gateway.tf`, each opt-in by name through `gateway_baseline_policies` (empty by default). Selecting one whose input variable is empty fails the plan.

| Name | Pipeline | Action | Precedence | Reads |
|---|---|---|---|---|
| `block_security_threats` | `dns` | `block` | 10 | `gateway_security_categories` |
| `bypass_trusted_applications` | `http` | `off` | 20 | `gateway_bypass_applications` |
| `block_security_threats_http` | `http` | `block` | 30 | `gateway_security_categories` |
| `block_disallowed_content` | `dns` | `block` | 40 | `gateway_blocked_content_categories` |
| `block_dlp_matches` | `http` | `block` | 50 | `gateway_dlp_profile_ids` |
| `quarantine_risky_downloads` | `http` | `quarantine` | 60 | `gateway_quarantine_file_types` |

Category and application names match case-insensitively, and one that does not resolve fails the plan. The API does not tell content categories from security categories, so a name put in the wrong variable resolves but never matches.

### Microsoft 365 Decryption Bypass
Certain enterprise applications (such as Microsoft 365 desktop clients) use certificate pinning and fail under TLS decryption. The platform baseline provides a preconfigured bypass rule:

```hcl
gateway_baseline_policies   = ["bypass_trusted_applications"]
gateway_bypass_applications = ["Microsoft 365"]
```

Cloudflare processes Do Not Inspect (`action = "off"`) rules before evaluating inspection-dependent policies. `restricted_actions = ["off"]` would refuse this baseline along with any tenant bypass.

### Governing defaults

| Setting | Default | Effect |
|---|---|---|
| `reserved_precedence_ceiling` | `100` | Reserves precedence 1 to 99 for platform baseline rules. Custom policies claiming lower precedence fail at plan time. |
| `restricted_actions` | `[]` | Actions no policy may use, baseline policies included. |
| `default_block_notification` | enabled, with a stock message | Added to every `block` policy that sets no notification of its own, baseline blocks included. |
| `default_untrusted_cert_action` | `"error"` | What an HTTP `allow` policy that sets nothing does with an origin whose certificate is invalid. |
| `allow_antivirus_fail_closed` | `false` | Fails the plan if antivirus `fail_closed` is enabled without explicit authorisation. Unscannable or oversized files are delivered rather than causing widespread unexplained download failures. |
| `allow_uninspected_http_policies` | `false` | Fails the plan if a `gateway_policies` HTTP rule other than `action = "off"` exists while `gateway_settings` is null or `tls_decrypt.enabled` is not true. Prevents false security assumptions where L7 rules would only apply to unencrypted HTTP. With `gateway_settings` managed, baseline HTTP rules are checked too. |
| `allow_dlp_payload_logging` | `false` | Fails the plan if a policy sets `settings.payload_log_enabled = true`, which records sensitive matching data in logs. |
| `allow_disabling_dnssec_validation` | `false` | Fails the plan if a policy sets `settings.insecure_disable_dnssec_validation = true`. |
| `allow_untrusted_certificate_pass_through` | `false` | Fails the plan if a policy, or `default_untrusted_cert_action`, uses `"pass_through"` for origins with invalid certificates. |

---

## Cloudflare WAN

The `wan` layer manages Magic WAN: IPsec and GRE tunnels connecting customer premises, data centres, and cloud VPCs to Cloudflare Anycast edge, optionally peering over BGP, alongside static routing.

```hcl
wan_ipsec_tunnels = {
  london_primary = {
    name                = "lon-ipsec-01"
    cloudflare_endpoint = "192.0.2.10"
    customer_endpoint   = "203.0.113.10"
    interface_address   = "10.252.0.0/31"
  }
  london_secondary = {
    name                = "lon-ipsec-02"
    cloudflare_endpoint = "192.0.2.10"
    customer_endpoint   = "203.0.113.11"
    interface_address   = "10.252.0.2/31"
  }
}

wan_static_routes = {
  london_lan_primary = {
    prefix     = "10.10.0.0/16"
    tunnel_key = "london_primary"
    priority   = 100
  }
  london_lan_secondary = {
    prefix     = "10.10.0.0/16"
    tunnel_key = "london_secondary"
    priority   = 200
  }
}
```

Two tunnels per prefix is the baseline: a prefix reachable over one tunnel fails the plan unless `allow_single_tunnel_prefixes` is set. GRE tunnels go in `wan_gre_tunnels`, with the same shape. Either kind can peer over BGP by setting `bgp_customer_asn` (and `bgp_extra_prefixes`). A static route names exactly one of `tunnel_key` or `nexthop`, and an IPv6 route takes its next hop from the tunnel's `interface_address6` (a `/127`). Interconnects (CNI) have no resource here; one can only be reached as a `nexthop`.

### Derived Next Hops
In a `/31` tunnel interface, Cloudflare occupies one IP address and the customer edge router occupies the other. Static routes must target the customer router as the next hop. The layer derives customer next-hop IP addresses automatically from `tunnel_key`, preventing configuration errors that route traffic into Cloudflare's own endpoint.

### Secrets Injection
IPsec Pre-Shared Keys (PSKs), and BGP MD5 keys where a tunnel peers, must never be stored in `.tfvars`. They are supplied as the `TF_VAR_wan_ipsec_tunnel_psks` and `TF_VAR_wan_bgp_md5_keys` environment variables, in the shell that runs `cflz`:

```bash
export TF_VAR_wan_ipsec_tunnel_psks='{"london_primary":"<32_char_secure_psk>"}'
```

Omitting a tunnel's PSK is valid: Cloudflare generates one that Terraform never sees, visible only in the dashboard. The plan fails for a PSK shorter than 16 characters, for a PSK keyed to anything but an IPsec tunnel, and for an MD5 key on a tunnel that sets no `bgp_customer_asn`.

### Governing defaults

| Setting | Default | Effect |
|---|---|---|
| `default_tunnel_health_check_*` | enabled, `mid`, `reply`, `unidirectional` | Health check for a tunnel that sets none. |
| `allow_tunnels_without_health_checks` | `false` | Fails the plan if a tunnel sets `health_check_enabled = false`, which removes automated failover. |
| `allow_single_tunnel_prefixes` | `false` | Fails the plan if a static route prefix is reachable over fewer than two distinct tunnels or next hops. BGP prefixes are not checked. |
| `allow_static_routes_to_unmanaged_nexthops` | `false` | Fails the plan if a hand-written `nexthop` is not the customer side of a tunnel declared here. |
| `allow_default_static_route` | `false` | Prohibits default `0.0.0.0/0` or `::/0` routes into site tunnels. |
| `allow_public_static_route_prefixes` | `false` | Restricts static routes to private RFC 1918, RFC 6598, or IPv6 ULA ranges. |

---

## Lists

The `lists` layer manages account-scoped Cloudflare Lists: reusable collections of IP addresses, CIDR blocks, ASNs, or hostnames referenced across WAF and firewall rules as `$name`.

```hcl
# config/lists.tfvars
account_lists = {
  global_ip_blocklist = {
    name         = "corp_global_ip_blocklist"
    kind         = "ip"
    description  = "Operationally managed IP blocklist"
    manage_items = false
  }
  partner_egress_ips = {
    name         = "partner_egress_ips"
    kind         = "ip"
    description  = "Trusted partner static egress ranges"
    manage_items = true
    items = [
      { ip = "198.51.100.0/24", comment = "Partner Primary DC" },
      { ip = "203.0.113.50/32", comment = "Partner Secondary Gateway" },
    ]
  }
}
```

A row sets exactly one of `ip`, `asn` or `hostname` (`{ url_hostname, exclude_exact_hostname }`), matching the list's `kind` - `ip` unless stated, and changing it replaces the list. A list `name` is 1 to 50 lowercase letters, digits and underscores, unique in the account, because a rule refers to it as `$name`.

### Operational vs Managed Items
- `manage_items = false` (the default): Terraform provisions and manages the list container itself. List items are added or removed dynamically via the Cloudflare dashboard, SIEM integrations, or SOC automated response scripts without triggering Terraform state drift. Rows supplied for such a list fail the plan rather than being silently ignored. The `list_ids_for_api_load` output gives each unmanaged list's ID, keyed by name; the loader itself is outside this repository.
- `manage_items = true`: Terraform manages list rows authoritatively. Any out-of-band changes are reverted on the next apply. Recommended for stable corporate address allocations. More rows than `max_managed_items` (200 unless stated), a row that does not match `kind`, and duplicate rows all fail the plan.

Apply `lists` before `waf`, so that a named list exists before a WAF rule references it. The link is by name only: the WAF `block_listed_ips` baseline reads the list whose `name` equals `waf_ip_blocklist_name` in `waf.tfvars`.

---

## Rules

The `rules` layer manages zone-level traffic modification phases: Cache Rules (`http_request_cache_settings`), Transform Rules (`http_request_late_transform`), and Origin Rules (`http_request_origin`).

```hcl
# config/rules.tfvars
rule_policies = {
  primary = {
    zone_key = "primary"

    cache_rules = [
      {
        name        = "Cache anonymous static content"
        description = "Cache static assets ignoring query parameters for anonymous visitors"
        expression  = "not http.cookie contains \"session_id\""
        enabled     = true
        cache       = true
        cache_key = {
          custom_key = {
            query_string = { exclude = { all = true } }
          }
        }
      },
      {
        name       = "Bypass cache for authenticated API calls"
        expression = "http.request.uri.path contains \"/api/\""
        cache      = false
      },
    ]

    transform_rules = [
      {
        name       = "Strip untrusted client headers"
        expression = "true"
        enabled    = true
        headers = {
          "X-Forwarded-Host" = { operation = "remove" }
        }
      },
    ]

    origin_rules = [
      {
        name       = "Route legacy API to alternate backend"
        expression = "starts_with(http.request.uri.path, \"/api/v1/\")"
        enabled    = true
        origin = {
          host = "legacy-api.internal.example.com"
          port = 8443
        }
      },
    ]
  }
}
```

### Phase Evaluation Semantics
Rule evaluation behaviour differs by phase:
- **Cache Rules:** Cloudflare evaluates all matching rules and the **last** matching rule takes precedence. Broad caching rules should be placed first, followed by specific bypass exceptions.
- **Origin Rules:** Cloudflare evaluates rules in order and stops at the **first** match. Specific overrides must precede general rules.
- **Transform Rules:** request header changes only, in `http_request_late_transform`, after the security phases. A header set or removed here cannot influence a WAF rule, and a WAF rule cannot match on it; it changes only what the origin receives. URL rewrites and response header changes are not managed by this layer.

Each module owns its phase's entry-point ruleset for the zone. Values in these rules reach state and plan output, so they must never hold a credential.

### Guardrails
- An enabled cache rule with `cache = true` whose expression mentions neither a cookie nor `authorization` fails the plan unless it sets `acknowledge_public_response = true`, because it would cache one visitor's response for the next. The first example rule passes only because it tests `http.cookie`.
- Two `rule_policies` entries for the same zone fail the plan, as do a policy with no rules, a cache rule that sets nothing, a header operation with both or neither of `value` and `expression` (`remove` takes neither), and an origin rule that sets none of `host_header`, `origin` and `sni`.
- There is no plan-tier gate. The origin port and SNI overrides are Enterprise features, and on a lower plan Cloudflare rejects the whole origin ruleset at apply - the example's `port = 8443` included, on a `business` zone.

---

## Bulk Redirects

The `bulk_redirects` layer manages high-volume URL redirection at the Cloudflare edge, executing redirects before requests reach origin servers or Worker invocations.

```hcl
# config/bulk_redirects.tfvars
bulk_redirect_lists = {
  vanity_urls = {
    name         = "redirects_vanity_urls"
    description  = "Static marketing vanity redirects"
    manage_items = true
    items = [
      {
        source_url            = "example.com/legacy-docs"
        target_url            = "https://example.com/documentation"
        status_code           = 301
        preserve_query_string = true
      },
      {
        source_url            = "www.example.com/promo"
        target_url            = "https://www.example.com/promotions"
        status_code           = 302
        subpath_matching      = true
        preserve_path_suffix  = true
      },
    ]
  }
}

bulk_redirect_rules = [
  {
    list_key        = "vanity_urls"
    description     = "Apply vanity redirect list"
    scope_zone_keys = ["primary"]
  },
]
```

### Operational Considerations
- **Status Codes:** Use 302 (temporary) redirects during active testing or initial migration phases. Browsers cache 301 (permanent) redirects aggressively, making routing corrections difficult to propagate quickly. A row may use 301, 302, 307 or 308; one that states none gets `default_status_code`, 302.
- **Scope Restriction:** Scope redirect rules to specific zones using `scope_zone_keys` to limit blast radius. The layer needs no zone ID for this: each key becomes that zone's `domain_name` from `zones.tfvars`, matched as the host or any subdomain of it, and `scope_hostnames` adds exact hosts. A row whose source hostname is outside the zone inventory fails the plan unless `allow_hostnames_outside_zone_inventory` is set.
- **Rule Order:** `bulk_redirect_rules` is an ordered list, one rule per list, and the first redirect that matches wins. `enabled = false` stages or rolls back a list. The layer owns the account's single `http_request_redirect` entry-point ruleset, so nothing else may manage it.
- **Dataset Scalability:** `manage_items` defaults to `false`, and a managed list over `default_max_managed_items` (500) rows fails the plan. A larger dataset stays unmanaged and is loaded through the Lists API (`PUT .../rules/lists/<list_id>/items`) against the `list_id` in the `bulk_redirect_lists` output. This repository ships no loader for it.

A row's `source_url` is a hostname and path, with no scheme or query string; `target_url` is a full URL with its scheme; `preserve_path_suffix` needs `subpath_matching`; and duplicate sources fail the plan.

### Governing defaults

| Setting | Default | Effect |
|---|---|---|
| `default_manage_items` | `false` | Lists are containers only unless a list sets `manage_items = true`. |
| `default_max_managed_items` | `500` | Ceiling on the rows a managed list may hold. A list can set its own `max_managed_items`. |
| `default_status_code` | `302` | For a row that states none. The variable's own default is 301. |
| `default_preserve_query_string` | `true` | Cloudflare's own default is false. |
| `max_bulk_redirect_lists`, `max_bulk_redirect_rules` | `25`, `50` | Account ceilings, checked at plan time. |
| `allow_hostnames_outside_zone_inventory` | `false` | Fails the plan for a source hostname in no zone in `zones.tfvars`. |
| `allow_unreferenced_lists` | `false` | Fails the plan for a list no rule references. |

---

## Workers, KV, D1 & Queues

The `workers` layer manages Cloudflare Workers scripts, Workers KV namespaces, D1 databases, queues, script bindings, routes, custom domains, and cron triggers.

```hcl
# config/workers.tfvars
kv_namespaces = {
  config = {
    title = "example-config"
  }
}

worker_scripts = {
  security_headers = {
    name        = "example-security-headers"
    script_file = "headers/security_headers.js"

    bindings = [
      {
        name             = "CONFIG"
        type             = "kv_namespace"
        kv_namespace_key = "config"
      },
      {
        name        = "API_SECRET"
        type        = "secrets_store_secret"
        store_id    = "0123456789abcdef0123456789abcdef"
        secret_name = "telemetry-api-key"
      },
    ]

    routes = [
      {
        zone_key = "primary"
        pattern  = "example.com/*"
      },
    ]
  }
}
```

A Worker can also take `custom_domains = [{ zone_key = "primary", hostname = "api.example.com" }]` and `cron_schedules = ["*/30 * * * *"]`. A custom domain must sit inside its zone, must not also be a record in `dns.tfvars`, and cannot share a host with a route. A cron expression has five fields, runs in UTC, and needs a `scheduled()` handler in the script.

### Serverless State: D1 & Queues

D1 databases and queues are declared in the same file and bound by logical key, so `workers.tfvars` never carries a database UUID or a queue ID.

```hcl
# config/workers.tfvars - the same file as above: these Workers go in its one worker_scripts map
d1_databases = {
  telemetry = {
    name                  = "example-telemetry"
    primary_location_hint = "weur"
  }
}

queues = {
  telemetry = {
    name = "example-telemetry"

    consumer = {
      worker_key            = "telemetry_processor"
      dead_letter_queue_key = "telemetry_dlq"

      settings = {
        batch_size       = 50
        max_wait_time_ms = 5000
        max_retries      = 3
        retry_delay      = 30
      }
    }
  }

  # Holding pen for batches that failed three times. Exempt from
  # allow_queues_without_consumer because another queue dead letters into it.
  telemetry_dlq = {
    name                     = "example-telemetry-dlq"
    message_retention_period = 1209600
  }
}

worker_scripts = {
  telemetry_processor = {
    name        = "example-telemetry-processor"
    script_file = "queues/telemetry_processor.js"

    bindings = [
      # Producer side: this Worker writes to the queue.
      { name = "TELEMETRY_QUEUE", type = "queue", queue_key = "telemetry" },
      { name = "TELEMETRY_DB", type = "d1", d1_database_key = "telemetry" },
    ]
  }
}
```

- **Producer and consumer are declared in different places.** A producer is a `queue` binding on the Worker that writes; the consumer is declared on the queue, because Cloudflare gives a queue exactly one. A Worker may consume several queues, and any number of Workers may produce to one.
- **Ordering is derived, not declared.** A queue must exist before a Worker can bind it, and the Worker must exist before it can be named as that queue's consumer. The layer creates the queue from variables alone (`queue` module) and attaches the consumer separately, from the deployed Worker's name (`queue_consumer` module), so Terraform works out `queue -> Worker -> consumer` from the references without a `depends_on`. The consumer has to be its own module call: Terraform treats `module.queues[key]` as depending on everything inside that module, so a consumer inside it would leave the Worker waiting on itself.
- **D1 schema is not Terraform's.** The layer owns the database and the binding; tables come from migrations. A migration is an ordered one-way change, which is not what a plan reconciling desired state does.

  Migrations live in the layer at `migrations/<database_key>/0001_initial_schema.sql`, keyed by the same logical key a binding uses. After a `workers` apply, run [`scripts/d1-migrations.sh`](../scripts/d1-migrations.sh): it reads the `d1_databases` output, applies whatever has not run yet and records it in a `d1_migrations` table inside each database, so a re-run is a no-op. File names are validated before anything is applied, a directory naming a database `workers.tfvars` does not declare fails the run, and a migration that removes data is called out in the log. See [migrations/README.md](layers/workers/migrations/README.md).
- **A database's name, jurisdiction and location hint are set at creation.** A replaced D1 database is a new, empty one, so read a plan proposing a replacement as a plan to lose the data, and export first. `read_replication_mode` is the exception: it changes in place, though turning it off takes up to 24 hours to take effect.

### Architectural Standards
- **External Source Files:** each Worker is one ready-to-run JavaScript file under `deployment/layers/workers/scripts/` (`worker_source_dir`), named by `script_file` relative to that directory. It is uploaded unmodified: there is no bundling or TypeScript compile, and files it imports are not uploaded. Build a TypeScript or multi-file Worker first and commit the output. Script source code is not embedded directly in `.tfvars`.
- **Content Hashing:** the layer passes each script by path with its `filesha256()` as `content_sha256`. The source never enters state; the hash is what makes an edit show up in a plan.
- **Secrets Store Integration:** Production secrets are bound using Cloudflare Secrets Store references rather than plain-text environment variables, preventing credential exposure in Terraform state. The store and its secrets are created outside Terraform, in the dashboard or with wrangler; `workers.tfvars` names the store by ID and the secret by name.
- **Workers KV Scalability:** Terraform manages at most `default_max_managed_kv_pairs` (500) pairs per namespace, from `pairs` or a `pairs_file`; a namespace can override it with `max_managed_pairs`, and going over fails the plan. A larger dataset goes in `layers/workers/data/bulk/`, and `kv-bulk-load.sh` loads it after every apply. See [data/kv/README.md](layers/workers/data/kv/README.md).
- **Data Planes Stay Out Of State:** KV pairs beyond configuration, D1 rows and queue messages are all loaded or produced outside Terraform. The layer owns the container and the binding; the scripts and the application own the contents.

### Guardrails

Set in `layers/workers/defaults.auto.tfvars`; an account can override one in its own `workers.tfvars`.

| Variable | Default | Effect |
| --- | --- | --- |
| `allow_inline_secret_text` | `false` | Fails the plan if a Worker carries a `secret_text` binding, which holds the literal secret in the variable file, the plan output and state. Use a `secrets_store_secret` binding instead. |
| `allow_unpinned_compatibility_date` | `false` | Fails the plan if a Worker has neither its own `compatibility_date` nor `default_compatibility_date`, which would pin its runtime to whenever it was last uploaded. |
| `allow_disabled_observability` | `false` | Fails the plan if a Worker's resolved `observability.enabled` is false. Turning off `logs_enabled` or `invocation_logs`, or sampling at 0, is not caught. Sample with `head_sampling_rate` where the concern is volume. |
| `allow_queues_without_consumer` | `false` | Fails the plan if a queue has nothing reading it. Producers keep succeeding while the backlog ages out at the retention period, with nothing raising an error. A queue another queue dead letters into is exempt. |
| `allow_queue_consumer_without_dead_letter_queue` | `false` | Fails the plan if a consumer has no dead letter queue, in which case a message that fails `max_retries` times is deleted with no copy to examine. |
| `allow_replicated_d1_in_jurisdiction` | `false` | Fails the plan if a database restricted to a `jurisdiction` also has read replication on, which keeps a copy of the data in every supported region. |

### Governing defaults

| Setting | Default | Effect |
| --- | --- | --- |
| `default_compatibility_date` | `"2026-01-01"` | Pins every Worker that sets no date of its own, and is what satisfies `allow_unpinned_compatibility_date`. Bumping it redeploys all of those Workers in one plan. |
| `default_observability` | `enabled`, `logs_enabled` and `invocation_logs` all `true` | Merged field by field into each Worker's own `observability`. |
| `default_max_managed_kv_pairs` | `500` | Ceiling on the pairs Terraform manages per namespace. |
| `default_d1_read_replication_mode` | `null` | Setting it to `"auto"` trips `allow_replicated_d1_in_jurisdiction` for every database with a `jurisdiction`. |
| `default_queue_message_retention_period` | `null` | Cloudflare's own default, 4 days. A queue may set 60 to 1209600 seconds. |
| `default_logpush`, `default_usage_model`, `default_placement_mode`, `default_compatibility_flags`, `default_d1_primary_location_hint` | `false`, `null`, `null`, `[]`, `null` | Applied to a Worker or database that sets none of its own. |

The plan also fails, with no override, for a key that names nothing (`zone_key`, `kv_namespace_key`, `d1_database_key`, `queue_key`, a binding's or consumer's `worker_key`, `dead_letter_queue_key`), a queue that dead letters into itself, a missing script or `pairs_file`, a route pattern or custom domain claimed by two Workers, and two Worker, queue or D1 names that differ only in case.

---

## Load Balancing

The `load_balancing` layer manages origin health monitors, origin pools, and zone-level load balancers.

```hcl
# config/load_balancing.tfvars
load_balancers = {
  api_lb = {
    zone_key    = "primary"
    lb_hostname = "api.example.com"
    proxied     = true

    origins = [
      { name = "origin-primary", address = "203.0.113.10", weight = 1.0 },
      { name = "origin-secondary", address = "198.51.100.20", weight = 1.0 },
    ]

    health_check = {
      path = "/status" # every field left out takes default_health_check
    }
  }
}
```

Monitors and origin pools operate at account scope, whilst the load balancer hostname binding is scoped to the target zone. Hostnames must reside within the apex domain of the referenced `zone_key`.

Each entry creates one monitor, one pool named `<lb_hostname>-pool`, and one load balancer that uses that pool as both default and fallback. Traffic is split between origins by their `weight`; `steering_policy` chooses between pools, so with one pool it has nothing to choose, and left null it is Cloudflare's default failover. Optional per-entry fields: `session_affinity` (`none`, `cookie`, `ip_cookie` or `header`), `pool_minimum_origins`, `pool_notification_email`, and per-origin `port`, `header_host` and `enabled`.

`default_health_check` is `https`, `/healthz`, port 443, `GET`, expecting `2xx`, every 60 seconds with a 5-second timeout and 2 retries. A monitor switched to `type = "http"` keeps port 443 unless it sets its own. The plan fails for a duplicate `lb_hostname`, a `timeout` not shorter than `interval`, duplicate origin names, and a `pool_minimum_origins` above the origin count.

---

## Authenticated Origin Pulls

Authenticated Origin Pulls (AOP) is mutual TLS between the Cloudflare edge and the origin. The edge presents a client certificate on the origin connection, and an origin configured to verify it stops serving anything that did not arrive through Cloudflare - closing the hole that a WAF rule cannot, where an attacker who has learned the origin IP address connects to it directly and bypasses every edge control.

Managed by the `origin_pulls` layer, which calls [`modules/authenticated_origin_pulls`](../modules/authenticated_origin_pulls/) once per zone. It is split from `zones` for two reasons. Its state holds private keys, and putting them in the state that also owns every zone would make the most sensitive state in the repository the one most people need to plan against. And its token needs `SSL and Certificates:Edit` but must hold neither `Zone:Edit` nor `DNS:Edit` - an identity the origin trusts, combined with the ability to repoint a hostname, is a materially bigger prize than either alone.

### Two scopes

| Scope | Resource | What it covers |
|---|---|---|
| Zone-level | `cloudflare_authenticated_origin_pulls_settings`, `cloudflare_authenticated_origin_pulls_certificate` | Every hostname in the zone, on one certificate |
| Per-hostname | `cloudflare_authenticated_origin_pulls`, `cloudflare_authenticated_origin_pulls_hostname_certificate` | One hostname, on a certificate of its own |

Where both cover a hostname, Cloudflare applies the per-hostname association. That is what lets `api.example.com` hold a dedicated certificate its origin alone trusts, while the rest of the zone keeps the zone-level posture.

```hcl
origin_pulls = {
  primary = {
    enabled         = true
    certificate_key = "edge_client" # zone-wide; omit to use Cloudflare's default certificate

    hostnames = [
      { hostname = "api", certificate_key = "api_origin" },
      { hostname = "legacy", certificate_key = "api_origin", enabled = false },
      { hostname = "partner", certificate_id = "2458ce5a-0c35-4c7f-82c7-8e9487d3ff60" },
    ]
  }
}
```

A hostname is qualified against its zone, and one belonging to another zone fails the plan rather than being silently turned into `api.other.com.example.com`. Only a single label (`api`) or `@` (the apex) is qualified; a multi-label relative name such as `api.eu` is taken as written, and then fails as another zone's. Each hostname sets exactly one of `certificate_key` or `certificate_id`, and an `origin_pulls` key with no entry in `zones.tfvars` fails the plan. `enabled = false` parks an association without deleting it, which is the reversible way to take a hostname out.

### Cloudflare's default certificate identifies Cloudflare, not you

A zone that turns AOP on without uploading a certificate runs on the certificate the Cloudflare edge presents for **every** customer on the platform. An origin that trusts it therefore accepts anything proxied through any Cloudflare account, not only this one.

That is still a real filter in front of an origin that would otherwise accept traffic from anywhere, so it is allowed, and a single `check` warning names every zone using it. Where the origin is relied on to identify the tenant - a shared origin, a cardholder-data environment - upload a certificate of your own and set `certificate_key`. Setting `allow_shared_cloudflare_certificate = false` turns that warning into a failed plan for the whole account.

### Exporting the trust bundle to the origin

The layer's `origin_trust_bundles` output is the deliverable for whoever configures the origin: per zone, the PEM the origin's client-certificate trust store has to hold. In order, it carries Cloudflare's Origin Pull CA (only for a zone running on the default certificate), the zone certificate, then every per-hostname certificate uploaded here; `origin_trust_bundle_sources` lists which is which. Certificates only - no private key is ever output. A certificate referenced by `certificate_id` is in no bundle, and has to come from wherever it was uploaded.

Because the bundle is per zone, installing it at the origin of a hostname with a dedicated certificate makes that origin trust the zone's other certificates too. There, install only the hostname's own certificate.

Read it once the layer has applied (see [Reading a layer's outputs](#reading-a-layers-outputs)). From the repository root:

```bash
terraform -chdir=deployment/layers/origin_pulls output -json origin_trust_bundles \
  | jq -r '.primary' >cloudflare-client-ca.pem
```

```nginx
# NGINX, and the NGINX ingress controller's server-snippet
ssl_client_certificate /etc/nginx/cloudflare-client-ca.pem;
ssl_verify_client on;
```

For Azure Application Gateway, upload the same file as a Trusted Client Certificate on an SSL profile and attach that profile to the listener. Both verify the chain only; neither checks *which* certificate was presented, so a bundle holding more than one accepts any of them.

### Order of operations

Applying this layer changes what Cloudflare **sends**. It does not make the origin ask for anything, and nothing in this state can see whether the origin has been changed.

1. Apply `origin_pulls`.
2. Take the bundle out of `origin_trust_bundles` and install it at the origin.
3. Switch the origin to require a client certificate.

Doing 3 before 1 fails every request in between. Removing a certificate runs the same sequence backwards: stop requiring it at the origin first.

### Secrets Injection

Certificate material never goes in `.tfvars`. It is supplied as an environment variable in the shell that runs `cflz`, keyed by certificate:

```bash
# One entry per certificate_key origin_pulls.tfvars names - edge_client and api_origin in the example above
export TF_VAR_origin_pull_certificates="$(jq -n \
  --rawfile ec edge.crt --rawfile ek edge.key \
  --rawfile ac api.crt --rawfile ak api.key \
  '{edge_client: {certificate: $ec, private_key: $ek}, api_origin: {certificate: $ac, private_key: $ak}}')"
```

PEM is line-structured and a value flattened to one line is rejected by Cloudflare, which is why the keys are read with `--rawfile` rather than pasted. The plan fails for a `certificate_key` naming material that was not supplied, and for supplied material nothing refers to - an unused private key in state is one nobody rotates and nobody misses.

Self-signed is normal here: the origin is told to trust this certificate itself, so there is nothing for a public CA to add. Cloudflare does not renew an uploaded certificate, and an expired one fails every origin connection it covers, so watch `expires_on` in the `certificates` output.

### Governing defaults

| Setting | Default | Effect |
|---|---|---|
| `default_zone_level_enabled` | `false` | Zone-level AOP is opt-in per zone rather than inherited. |
| `allow_shared_cloudflare_certificate` | `true` | Permits a zone to run on Cloudflare's default certificate, with one `check` warning naming every such zone. `false` fails the plan instead. |
| `cloudflare_origin_pull_ca_certificate` | `null` | Uses the copy vendored at `layers/origin_pulls/ca/`. See that directory's README to refresh it. |

### Out of Scope

Edge mTLS in the other direction - client certificates presented *by visitors to Cloudflare*, through API Shield or an Access mTLS policy - is a different resource family (`cloudflare_mtls_certificate`, `cloudflare_zero_trust_access_mtls_certificate`) and is not managed here. The zone's SSL mode, which has to be `full` or `strict` for any of this to apply, belongs to the `zones` layer.

---

## Turnstile

The `turnstile` layer manages Cloudflare Turnstile widgets: the CAPTCHA replacement a form embeds, and the secret its backend validates the resulting token with. A widget is account-scoped and attached to no zone - the hostname list is free text, so a widget may legitimately name a domain this account does not hold, and Cloudflare will not warn when a hostname is wrong. The widget simply refuses to render on the page that embeds it.

```hcl
# config/turnstile.tfvars
turnstile_widgets = {
  primary = {
    name = "Primary site (example.com)"
    domains = [
      "example.com",
    ]
    mode = "managed"
  }
}
```

A hostname covers itself and every subdomain, so `example.com` also serves `www.example.com` - and listing `www.example.com` does *not* serve the apex. For that reason the plan fails for an apex and its subdomain in the same widget, and for the same hostname in two widgets. It also fails for a hostname that is not a plain FQDN - a scheme, port, path or wildcard - and for two widgets whose `name` differs only in case.

### The sitekey is the handover, and Terraform cannot complete it

A widget is two keys. The sitekey is public and belongs in the page; the secret is sent by the backend to `/siteverify`. This layer creates the widget and holds both, but it does not manage the page or the backend, so nothing here can tell whether a widget protects anything at all. Read `turnstile_sitekeys` after an apply (see [Reading a layer's outputs](#reading-a-layers-outputs)) and hand each value to whoever owns the page.

That asymmetry is also why a replacement is an outage rather than a diff. Updating a widget in place - hostnames, mode, branding - keeps the sitekey and live pages keep working. Replacing one issues a *new* sitekey while every page still carries the old one, and every challenge fails until those pages are redeployed. A `region` change, a key rename and an apply against an empty state all replace. Read any plan on this layer for "must be replaced" before approving it.

### Adopting widgets that already exist

If widgets are already in the account - and for Turnstile they usually are, because a widget is created in the dashboard the moment somebody protects a form - adopt them rather than letting this layer create duplicates. `layers/turnstile/imports.tf` carries the API query that lists them and a commented `import` block; the import id is `<account_id>/<sitekey>`. See that file before the first apply.

### Secrets

Nothing is injected into this layer: Cloudflare issues the secret, and Terraform records what the API returned, so **this layer's state holds every widget's secret key in plain text**. Anyone holding it can forge a passing `/siteverify` response for any form the widget protects, and it cannot be rotated in place - a new secret means a new widget, and a new widget means a new sitekey. The secret is deliberately not re-exported as a root output; it lives in `module.turnstile`. Read one from state when handing it over, from inside `deployment/layers/turnstile` while the state still exists:

```bash
terraform show -json | jq -r '.values.root_module.child_modules[]
  | select(.address == "module.turnstile") | .resources[]
  | select(.type == "cloudflare_turnstile_widget" and .index == "primary") | .values.secret'
```

Treat a leak of this state, or of a saved plan of this layer, as a compromise of every protected form.

### Governing defaults

| Setting | Default | Effect |
|---|---|---|
| `default_widget_mode` | `"managed"` | Cloudflare decides, and asks for a click only when it needs one. The mode that fails visibly. |
| `default_widget_region` | `"world"` | `"china"` is a separate widget network and is fixed at creation, so it is never a silent default. |
| `max_domains_per_widget` | `200` | Cloudflare's Enterprise ceiling, enforced before the API sees the widget. Every other plan allows 10, so on a non-Enterprise account set `max_domains_per_widget = 10` in its `turnstile.tfvars`, or 11 to 200 hostnames pass the plan and fail the apply. |
| `allow_offlabel_widgets` | `false` | Removing Cloudflare branding is a contractual and design decision, so it has to be switched on deliberately. |
| `invisible_mode_privacy_addendum_accepted` | `false` | Invisible mode tells the visitor nothing, which is why Cloudflare requires its privacy addendum first. |

### Out of Scope

Embedding the sitekey, calling `/siteverify`, and storing the secret in the backend all happen outside this repository. Pre-clearance interacts with the WAF challenge that the issued `cf_clearance` cookie satisfies, but the rule itself belongs to the `waf` layer.

---

## Pages

The `pages` layer manages Cloudflare Pages projects - static and Jamstack front ends - through [`modules/pages_project`](../modules/pages_project/), once per project. It declares the project, its Git source and branch deployment rules, its per-environment bindings and env vars, and its custom domains, including the proxied CNAME behind each. It is its own layer rather than part of `workers`: Pages has its own permission group, and the token that can change what a site serves should not also be able to rewrite the Workers in front of the API that site calls.

```hcl
# config/pages.tfvars
pages_projects = {
  docs_site = {
    name = "example-docs"
    source = {
      type      = "github"
      owner     = "example-org"
      repo_name = "docs"
    }
    build          = { build_command = "npm run build", destination_dir = "dist" }
    custom_domains = [{ hostname = "docs.example.com", zone_key = "primary" }]
  }

  admin_portal = {
    name              = "example-admin"   # Direct Upload: no `source`
    access_protection = "all"
    production        = { secret_names = ["SESSION_SECRET"] }
    custom_domains    = [{ hostname = "admin.example.com", zone_key = "primary" }]
  }
}
```

A project with a `source` builds on Cloudflare from GitHub or GitLab. Cloudflare's Git app must already be installed on the owner with access to the repository, and Terraform cannot install it. A project without one is **Direct Upload**: this layer creates it, and deployments arrive from `wrangler pages deploy` in the application's own pipeline. Either way, **this layer does not deploy anything**. A newly created project serves nothing until its first deployment lands.

### Custom domains need a DNS record, and the API does not create it

Adding a custom domain through the API - unlike the dashboard - does not write its DNS record, so the domain sits at `pending` and no certificate is issued. Give each custom domain a `zone_key` and this layer writes a proxied CNAME to the project's real pages.dev hostname. Without one, the plan fails unless `allow_unmanaged_pages_hostnames` is set, for a record genuinely managed elsewhere. A custom domain must sit inside the zone its `zone_key` names and belongs to one project only, and two projects cannot share a `name` - each fails the plan. A custom domain must not also be a record in `dns.tfvars`; nothing checks that, because neither layer can see the other's records.

### Access: the pages.dev hostname is the bypass

Protecting an internal portal is a `zerotrust` change. This layer neither writes nor checks an Access application. What it does is work out which hostnames one has to cover, and publish them in the `pages_access_applications` output, shaped as `access_applications` entries for `zerotrust.tfvars`. Copy each entry under the same key (`pages_<project key>`) and add `policy_keys`.

That list is the reason the output exists. Every project also answers on its own `<project>.pages.dev` hostname and every preview on `*.<project>.pages.dev`, and neither is covered by an Access application on the custom domain. The wildcard does not match the bare hostname either. (`<project>.pages.dev` here is the whole hostname the `pages_projects` output gives as `subdomain`.) So:

| `access_protection` | Hostnames in the hand-over | Use for |
|---|---|---|
| `previews` (default) | `*.<project>.pages.dev` | A public site whose unreleased branches should not be |
| `all` | every custom domain, `<project>.pages.dev`, `*.<project>.pages.dev` | An internal admin portal or dashboard |
| `none` | nothing | Only with `allow_unprotected_previews`, or on a Git project with `source.preview_deployment_setting = "none"`. A Direct Upload project always counts as publishing previews, because `wrangler pages deploy --branch` makes one |

The subdomain is read from the project after apply, not built from its name. pages.dev is one namespace across every Cloudflare account, and a name somebody else already holds is given a random suffix. Re-read the output after any apply that changes a project's custom domains: the `zerotrust` entry is a copy, and a hostname added here and not there is served without a login.

### Secrets and the browser

Plain `env_vars` are readable in the dashboard, the API and every plan of this layer. A secret is listed by name under `secret_names` and its value arrives in the `TF_VAR_pages_project_secrets` environment variable - see [VARIABLES_AND_SECRETS.md](../VARIABLES_AND_SECRETS.md). The plan fails for a declared secret with no value, or a value no project declares.

Both kinds of variable reach the build as well as Functions. A framework that inlines variables with a public prefix (`VITE_`, `NEXT_PUBLIC_`, `PUBLIC_`, `REACT_APP_`, `GATSBY_`, `NUXT_PUBLIC_`, `EXPO_PUBLIC_`, `VUE_APP_`, `STORYBOOK_`) writes the value into the JavaScript every visitor downloads, whatever type it was stored as. The plan refuses a secret under such a name outright, in any case, and refuses a plain variable whose name looks like a credential unless `allow_credential_like_plain_env_vars` is set.

**This layer's state holds every secret value in plain text.** Cloudflare never returns a secret once set, but Terraform records what it sent.

`production` and `preview` are configured separately and preview inherits nothing. A preview is built from any branch, so it should not be handed production's bindings or secrets by default.

### Adopting projects that already exist

A project name is unique per account, so applying against a project created in the dashboard fails rather than duplicating it. `layers/pages/imports.tf` carries the API query and commented `import` blocks for projects (`<account_id>/<project_name>`) and domains (`<account_id>/<project_name>/<hostname>`). A project with secret env vars cannot be imported; remove the secrets, import, then let this layer set them again. A CNAME that already exists for a custom domain has to be imported too, into `module.pages_project[<key>].cloudflare_dns_record.this["<hostname>"]` with id `<zone_id>/<record_id>`, or the apply tries to create a second record and the API refuses it.

### Governing defaults

| Setting | Default | Effect |
|---|---|---|
| `default_production_branch` | `"main"` | For a project that does not state one. |
| `default_preview_deployment_setting` | `"all"` | Every pushed branch gets a preview - which is why the next default matters. |
| `default_access_protection` | `"previews"` | Previews are listed in the Access hand-over unless a project says otherwise. |
| `allow_unprotected_previews` | `false` | A project publishing previews with `access_protection = "none"` fails the plan. |
| `allow_unmanaged_pages_hostnames` | `false` | A custom domain with no `zone_key` fails the plan, because nothing would create its record. |
| `allow_credential_like_plain_env_vars` | `false` | A plain env var whose name contains `SECRET`, `TOKEN`, `PASSWORD`, `PASSWD`, `API_KEY`/`APIKEY`, `PRIVATE_KEY`/`PRIVATEKEY` or `CREDENTIAL` - anywhere in the name, in any case - fails the plan. |

### Known gaps

- The API may return defaults for `deployment_configs` fields this layer leaves unset, which shows as drift on the plan after the first apply. Pin the field in `pages.tfvars` if it does.
- Unicode (IDN) custom domains are rejected. Punycode passes, but only without a `zone_key` - with one it fails the in-zone check, because `zones.tfvars` holds the Unicode zone name - so on an IDN zone a custom domain needs `allow_unmanaged_pages_hostnames` and a CNAME managed elsewhere.
- `web_analytics_token`, Durable Object, Hyperdrive, AI, Vectorize and mTLS bindings are not exposed yet, nor are `analytics_engine_datasets`, `browsers`, `limits`, `usage_model` or `build_image_major_version`.

---

## AI Gateway

The `ai_gateway` layer manages Cloudflare AI Gateway through [`modules/ai_gateway`](../modules/ai_gateway/), once per gateway. A gateway is a proxy between an application and its AI providers: it logs, caches, rate limits and applies DLP, guardrails and spend limits to every request sent through it, and its dynamic routes choose a model per request. It is account-scoped and attached to no zone - a client reaches it by URL - so the layer reads nothing and nothing reads it.

```hcl
# config/ai_gateway.tfvars
ai_gateways = {
  support_assistant = {
    gateway_id = "support-assistant"
    cache      = { ttl = 300 }
    rate_limit = { limit = 600, interval = 60, technique = "sliding" }
    guardrails = { prompt = { prompt_injection = "BLOCK", hate = "FLAG" } }
    routes = {
      support-default = {
        elements = {
          start   = { type = "start", outputs = { next = "primary" } }
          primary = { type = "model", provider = "openai", model = "gpt-5-mini", retries = 1, timeout = 30000, outputs = { success = "end" } }
          end     = { type = "end" }
        }
      }
    }
  }
}
```

### The endpoint is the handover, and Terraform cannot complete it

A gateway does nothing until an application's base URL points at it. `ai_gateway_endpoints` (see [Reading a layer's outputs](#reading-a-layers-outputs)) gives both forms: `base`, which takes the provider's path segment and its own API path (`<base>/openai/chat/completions`), and `openai_compat`, the OpenAI SDK base URL, where the model is `<provider>/<model>` or `dynamic/<route>`. Hand them to whoever owns the application.

Every gateway is authenticated by default: requests must carry `cf-aig-authorization: Bearer <token>`, with a Cloudflare API token holding `AI Gateway Run`. This layer does not create that token - it is the application's credential - and Cloudflare cannot scope one to a single gateway, so any Run token can use every gateway on the account, BYOK keys included. `authentication = false` fails the plan unless `allow_unauthenticated_gateways` is set: the account ID and gateway ID in the URL are not secrets, so an unauthenticated gateway serves anyone who guesses the second. Routes, BYOK and Zero Data Retention need authentication on regardless, and the plan says so.

### Logs are prompts

`collect_logs` is on by default, as it is at Cloudflare, and a log is the full prompt and response of every request, kept with no time limit until `log_storage.max_logs` rotates it. Any credential with `AI Gateway Read` can read them, and the one this layer runs with can read and delete them. Cloudflare has no grant that reads a gateway's settings without its logs. For a gateway in front of anything sensitive, set `collect_logs = false`, or keep the data out with `dlp_policies`. `zero_data_retention` is not a logging switch: it only sends Unified Billing traffic to OpenAI and Anthropic endpoints that do not retain it.

### A new gateway may need a second apply

Cloudflare's create call does not take `dlp_policies`, `guardrails` or `spend_limits`; only its update call does. Provider 5.23 sends them on create regardless. If the API drops them, the gateway comes up without them - DLP and guardrails still recorded as applied, spend limits possibly failing the apply as an inconsistent result - and the next plan's refresh shows them as a change. The apply after that is the one that turns them on. Plan again after creating a gateway that declares any of the three, and apply what it shows, before pointing a client at it.

### Dynamic routes

A route is a graph of elements - `start`, `conditional`, `rate`, `model`, `end` - declared as a map keyed by element ID, each element's `outputs` naming the element that runs next. The plan checks the graph: one start, at least one end, no dangling or self-referencing outputs, nothing pointing back at the start, and no element other than the start that no output points at. It does not check that every element is reachable from the start, or that the graph has no cycle. Percentage splits are not supported; the provider cannot represent their outputs.

The API changes a route's elements by creating a new version and deploying it, and provider 5.23 only ever updates a route's name. So **any element change replaces the route**: it is deleted and recreated under the same name. Clients call it by name, as `dynamic/<name>`, so nothing needs redeploying, but requests to it fail for the seconds in between. Cloudflare's docs expect the providers a route calls to have BYOK keys stored on the gateway; adding those is outside Terraform.

### Adopting gateways that already exist

A gateway ID is unique per account, so applying against one created in the dashboard fails rather than duplicating it. `layers/ai_gateway/imports.tf` carries the API queries and commented `import` blocks for gateways (`<account_id>/<gateway_id>`) and routes (`<account_id>/<gateway_id>/<route_id>`). Read it first: spend limit rules must keep their existing IDs as their keys, a route must be imported only with its elements copied exactly, and a gateway switched to Unified Billing in the dashboard is switched back by the first apply that changes it. An adopted gateway that already uses BYOK must also set `secrets_store_id`, or the apply unlinks its store - that one is in the variable's description in `modules/ai_gateway`, not in `imports.tf`. `default` is the gateway Cloudflare creates on its own, and on most accounts it has to be imported rather than declared.

### Governing defaults

| Setting | Default | Effect |
|---|---|---|
| `default_authentication` | `true` | Callers need a token with `AI Gateway Run`. |
| `default_collect_logs` | `true` | Cloudflare's default, and what analytics and Logpush are built on. Logs are full prompts and responses. |
| `default_log_storage` | `10000000`, `DELETE_OLDEST` | What the API gives a gateway that states neither. `STOP_INSERTING` stops recording, and Logpush exporting, at the cap. Workers Free holds 100000 logs per account. |
| `max_ai_gateways` | `20` | Cloudflare's Workers Paid ceiling, enforced before the API sees it (10 on Workers Free). |
| `allow_unauthenticated_gateways` | `false` | A gateway with `authentication = false` fails the plan. |

### Known gaps

- Nothing here has been applied to a live account. Every guardrail has been fired and every resource planned offline against provider 5.23.0; how the API treats each field on the first real apply has not been seen.
- `otel` and `stripe` are not managed. OTel exports every prompt and completion to a third-party collector and needs a credential; Stripe is undocumented beyond its API schema.
- BYOK provider keys and provider configs have no Terraform resource (cloudflare/terraform-provider-cloudflare#7332), and the Logpush job for the AI Gateway dataset has no dataset value in the provider. Both are dashboard steps.
- `workers_ai_billing_mode` can only be `postpaid` on provider 5.23 (#7331), and `log_classification` and `byok_only` do not exist in it yet. All need a provider bump.
- The unit of a spend limit's `window` is not documented by Cloudflare. Verify it against a rule created in the dashboard before relying on one.

---

## A second account

There is one `config/` directory and it describes one account. The Accelerator has no notion of a second: each layer keeps a single state file, so pointing the same clone at another account would have Terraform plan to move the first account's baseline rather than build a new one.

For another customer, or another account of the same customer, use a fresh clone with its own config and its own state. If the accounts need to be managed together, over time, that is what [Cloudflare Landing Zones](https://github.com/itsharryshelton/CloudflareLandingZone) is built for: one config tree and one set of scoped credentials per account, behind a pipeline.

## Adding a new product layer

To introduce a new Cloudflare product layer:

1. Create a directory `layers/<product>/`, named after the Cloudflare product it manages.
2. Add the standard root files: `terraform.tf` (no backend block), `providers.tf` (an empty `provider "cloudflare" {}`, with a comment listing the permissions an API token would need), `variables.tf`, `locals.tf`, `<subject>.tf`, and `outputs.tf`.
3. Source its modules by relative path, `../../../modules/<name>`.
4. If the layer binds to zones, include `zone_lookup.tf` and define `referenced_zones` so it resolves zone keys dynamically via `data "cloudflare_zone"` instead of reading another layer's state.
5. Add `preflight.tf` to assert on all logical key references and guardrails at plan time.
6. Provide a baseline `defaults.auto.tfvars` where appropriate.
7. Add `<product>.tfvars` to `config/`, assigning only variables the new layer declares. `scripts/cflz.sh layers` then lists it against the layer with no other edit.
8. If the layer takes a secret, declare it as a `sensitive` variable with an empty default and add it to [VARIABLES_AND_SECRETS.md](../VARIABLES_AND_SECRETS.md).
9. Add the layer to the tables in this file and in the [root README](../README.md), and to [Apply Order](#apply-order) if another layer has to be applied before it.

[CONTRIBUTING.md](../CONTRIBUTING.md) has the conventions and the checks to run.
