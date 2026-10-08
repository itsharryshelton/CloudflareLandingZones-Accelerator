# Variables & Secrets

Quick reference for every environment variable a run reads: what it is, which
layer needs it, and how to set it without leaving it behind. Everything here is
set in the shell that runs [`scripts/cflz`](scripts/cflz.sh), for that session.

Nothing here goes in a `.tf` or `.tfvars` file.

## At a glance

| # | What | Needed by | Required? |
|---|---|---|---|
| 1 | [The Cloudflare credential](#1-the-cloudflare-credential) | Every layer and every script | Yes - exactly one |
| 2 | [Layer secrets (`TF_VAR_*`)](#2-layer-secrets-tf_var_) | Six layers | Only for what the config declares |
| 3 | [Script and tuning variables](#3-script-and-tuning-variables) | The helper scripts | No |

The Cloudflare account ID is configuration, not a secret, and not an environment
variable. It goes in
[deployment/config/account.tfvars](deployment/config/account.tfvars) as
`cloudflare_account_id`, and every layer and script reads it from there.

---

## 1. The Cloudflare credential

One credential runs every layer. Set **one** of these, never both:

| Option | Variables | Where to get it |
|---|---|---|
| **Global API Key** (the default) | `CLOUDFLARE_API_KEY` and `CLOUDFLARE_EMAIL` | Dashboard → **My Profile → API Tokens → Global API Key → View**. `CLOUDFLARE_EMAIL` is that user's login address |
| A single API token | `CLOUDFLARE_API_TOKEN` | Dashboard → **My Profile → API Tokens → Create Token**, or an account-owned token under **Manage Account → API Tokens** |

`cflz` checks this before it calls Terraform, and stops if neither is set, if
both are, or if a value carries whitespace.

The Global API Key can do everything its user can, in every account they belong
to. It needs no scoping, which is why it is the default for a short project -
and why it deserves care. The [README](README.md#credentials) has the handling
rules; the short version is: a project user in the customer's account, the
current shell session only, rolled or removed when the project ends.

### Using an API token instead

Where a Global API Key is not acceptable, one token covers the same ground. Give
it the rows for the layers you intend to run, scoped to the one account and its
zones. Each layer's `providers.tf` carries the same list.

| Layer | Minimum scope |
|---|---|
| `account_governance` | `Account Settings:Edit` |
| `ai_gateway` | `AI Gateway:Edit` (the API names the same grant AI Gateway Write). Not `AI Gateway Run`. Can read and delete every gateway's logs - prompts and responses |
| `bulk_redirects` | `Account Filter Lists:Edit`, `Account Rulesets:Edit` |
| `device_posture` | `Zero Trust:Edit` |
| `dns` | `DNS:Edit`, `Zone:Read` |
| `gateway` | `Zero Trust:Edit` |
| `lists` | `Account Filter Lists:Edit` |
| `load_balancing` | `Account Load Balancers:Edit`, `Zone Load Balancers:Edit`, `Zone:Read` |
| `logpush` | `Logs:Edit` (account + zone), `Zone:Read`; `Zero Trust: PII Read` for Access/Gateway/DEX datasets |
| `origin_pulls` | `SSL and Certificates:Edit`, `Zone:Read` |
| `pages` | `Cloudflare Pages:Edit`; `Zone:Read` + `DNS:Edit` if a custom domain names a `zone_key` |
| `r2` | `Workers R2 Storage:Edit`; `Zone:Read` + `DNS:Edit` if a bucket has a custom domain |
| `rules` | `Cache Rules:Edit`, `Transform Rules:Edit`, `Origin Rules:Edit`, `Zone:Read` |
| `tunnels` | `Cloudflare Tunnel:Edit`; `Zone:Read` + `DNS:Edit` if an ingress rule names a `zone_key` |
| `turnstile` | `Turnstile:Edit` (the API names the same grant Turnstile Sites Write) |
| `waf` | `Zone WAF:Edit`, `Zone:Read` |
| `wan` | `Magic Transit:Edit` |
| `workers` | `Workers Scripts:Edit`, `Workers KV Storage:Edit`, `Zone:Read`; `D1:Edit` if databases are declared; `Queues:Edit` if queues are declared; `Workers Routes:Edit` if routes are declared; `DNS:Edit` for a custom domain |
| `zerotrust` | `Access: Organizations, Identity Providers, and Groups:Edit`, `Access: Apps and Policies:Edit`, `Access: Service Tokens:Edit` |
| `zones` | `Zone:Edit`, `DNS:Edit`, `Zone Settings:Edit`; `Bot Management:Edit` if bot management is configured; `Billing:Read` + `Billing:Write` if `manage_zone_subscriptions` is on |
| `scripts/resource-tags.sh` | Resource Tagging write at account scope, plus zone scope for zone tags. Beta permission groups, found by name - never `Access: Tags` |

---

## 2. Layer secrets (`TF_VAR_*`)

Six layers take a secret besides the Cloudflare credential. Each is a JSON
object keyed the same way as the matching map in that layer's `.tfvars`.
Terraform reads any environment variable named `TF_VAR_<variable>` as that
variable's value, so the name is the variable's name, in lower case.

Set them for both `cflz plan` and `cflz apply`: a plain `apply` plans again, and
needs the same inputs. (Applying a saved plan file, `cflz apply <layer> tfplan`,
is the exception - the plan already carries them.)

| Variable | Layer | Keyed like | Example value |
|---|---|---|---|
| `TF_VAR_identity_provider_secrets` | `zerotrust` | `identity_providers` | `{"entra_id":"<client secret>"}` |
| `TF_VAR_device_posture_integration_secrets` | `device_posture` | `device_posture_integrations` | `{"intune":{"client_secret":"<client secret>"}}` |
| `TF_VAR_logpush_destination_secrets` | `logpush` | `logpush_jobs` | `{"audit_archive":"r2://<bucket>/audit/{DATE}?account-id=<id>&access-key-id=<key id>&secret-access-key=<secret>"}` |
| `TF_VAR_logpush_ownership_challenges` | `logpush` | `logpush_jobs` | `{"primary_http_requests":"<challenge token>"}` |
| `TF_VAR_origin_pull_certificates` | `origin_pulls` | `certificate_key` references in `origin_pulls` | `{"api_origin":{"certificate":"-----BEGIN CERTIFICATE-----\n...","private_key":"-----BEGIN PRIVATE KEY-----\n..."}}` |
| `TF_VAR_pages_project_secrets` | `pages` | `pages_projects`, then environment | `{"admin_portal":{"production":{"SESSION_SECRET":"<value>"}}}` |
| `TF_VAR_wan_ipsec_tunnel_psks` | `wan` | `wan_ipsec_tunnels` | `{"london_primary":"<psk>","london_secondary":"<psk>"}` |
| `TF_VAR_wan_bgp_md5_keys` | `wan` | the `wan_gre_tunnels` / `wan_ipsec_tunnels` entries that set `bgp_customer_asn` | `{"<peering tunnel key>":"<md5 key>"}` |

Notes:

- **Only set what you use.** Every one defaults to empty, so a layer whose
  config declares no identity provider, integration or job needs no secret. The
  plan fails for a secret keyed to something that is not declared, and for
  something declared that needs a secret and has none.
- **Unset is not the same as empty.** A variable exported as an empty string
  reaches Terraform as invalid input and fails with `Missing expression`. Unset
  it, or set it to `{}`.
- **zerotrust:** every OAuth-type identity provider - `azureAD`, `oidc`, `okta`,
  `google` and similar - needs its secret here. SAML and the one-time PIN need
  none.
- **device_posture:** most integration types take `client_secret`; Uptycs takes
  `client_key` and `client_secret`; a custom integration takes
  `access_client_secret`.
- **origin_pulls:** only needed where a zone uploads a client certificate of
  its own; a zone running on the certificate Cloudflare presents by default
  needs nothing here. PEM is line-structured, so the newlines have to survive -
  build the value with `jq -n --rawfile cert x.crt --rawfile key x.key
  '{<certificate_key>: {certificate: $cert, private_key: $key}}'` rather than
  pasting. Both the certificate and its private key land in that layer's
  state in plain text, and the private key is an identity the origin has been
  told to trust.
- **pages:** only needed where a project lists `secret_names`. Keyed by project
  key, then `production` or `preview`, then variable name. The plan fails for a
  declared name with no value and for a value nobody declares. Never use a
  framework public prefix (`VITE_`, `NEXT_PUBLIC_`, ...) for a secret - the build
  inlines it into browser JavaScript, and the plan refuses it.
- **logpush:** a destination whose URI carries a credential (R2, Splunk HEC,
  Datadog, Azure SAS) goes in `TF_VAR_logpush_destination_secrets` and is left
  out of `logpush.tfvars`. One with no credential (S3, GCS) stays in
  `destination_conf`.
- **wan:** without a PSK each IPsec tunnel gets one Cloudflare generates,
  visible only in the dashboard. One PSK per tunnel, 32+ random characters (the
  plan refuses fewer than 16), never reused.
- **Every one lands in that layer's state file in plain text**, and in any
  saved plan. Scope each credential as narrowly as its provider allows, and see
  [State](README.md#state) for what to do with the file afterwards.

### Layers with nothing extra

`account_governance`, `ai_gateway`, `bulk_redirects`, `dns`, `gateway`, `lists`,
`load_balancing`, `r2`, `rules`, `tunnels`, `turnstile`, `waf`, `workers` and
`zones` need only the Cloudflare credential. So does `origin_pulls`, unless a
zone in it uploads a certificate of its own, and `pages`, unless a project lists
`secret_names`. Workers secrets live in Cloudflare Secrets Store and are
referenced by name in `workers.tfvars`.

---

## Setting a secret safely

Type or paste the value at a prompt, or read it from a file you then delete.
Avoid writing it on a command line: that puts it in your shell history, and a
stray newline or space makes Cloudflare reject the credential with 6003/6111.

```bash
# bash - prompts, and echoes nothing
read -rs CLOUDFLARE_API_KEY && export CLOUDFLARE_API_KEY
export CLOUDFLARE_EMAIL="you@example.com"

# JSON values: from a file, then delete the file
export TF_VAR_identity_provider_secrets="$(cat idp-secrets.json)" && rm idp-secrets.json

# PEM values: jq keeps the newlines intact
export TF_VAR_origin_pull_certificates="$(jq -n --rawfile cert x.crt --rawfile key x.key \
  '{api_origin: {certificate: $cert, private_key: $key}}')"
```

```powershell
# PowerShell 7.1+ - prompts, and echoes nothing
$env:CLOUDFLARE_API_KEY = Read-Host "Global API Key" -MaskInput
$env:CLOUDFLARE_EMAIL = "you@example.com"

# JSON values: -Raw keeps the file as one string
$env:TF_VAR_identity_provider_secrets = Get-Content idp-secrets.json -Raw
Remove-Item idp-secrets.json
```

On Windows PowerShell 5.1, which has no `-MaskInput`, use
`[System.Net.NetworkCredential]::new('', (Read-Host 'Global API Key' -AsSecureString)).Password`.

Environment variables set this way last until the shell closes. To clear one
sooner: `unset NAME` in bash, `Remove-Item Env:NAME` in PowerShell.

---

## 3. Script and tuning variables

Optional. None is a secret.

| Variable | Read by | What it does |
|---|---|---|
| `CLOUDFLARE_ACCOUNT_ID` | `resource-tags.sh`, `d1-migrations.sh`, `kv-bulk-load.sh` | Overrides the account ID the scripts otherwise read from `deployment/config/account.tfvars` |
| `DRY_RUN` | `resource-tags.sh`, `d1-migrations.sh` | `1` = report what would change and change nothing |
| `CLOUDFLARE_BASE_URL` | Terraform's Cloudflare provider | Points the provider at [`cf-api-throttle.py`](scripts/cf-api-throttle.py) - see [API rate limiting](deployment/README.md#api-rate-limiting) |
| `CLOUDFLARE_API_BASE_URL` | wrangler, in `d1-migrations.sh` and `kv-bulk-load.sh` | The same, for the scripts that call wrangler |
| `REQUEST_INTERVAL` | `resource-tags.sh` | Seconds between API calls. Default `0.3` |
| `CF_THROTTLE_RPS`, `CF_THROTTLE_PORT` | `cf-api-throttle.py` | Defaults for its `--rps` and `--port` |

---

## When a run says something is missing

| Message | Fix |
|---|---|
| `ERROR: no Cloudflare credential in the environment` | Set `CLOUDFLARE_API_KEY` and `CLOUDFLARE_EMAIL`, or `CLOUDFLARE_API_TOKEN` ([section 1](#1-the-cloudflare-credential)) |
| `ERROR: both CLOUDFLARE_API_TOKEN and CLOUDFLARE_API_KEY/CLOUDFLARE_EMAIL are set` | Unset whichever you are not using |
| `ERROR: the Global API Key needs both CLOUDFLARE_API_KEY and CLOUDFLARE_EMAIL` | Set the missing half |
| `ERROR: ... contains whitespace or a line ending` | Set the value again, copied with the dashboard's own copy button |
| `Unknown X-Auth-Key or X-Auth-Email` (9103), or `Authentication error` (10000) | The key and email do not belong together, the key has been rolled, or the user has no access to the account in `account.tfvars` |
| `Invalid request headers` (6003) / `Invalid format for Authorization header` (6111) | A truncated or malformed credential - set it again |
| `Missing expression` on `<value for var.identity_provider_secrets>` (or another secret) | The `TF_VAR_` variable is set but empty. Unset it, or set it to `{}` |
| A plan fails naming a missing secret, or a secret with no matching entry | Set, or correct the keys of, the `TF_VAR_` variable ([section 2](#2-layer-secrets-tf_var_)) |
| `429` / `Please wait and consider throttling your request speed` | The run exceeded 1,200 requests in five minutes - see [API rate limiting](deployment/README.md#api-rate-limiting) |
| `Error acquiring the state lock` | An earlier run of that layer was killed mid-way. Check nothing is still running, then `scripts/cflz.sh force-unlock <layer> <lock ID from the error>` |
