# Contributing

This document is about changing the Terraform. If you only want to deploy a
baseline for a customer, you want the [README](README.md) instead, and you
should not need to touch a `.tf` file at all.

## Where a change belongs

The Accelerator is [Cloudflare Landing Zones](https://github.com/itsharryshelton/CloudflareLandingZone)
with the pipeline, the remote state and the per-layer tokens removed. The
modules and the layers are the same Terraform in both.

| Change | Where |
|---|---|
| A customer's domains, policies, rules, origins | `deployment/config/`, in your own private copy. Not a contribution |
| Module logic, layer wiring, variable schemas, the WAF catalogue | Here - and say in the pull request whether it applies to CFLZ too, because it usually does |
| The wrapper and the post-apply scripts under `scripts/` | Here |
| Pipelines, remote state, token scoping, more than one account | CFLZ. They are out of scope here on purpose |

If a customer needs something the schema cannot express, add the input rather
than special-casing their copy. Keep the variable schemas compatible with CFLZ
where you can: the promise that the same `.tfvars` work in both is what lets a
customer move to full management later.

## Layout

```
modules/            agnostic building blocks, one Cloudflare concern each
deployment/
  layers/           root modules, one per product, each with its own local state
  config/           configuration for the one account being deployed
scripts/            cflz, which runs a layer, plus the post-apply scripts
```

Two rules hold the whole thing together.

Modules know nothing about this repository. They take flat arguments and real IDs,
never logical keys, and they never iterate over the estate. One module instance is
one resource group - one zone's records, one bucket, one tunnel - and any
`for_each` inside a module is over the members of that group only.

Layers own the estate shaped view. They hold every variable, iterate `for_each` over
maps keyed by a logical key, and turn `zone_key = "primary"` into a zone ID.

## Module conventions

Four files, always, plus `versions.tf`. Copy [modules/_TEMPLATE/](modules/_TEMPLATE/)
to start. [modules/README.md](modules/README.md) has the full set of rules every
module follows and the module-to-layer map; this section is the short form.

| File | Holds |
|---|---|
| `variables.tf` | The operator facing schema, and every single field guardrail as a `validation` block |
| `locals.tf` | Normalisation and mapping onto provider shaped values |
| `main.tf` | Resource declarations, plus `lifecycle.precondition` for cross field rules |
| `outputs.tf` | IDs and values other layers bind to |
| `examples/basic/main.tf` | A root module calling `source = "../.."` with placeholder inputs. It is how the module is planned on its own |

An example must stay offline-plannable: no data sources, every input a literal,
placeholders only. With no example, a module that has required inputs cannot be
planned on its own at all.

### Where a guardrail goes

Put a check in `variables.tf` if it can be decided from one variable. Types, enums,
ranges, required fields. It fails before Terraform builds a graph, and the message
points at exactly one input.

Put it in a `lifecycle.precondition` in `main.tf` if it needs another variable, a
local, or a comparison across list items.

Modules and layers both declare `required_version = ">= 1.12.0"`. That floor is
set by the modules: guards such as `x == null || contains(list, x)` rely on `||`
and `&&` short-circuiting, which Terraform only does from 1.12. Before 1.12 both
sides are evaluated, and the check fails on the very null it was meant to skip.
If a guard must hold on an older Terraform, write it as a conditional
(`x == null ? true : contains(list, x)`), which evaluates only the branch it takes.

A validation block has been able to reference another variable since 1.9, so that
is no longer a technical limit. Cross field checks in a module still go in a
`lifecycle.precondition`, so that every one of them is in `main.tf`. Cross
variable checks in a layer still live in `preflight.tf`, on a `terraform_data` resource, for
two reasons: a `module` block cannot carry a `lifecycle` block at all, and keeping
every cross cutting assertion in one file means a reader can see all of them
without opening four others. `terraform_data` needs no credentials and makes no API
calls.

So: single field checks go in `variables.tf` everywhere. Cross field checks go in
`main.tf` in a module, and `preflight.tf` in a layer.

### Duplicate object keys

A `for` expression that builds a map aborts on a duplicate key with Terraform's
generic `Duplicate object key`, pointing into `locals.tf`. It does not quietly keep
the last one. Group with `...`, take `[0]`, and report the collision through a
precondition so the operator gets a message naming the duplicate. See
`modules/zone_base/locals.tf`.

TFLint fails on unused locals under the `recommended` preset. A local that exists
only so variable validation could reference it will not survive, because validation
cannot reference locals anyway. Inline the list in the validation and leave a
comment saying why it is duplicated.

## Adding a module

1. Copy `modules/_TEMPLATE/` to `modules/<name>/`.
2. Fill in the four files and `examples/basic/main.tf`. Leave `versions.tf` alone,
   unless the module needs a newer provider than `~> 5.7` - as `ai_gateway` does -
   in which case say why in a comment there.
3. Document it in place. There are no per-module READMEs, on purpose: a separate
   document drifts from the code it describes, and
   [modules/README.md](modules/README.md) covers only what every module has in
   common. Add the new module to its table. Every variable carries a
   `description` saying what it does and what it accepts, TFLint enforces that,
   and the reasoning goes in the header comments of `locals.tf` and `main.tf`.
   Write those descriptions as though somebody will only ever read them from an
   editor's hover tooltip, because they will.
4. Call it from a layer with `source = "../../../modules/<name>"`, and add sample
   values to `deployment/config/`.
5. Run the [checks](#checks-before-a-pull-request).

Ask yourself whether the module would make sense to somebody who has never seen
`deployment/`. If it takes a `zone_key`, or reads a variable called
`waf_trusted_ip_ranges`, it has absorbed something that belongs in a layer.

## Adding a layer

1. `mkdir deployment/layers/<product>/`, named after the Cloudflare product.
   No numeric prefix.
2. Add `terraform.tf`, `providers.tf`, `variables.tf`, `locals.tf`,
   `<subject>.tf`, `outputs.tf`. `terraform.tf` declares no backend: state is
   local.
3. Keep `provider "cloudflare" {}` empty, so it reads whichever credential the
   environment holds, and list in `providers.tf` the permissions an API token
   would need for this layer. Somebody who cannot use a Global API Key will look
   there first.
4. If it binds to a zone, copy `zone_lookup.tf` and the `referenced_zones` local
   so it resolves keys by name instead of reading another layer's state. If it
   binds to something else Cloudflare identifies by an opaque per-account ID -
   roles, permission groups, resource groups - do the equivalent with a data
   source of its own, so a config file never carries a hex string. See
   `account_governance/permission_lookup.tf`.
5. Add `preflight.tf` for any new key reference.
6. Add `deployment/config/<product>.tfvars`. `scripts/cflz.sh layers` should then
   list it against the new layer with no other edit: the wrapper derives the
   mapping from which variables the layer declares.
7. If the product needs a credential of its own - a pre-shared key, an OAuth
   client secret - declare it as a `sensitive` variable with an empty default
   that no config file assigns, and document in
   [VARIABLES_AND_SECRETS.md](VARIABLES_AND_SECRETS.md) that it arrives as
   `TF_VAR_<name>`. See `origin_pull_certificates` in
   `layers/origin_pulls/variables.tf`.
8. Add the layer to [README.md](README.md) and [deployment/README.md](deployment/README.md),
   including any other layer that has to be applied before it.

## Configuration rules

One variable, one file. Nothing in `deployment/config/` may assign a variable that
another file there also assigns.

This is not tidiness. `-var-file` does not merge: if two files both define `zones`,
the last one silently wins in full. It is also what makes the wrapper work, since
`cflz` decides a file belongs to a layer when every variable it assigns is declared
by that layer. Break the rule and the mapping becomes ambiguous, and `cflz` refuses
to run the layer rather than guess.

Baselines live in `layers/<layer>/defaults.auto.tfvars`, auto loaded and
customer agnostic. Deployment values live in `deployment/config/` and win, because
they are passed later.

There is one account and one config directory. A second account is a second clone
of this repository, or a reason to use CFLZ.

## What may be committed

**To this repository: placeholder values only.** Use reserved ranges in anything
committed as an example: RFC 5737 for addresses (`192.0.2.0/24`,
`198.51.100.0/24`, `203.0.113.0/24`) and RFC 2606 for domains (`example.com`,
`example.net`, `example.org`).

In a private copy made for a project, account IDs and domain names may be
committed. They are configuration, not secrets, and this is acceptable only while
that copy stays private. **DO NOT COMMIT VARIABLE FILES WITH REAL DATA TO PUBLIC REPOS!**

Credentials are never committed, in any form, in any file. They reach Terraform
from the environment at run time: `CLOUDFLARE_API_KEY` and `CLOUDFLARE_EMAIL`, or
`CLOUDFLARE_API_TOKEN`, and the `TF_VAR_*` secrets.

`.gitignore` is default deny for `*.tfvars`, with explicit exceptions for
`layers/*/defaults.auto.tfvars` and `config/*.tfvars`. It then re-denies
`**/terraform.tfvars`, `**/local.auto.tfvars` and `**/*.local.tfvars` after those
exceptions, so no negation can reach them.

Terraform state and plan files are as sensitive as the credentials, and state now
sits in the working tree, next to the code. Both contain resolved zone IDs, DNS
record contents and complete WAF expressions, and some layers' state holds live
secrets. `.gitignore` excludes `*.tfstate*` and saved plans; check `git status`
before every commit all the same, and never use `git add -f` under
`deployment/layers/`.

[`.betterleaks.toml`](.betterleaks.toml) configures a secret scan with a rule for
Cloudflare token prefixes. Run it over your branch before pushing.

## Checks before a pull request

There is no CI in this repository, so the checks are yours to run. None of them
needs a real credential or touches an account.

| Check | Command | What it does |
|---|---|---|
| Format | `terraform fmt -check -recursive -diff` | Formatting, everywhere |
| Lint | `TFLINT_CONFIG_FILE="$PWD/.tflint.hcl" tflint --recursive` | The root `.tflint.hcl`, in every layer and module |
| Validate | `scripts/cflz.sh validate <layer>` | The layer and every module it calls. Runs `init` first if needed |
| Config mapping | `scripts/cflz.sh layers` | Every config file is claimed by the layers you expect, and none is split across two |
| Offline plan | `CLOUDFLARE_API_TOKEN=offline-plan-no-api-calls scripts/cflz.sh plan <layer> -refresh=false -lock=false` | A full plan of a layer that reads nothing from the API |

Seven layers can be planned offline, with a dummy token: `ai_gateway`,
`bulk_redirects`, `device_posture`, `lists`, `turnstile`, `wan` and `zones`. Every
other layer holds a `data "cloudflare_*"` block and so makes a real API read at
plan time: the layers that resolve a zone by name, `account_governance` resolving
role and permission group names, `zerotrust` reading the account's existing Zero
Trust organization, and `gateway` resolving Cloudflare's category and application
catalogues. Those are covered by `validate`, and by a plan against a real account
when you have one to test with.

Do those offline plans in a clone with no project state in it. A dummy
credential cannot change anything, but the result only means something against
an empty state, where every resource is a create.

`wan` is account-scoped, resolves nothing by name and holds no data source at
all, so every guardrail in it can be fired with a dummy token and no
stubbing. That makes it the easiest layer in the repository to test a check
against, and there is no excuse for an untested one.

A zone-reading layer looks up only the zones its config references - a bucket's
custom domain in `r2`, a zone-scoped job in `logpush`, a published hostname in
`tunnels` - so a config that references none makes no API call at all.

A layer that reads the API is still testable offline, and a new guardrail in one
should be proven before review. Copy the layer to a scratch directory, keeping the
modules at the same relative path. Delete the data source file, and replace each
`data.cloudflare_x.this` reference with a `local.stub_x` you write by hand. Take
the stub's shape from `terraform providers schema -json` rather than the registry
documentation, which flattens nesting modes. Plan it against the committed
`.tfvars` with a dummy `CLOUDFLARE_API_TOKEN`, and every precondition in
`preflight.tf` can then be made to fire on demand.

## Test your guardrails

A validation block nobody has seen fail is a validation block that might not work.
When you add one, prove it rejects what it claims to.

Put a deliberately bad value in `deployment/config/` and confirm the plan fails
with your message. This works directly for the seven offline-plannable layers.
For example, add an entry keyed `not_a_zone` to the `zone_config` map in
`deployment/config/zone_config.tfvars`, for a zone `zones.tfvars` does not
declare:

```hcl
not_a_zone = { ssl_mode = "strict" }
```

The plan should fail with `zone_config has entries with no matching zone in
var.zones: not_a_zone`. If it plans cleanly, your check is doing nothing. Take the
bad value out again before you commit, and paste the failing output into the pull
request description, so a reviewer does not have to take it on trust.

For guardrails on a layer that reads the API - `dns`, `waf`, `r2`, `gateway`,
`zerotrust` and the rest - the same trick works against a real test account, or
offline, with the stubbed data source described above. A proxied TXT record in
`dns.tfvars` is the classic one:

```hcl
{ name = "@", type = "TXT", content = "v=spf1 -all", ttl = 1, proxied = true },
```

It should fail with the message about only A, AAAA and CNAME being proxiable. A
zone-reading layer whose config references no zone reads nothing, so most of its
guardrails can be fired with a dummy token and no stubbing at all - `r2` with no
`custom_domains`, for instance. `wan` needs neither, since it reads nothing under
any configuration.

`gateway` is the layer the stubbing recipe was worth writing down for, because
its two data sources are plain lists. Replace
`data.cloudflare_zero_trust_gateway_categories_list.this.result` with a handful
of `{ id, name, subcategories }` objects and
`data.cloudflare_zero_trust_gateway_app_types_list.this.result` with a couple of
`{ id, name }`, and every precondition in it - including the ones in
`modules/gateway`, which see only resolved IDs - can be fired against the
committed config with a dummy token.

## Pull requests

Branch off `main`. Keep the change to one concern: a module fix, or a layer
addition, or a script change, not all three.

In the description, say what changed, which of the checks above you ran, and what
they printed. If the change alters a variable schema, say whether existing
`.tfvars` keep working, and whether the same change is needed in CFLZ.

### Reviewing

Has a module learned anything about layers, keys or accounts? That is the leak that
matters most, because it is the thing that stops a module being reusable.

Is each new guardrail somewhere it can actually fire, and does its message name the
input at fault? A check that reports `Invalid index` against a local has not really
been written.

Does a schema change break existing tfvars, and if so does the description say so?

Has anything credential shaped appeared in a committed file? A state file?

Has the change brought back something this repository deliberately left out - a
backend block, a second account, a token per layer, a workflow? That is a feature
of CFLZ, and belongs there.

Renaming a map key in the config is not a schema concern, but it is destructive.
Keys are resource identity, so renaming one destroys and recreates the resource.
For a zone that means losing every DNS record in it.

## Licensing your contribution

This project is Apache License 2.0. Anything you submit is taken as offered under the
same licence, which is what section 5 of the licence says by default, so there is no
separate agreement to sign.

Two things that follow from that. Do not paste code in from a source under an
incompatible licence, GPL in particular, because Apache-2.0 cannot absorb it. And if
you add a dependency, check its licence and add it to [NOTICE](NOTICE), which lists
what this repository relies on and under what terms.

There are no per file SPDX headers. The licence lives in `LICENSE` and applies to the
repository. If you would rather have headers, that is a reasonable change, but do it
in one pass across every file rather than adding them piecemeal.
