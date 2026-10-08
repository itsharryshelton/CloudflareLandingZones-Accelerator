# `modules` - the building blocks

Every Cloudflare resource this repository creates is declared in a module here.
A module wraps one Cloudflare concern - a zone, a set of DNS records, a WAF
entry point, a tunnel - behind a small, validated set of inputs, and knows
nothing about the repository around it: no accounts, no logical keys, no layers,
no customers.

The layers under [../deployment/layers/](../deployment/layers/) are what call
them. A layer holds the estate-shaped view - every zone, bucket or tunnel in the
account, keyed by a logical name - turns those names into real Cloudflare IDs,
and calls a module once per item.

The modules sit in this directory and every layer sources them by relative path
(`../../../modules/<name>`), so a clone of the repository is everything a run
needs. They are the same modules [Cloudflare Landing Zones](https://github.com/itsharryshelton/CloudflareLandingZone)
publishes as versioned repositories; here there is nothing to publish and no
tag to pin.

This file covers what every module has in common. There is deliberately no
README per module: each module documents itself in its variable descriptions
and the header comments of its `locals.tf` and `main.tf`, where the text cannot
drift away from the code.

## Where a module sits

```text
deployment/config/*.tfvars                what to build, by logical key: zone_key = "primary"
        │
        ▼
deployment/layers/<layer>/                resolves keys to IDs, applies platform defaults,
        │                                 runs preflight.tf, calls the module with for_each
        │   module "x" { for_each = ..., zone_id = "<32 hex>" }
        ▼
modules/<module>/                         one resource group: validates, normalises,
        │                                 declares resources, outputs IDs
        ▼
cloudflare/cloudflare provider            configured by the layer, never by the module
```

## The modules

| Module | Called by layer | Manages |
|---|---|---|
| `account_governance` | `account_governance` | Account members, user groups and their memberships |
| `account_list` | `lists` | One account-level IP, ASN or hostname list, and optionally its rows |
| `ai_gateway` | `ai_gateway` | One AI Gateway and its dynamic routes |
| `authenticated_origin_pulls` | `origin_pulls` | Authenticated Origin Pulls for one zone: settings, zone and per-hostname certificates |
| `bulk_redirect_list` | `bulk_redirects` | One redirect list, and optionally its rows |
| `bulk_redirect_ruleset` | `bulk_redirects` | The account's `http_request_redirect` entry-point ruleset |
| `cache_rules` | `rules` | One zone's `http_request_cache_settings` entry-point ruleset |
| `d1_database` | `workers` | One D1 database |
| `device_posture` | `device_posture` | Device posture rules and service provider integrations |
| `dns_records` | `dns` | One zone's DNS records |
| `gateway` | `gateway` | Gateway policies, account settings and the inspection root CA |
| `load_balancer` | `load_balancing` | One monitor, one pool and one load balancer |
| `logpush_job` | `logpush` | One Logpush job |
| `origin_rules` | `rules` | One zone's `http_request_origin` entry-point ruleset |
| `pages_project` | `pages` | One Pages project, its custom domains and their CNAMEs |
| `queue` | `workers` | One queue, and its consumer where the consuming Worker lives elsewhere |
| `queue_consumer` | `workers` | The consumer of one queue, when the same layer deploys the Worker |
| `r2_bucket` | `r2` | One R2 bucket with its CORS, lifecycle, lock, `r2.dev` and custom domain settings |
| `transform_rules` | `rules` | One zone's `http_request_late_transform` entry-point ruleset |
| `tunnel` | `tunnels` | Tunnels, their remote configuration, CNAMEs, virtual networks and routes |
| `turnstile` | `turnstile` | Turnstile widgets |
| `waf` | `waf` | One zone's custom, rate limiting and managed WAF entry points |
| `wan` | `wan` | Magic WAN GRE and IPsec tunnels and static routes |
| `worker_script` | `workers` | One Worker, its routes, custom domains and cron triggers |
| `workers_kv_namespace` | `workers` | One KV namespace, and optionally the pairs Terraform owns |
| `zerotrust` | `zerotrust` | The Zero Trust organisation, identity providers, service tokens, Access groups, policies and applications |
| `zone_base` | `zones` | One zone and its settings (and the legacy `dns_records` input) |
| `zone_rules` | `zones` | One zone's rate plan subscription and bot management |
| `_TEMPLATE` | - | The skeleton a new module is copied from |

Every module targets the `cloudflare/cloudflare` provider `~> 5.7`, except
`ai_gateway`, which needs `~> 5.20`. Every module requires Terraform
`>= 1.12.0` - see [Guardrails](#guardrails).

## Rules for use

### Calling a module

- **Pass real IDs, never logical keys.** A module takes `zone_id`, `account_id`,
  a queue's ID, a Worker's name - whatever Cloudflare calls the thing. Turning
  `zone_key = "primary"` into a zone ID is the calling layer's job, through
  `zone_lookup.tf` or a data source of its own.
- **One call per resource group.** A module manages one zone's records, one
  bucket, one gateway. To manage many, the layer calls it with `for_each` over a
  map keyed by a logical key. That key becomes part of every resource address,
  so renaming it destroys and recreates what it manages.
- **Configure the provider in the root.** Modules declare `required_providers`
  and nothing else. The calling root module - a layer, or an example - holds the
  `provider "cloudflare" {}` block and the credential that goes with it.
- **Source it by relative path.** Every layer's `module` block reads
  `source = "../../../modules/<name>"`. A module change therefore reaches the
  next plan of every layer that calls it, straight away - read that plan.
- **Read the variable descriptions.** They are the documentation: what an input
  does, what it accepts, and what Cloudflare does with it. They are written to
  be read from an editor's hover tooltip.

### Writing or changing a module

- **Keep it agnostic.** A module never takes a logical key, reads a layer's
  variable (`waf_trusted_ip_ranges` belongs to the `waf` layer, not the `waf`
  module), or holds a tenant value. Examples use RFC 5737 addresses, RFC 2606
  domains and placeholder IDs. If a module would not make sense to somebody who
  has never seen `deployment/`, something has leaked into it.
- **No provider blocks, no backends, no data sources.** A module that reads the
  API at plan time cannot be planned offline, which is how a module is tested
  on its own. Anything that needs a lookup is resolved by the layer and passed
  in as a value.
- **Key collections with `for_each` on a stable key**, not `count` over a list,
  so reordering an input never replaces anything. Use `count` only to switch a
  single optional resource on or off. Name the primary resource `this`.
- **Normalise inputs to what the API returns** - fully qualified names,
  upper-cased record types, Unicode rather than punycode domains - so the plan
  after the first apply is empty.
- **Put every guardrail where it can fire** - see [Guardrails](#guardrails) -
  and prove it does before review: see "Test your guardrails" in
  [CONTRIBUTING.md](../CONTRIBUTING.md).
- **Credentials are inputs, never defaults.** A secret reaches a module from the
  layer, which receives it as a `sensitive` `TF_VAR_` variable. A module never
  reads the environment or a file for one, never ships a default for one, and
  marks any secret it has to output `sensitive`.
- **Document every variable and output.** Each needs a type and a description;
  TFLint enforces both (`.tflint.hcl`, run with `tflint --recursive`).
- **Treat the variable schema as an interface.** Somebody's filled-in
  `.tfvars` depend on it, and the same schema is what lets a deployment move to
  CFLZ later. A change that makes existing input invalid, or changes resource
  addresses so that something is replaced, is a breaking change - say so, and
  give the migration.

## How a module works

### Anatomy

Copy [`_TEMPLATE/`](_TEMPLATE/) to start. Every module has the same files:

| File | Holds |
|---|---|
| `versions.tf` | `required_version` and `required_providers`. Nothing else. |
| `variables.tf` | The input schema: types, `optional()` defaults, descriptions, and every single-field `validation` block |
| `locals.tf` | Normalisation, and mapping the input schema onto provider-shaped values |
| `main.tf` | Resource declarations, plus a `lifecycle.precondition` for every cross-field rule |
| `outputs.tf` | IDs and attributes the calling layer, or another layer by hand-over, needs |
| `examples/basic/main.tf` | A root module that calls `source = "../.."` with literal placeholder inputs - how the module is planned on its own |

A large module may split `main.tf` by concern - `gateway` has `settings.tf` and
`certificate.tf` - but the division of labour stays the same.

### The life of an input

1. The layer builds the module's arguments: real IDs from its lookups, the
   config's values, and baseline defaults from its `defaults.auto.tfvars`
   filling whatever the config left unset.
2. `variables.tf` rejects anything malformed on its own - a bad enum, an
   out-of-range number, a missing required field - before Terraform builds a
   graph.
3. `locals.tf` normalises what is left and derives the maps the resources
   iterate over, keyed by something stable such as `TYPE/fqdn/content` for a DNS
   record.
4. The resources in `main.tf` check the cross-field rules in their
   `lifecycle.precondition` blocks, then declare what Cloudflare should hold.
5. `outputs.tf` returns the IDs. The layer re-exports what an operator needs
   to hand over or carry into another layer's config, such as `name_servers` or
   `origin_trust_bundles`.

### Guardrails

A module's guardrails live in two places, chosen by what the check needs to see:

| Check | Where | Why there |
|---|---|---|
| Decidable from one variable: types, enums, ranges, required fields | `validation` in `variables.tf` | Fails before a graph is built, and the message names exactly one input |
| Needs another variable, a local, or a comparison across items: duplicates, one field against another | `lifecycle.precondition` in `main.tf` | Every cross-field rule in one file |

The calling layer adds a third place, `preflight.tf`, for checks that span
variables the module never sees - a `zone_key` naming no zone, a guardrail
switch in `defaults.auto.tfvars`. A module does not know those switches exist.

Two Terraform behaviours shape how guards are written:

- **`||` and `&&` short-circuit only from Terraform 1.12.** A guard such as
  `x == null || contains(list, x)` evaluates both sides on anything older, and
  fails on the very null it was meant to skip. That is why every module requires
  `>= 1.12.0`. Where a guard must hold on an older version, write it as a
  conditional: `x == null ? true : contains(list, x)`.
- **A `for` expression that builds a map aborts on a duplicate key** with a
  generic `Duplicate object key` pointing into `locals.tf`. Group with `...`,
  take `[0]`, and report the duplicate through a precondition that names it -
  see `zone_base/locals.tf`.

### Ordering between resources

Terraform orders resources by their references, so a module never needs
`depends_on` when one resource reads another's ID. The one thing references
cannot express is ordering *across* a `for_each` module call: Terraform treats
`module.x[key]` as depending on everything inside that module. That is why
`queue_consumer` is its own module rather than part of `queue` - a consumer
inside `queue` that names a Worker, where the same layer deploys that Worker and
binds it to the queue, would leave the Worker waiting on itself.

### Testing a module

Every module ships `examples/basic/main.tf`: a root module with a
`provider "cloudflare" {}` block, a `module` block calling `source = "../.."`,
and every input a literal placeholder. Because it only ever creates, a plan of
it makes no API call, so it runs with a dummy token and no state:

```bash
cd modules/<module>/examples/basic
terraform init
CLOUDFLARE_API_TOKEN=offline-plan-no-api-calls terraform plan -refresh=false -lock=false
```

Keep it offline-plannable: no data sources, no variables without a value, and
at least one of each resource the module manages. Make a guardrail fire by
editing the example's inputs, and put them back afterwards. `init` leaves a
`.terraform/` directory and a lock file behind in the example; both are
gitignored or safe to delete. To test a module through the layer that calls it,
see "Checks before a pull request" in [CONTRIBUTING.md](../CONTRIBUTING.md).

## Adding a module

1. Copy `_TEMPLATE/` to `modules/<name>/`, using a snake_case name.
2. Fill in `variables.tf`, `locals.tf`, `main.tf` and `outputs.tf`, and the
   module block in `examples/basic/main.tf`. Change `versions.tf` only if the
   module needs a newer provider than `~> 5.7`, and say why in a comment.
3. Call it from a layer, with `for_each` over the layer's map and real IDs, and
   add sample values to `deployment/config/`.
4. Plan the example offline, and prove each new guardrail fails when it should.
5. Add a row to [the table above](#the-modules).

[CONTRIBUTING.md](../CONTRIBUTING.md) covers the rest of the change: the layer
side, the checks to run, and what a pull request needs to say.
