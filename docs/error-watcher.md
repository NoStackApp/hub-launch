# Error Watchers

An **Error Watcher** is an inbound webhook. Your production application reports an
error to HubLaunch; HubLaunch deduplicates it and — when the error is new and your
account has capacity — automatically launches a fix (a PR, a plan, or a feedback
run). The `hula error-watcher` command creates and manages those watchers, and,
crucially, prints the exact signed-request snippet your application must send.

> **Requires a hula-server with Error Watcher support.** Against an older server,
> the management routes return a clear "this server may not support Error Watchers
> yet" message rather than a raw error.

---

## Two pieces, two owners

This is the thing to get straight before anything else. Reporting an error needs
**both** of the following, and they are created in different places:

| Piece | What it holds | Where it comes from |
| --- | --- | --- |
| **Error Watcher** | Configuration: dedupe window, environment allow-list, PR policy, `instructions`, `errorEnvVars`, `secrets` | `hula error-watcher --create`, or the dashboard |
| **Project ingest key** | The credential your app presents: `hik_…` plus its own signing secret `his_…` | Dashboard only — **Projects → gear icon → Error reporting API keys** |

```
your app ──POST /api/v1/webhooks/error──▶  ingest
           X-Hula-Api-Key: hik_…              │ authenticates on the KEY
           X-Hula-Signature: HMAC(his_…)      │ resolves config from the WATCHER
                                              ▼
                                    dedupe → fix run → PR
```

The key is scoped to the **project**, not to a watcher and not to a person, so
each reporting service can hold its own key and be revoked or rotated on its own.
Key CRUD is exposed over tRPC for the dashboard and has **no REST route**, so the
CLI cannot mint, rotate, or read one — it only tells you where to.

A valid key whose project has no enabled watcher is answered with **`409`**, not a
silent accept. See [Troubleshooting](#other-symptoms).

---

## Why this command exists

Setting a watcher up by hand means crafting an authenticated `POST` and — the real
blocker — working out the HMAC signing payload your app must send on every report.
Get the signature wrong and the server returns a bare `401` with no diagnostic
detail (deliberately: the endpoint must not be a signing oracle).

This command hands you a correct, copy-paste snippet, so that entire class of
failure disappears.

---

## Usage

```bash
hula error-watcher <mode> [tuning flags] [overrides]
```

Exactly **one** mode flag per invocation. Passing two fails with a clear message
and issues no request. Passing none prints help.

| Mode                     | Action                                                            |
| ------------------------ | ---------------------------------------------------------------- |
| `--create`               | Create a watcher, then print the setup steps, `.env`, and snippet |
| `--list`                 | Table of the project's watchers                                  |
| `--show <watcherId>`     | One watcher's full configuration                                 |
| `--events [watcherId]`   | Recent error events with status/skipReason (all watchers if no id) |
| `--update <watcherId>`   | Patch tuning fields                                             |
| `--delete <watcherId>`   | Soft-delete (interactive confirm unless `--yes`)               |
| `--print-setup [watcherId]` | Re-print `.env` + snippet with placeholders (no secrets)     |

There is deliberately **no `--rotate`**. The only signing secret that matters
belongs to the project ingest key, and that lives on the dashboard settings page.
A CLI mode that rotated the watcher's vestigial secret would look like it worked
and change nothing.

`--events` with no id lists the project's watchers and queries each one, then
merges the results newest-first (`--limit` caps the merged list). There is no
project-wide events endpoint to call directly.

### Tuning flags (`--create` / `--update`)

| Flag                        | Description                                                     | Bounds / default |
| --------------------------- | ------------------------------------------------------------- | ---------------- |
| `--name <name>`             | Watcher label, e.g. `api-prod`                                | default `default` |
| `--dedupe-window <seconds>` | How long the same error is deduplicated                       | 300–604800, default 86400 |
| `--max-fixes-per-day <n>`   | Max fix launches per UTC day                                  | ≥ 1, default 5   |
| `--environments <list>`     | Comma-separated environments allowed to launch fixes          | default `production` |
| `--outcome-type <type>`     | `pr` \| `plan` \| `feedback`                                  | default `pr`     |
| `--pr-policy <policy>`      | `always` \| `skip-if-open` \| `close-previous`                | default `skip-if-open` |
| `--enabled <bool>`          | Enable or disable the watcher                                 | `true` \| `false` |
| `--instructions <text>`     | Trusted guidance for the fix agent                            | ≤ 4000 chars     |
| `--clear-instructions`      | Remove the stored instructions                                | `--update` only  |
| `--error-env <KEY=VALUE>`   | Env var injected into the fix sandbox; repeatable             | ≤ 50 entries     |
| `--clear-error-env`         | Remove all `errorEnvVars`                                     | `--update` only  |
| `--secret <value>`          | Extra literal to redact from every payload; repeatable        | 6–512 chars, ≤ 50 |
| `--clear-secrets`           | Remove all extra redaction secrets                            | `--update` only  |

Create-only (the update endpoint ignores them, so `--update` **rejects** them
rather than reporting a success that changed nothing):

| Flag                     | Description                | Bounds |
| ------------------------ | -------------------------- | ------ |
| `--container-cpu <n>`    | vCPU for fix sandboxes     | 1–32   |
| `--container-memory <n>` | GiB RAM for fix sandboxes  | 1–128  |
| `--container-disk <n>`   | GiB disk for fix sandboxes | 5–200  |
| `--update-notification-url <url>` | Webhook for fix-run notifications | — |
| `--update-notification-name-tag <tag>` | "Initiated by" label | — |

Client-side validation rejects out-of-range values **before** any network call.
The server validates independently and remains the authoritative boundary.

### The three agent-facing fields

- **`--instructions`** — free-text guidance rendered into the fix agent's brief.
  Unlike the error report (which arrives from a crashing process and is treated
  strictly as untrusted data), this is set by you through the authenticated API,
  which is exactly why the agent is told it may follow it.
- **`--error-env`** — environment variables injected into the fix sandbox so the
  agent can reproduce the failure and pull logs. May hold API keys; encrypted at
  rest. **Separate from the launch path's `envVars`/`extraEnv`** — the two never
  mix, so a log-retrieval key scoped to error diagnosis never reaches an ordinary
  launch. Platform-reserved names (`HULA_*`, `RALPH_*`, `GITHUB_TOKEN`, …) are
  rejected client-side.
- **`--secret`** — extra literal values scrubbed from every payload for this
  watcher, on top of the built-in patterns. For credential shapes the built-in
  matcher cannot know about.

All three are settable **only** through `--create` / `--update` — never from a
webhook body, which anyone who can trigger an error in your app can influence.

`errorEnvVars` and `secrets` are encrypted at rest and **never returned** by any
read endpoint, so `--show` cannot display them. Each `--update` **replaces** the
stored value wholesale: pass the complete set you want, not a delta.

### Filters (`--list` / `--events`)

| Flag                | Description                          |
| ------------------- | ------------------------------------ |
| `--status <status>` | Filter `--events` by status          |
| `--limit <n>`       | Max rows (default 20)                |

### Standard overrides (identical to `hula schedule`)

| Flag                    | Description                                        |
| ----------------------- | -------------------------------------------------- |
| `--provider <type>`     | LLM provider: `claude` \| `openai` \| `openrouter` |
| `--provider-key <key>`  | Provider credential (required on `--create`)       |
| `--project <owner/repo>` | Override the target repository                    |
| `--url <url>`           | Override the hula-project server URL               |
| `--api-key <key>`       | Override the hula API key                          |
| `--yes`                 | Skip the confirmation prompt on `--delete`         |
| `--json`                | Emit raw server JSON for read modes                |

Credentials resolve **flags → `.hublaunch/hublaunch.config.js` → environment**,
exactly like `hula schedule`. Run `hula login` first so your GitHub token is
attached automatically on `--create`.

---

## Setup output

`--create` (and `--print-setup`) prints three steps, in this order:

1. **Create a project ingest key.** Open `<server>/dashboard/projects`, click the
   gear icon on the project card, and create a key under **Error reporting API
   keys**. The `hik_…` key and its `his_…` secret are shown **exactly once**.

   The CLI prints no credential of its own — it has no route to mint one.

2. The **`.env` block** for your production environment:

   ```bash
   # HubLaunch Error Watcher — add to your production environment
   HULA_ERROR_WEBHOOK_URL=https://www.hublaunch.site/api/v1/webhooks/error
   HULA_INGEST_KEY=hik_…
   HULA_INGEST_SECRET=his_…
   ```

   The URL defaults to `<server>/api/v1/webhooks/error`; override it with
   `errorWebhookUrl` in your config for a self-hosted webhook host.

3. The **signed-request snippet** — hard-coded in the CLI (so `--print-setup`
   works even with the server unreachable). It signs the exact payload the server
   verifies:

   ```js
   const timestamp = Math.floor(Date.now() / 1000).toString();
   const signature = createHmac('sha256', process.env.HULA_INGEST_SECRET)
     .update(`${timestamp}.${body}`)   // NOTE: timestamp + "." + body
     .digest('hex');
   ```

   and sends three headers: `X-Hula-Api-Key`, `X-Hula-Timestamp`, and
   `X-Hula-Signature: sha256=<hex>`.

### Three things to get right in your app

- **Send at least one identity field** — see [dedupe](#what-counts-as-the-same-error)
  below. This is the single easiest thing to get wrong.
- **Do not log credentials.** The server best-effort redacts common secret shapes
  from `stack`/`logs` on arrival, but the real fix is not printing them. Register
  the shapes it cannot know about with `--secret`. The dashboard shows a redaction
  count when it catches something.
- **Set `release`** to your deployed commit SHA. With it, the fix agent branches
  from the code that actually crashed; without it, it works against your default
  branch. It is accepted only as a 7–40 char hex SHA and otherwise dropped.

---

## What counts as "the same error"

The dedupe fingerprint is built from the **identity fields** you send — `key`,
`errorName`, `errorCode` — and **only** from those. The message and stack trace do
not contribute: they vary between occurrences of one bug (ids, timestamps, line
numbers), so keying on them would re-fingerprint an ongoing bug as "new" after
every deploy.

Two events collapse into one fix when every identity field they carry matches:

| You send | Fingerprint | Effect |
| --- | --- | --- |
| `key` + `errorName` (+ `errorCode`) | `id:k=…\|n=…\|c=…` | Same key, different name → fixed separately |
| `key` only | `id:k=…` | Everything under that key is one error |
| `errorName` / `errorCode`, no `key` | `id:n=…\|c=…` | Built from whatever is present |
| **none of the three** | `all:<watcherId>` | **One fix per watcher per window** |

That last row is the trap. With nothing to tell two errors apart, HubLaunch will
not guess: every keyless event lands in a single bucket, so at most one fix run
starts per dedupe window no matter how many distinct bugs you report. **Send at
least a `key` if you want distinct errors fixed distinctly.** The printed snippet
sends all three by default.

Within a watcher's `--dedupe-window`, repeat reports of the same fingerprint
increment `occurrenceCount` on the existing event instead of launching another
fix. A second layer, `--pr-policy skip-if-open`, additionally suppresses a new PR
while a prior fix PR is still open, even after the window expires.

---

## Security

- **The CLI never handles the ingest credential.** It cannot create, read, or
  rotate a `hik_`/`his_` pair — those exist only on the dashboard settings page
  and in your own deployment's secret store.
- **Never persisted by the CLI.** Nothing credential-shaped is written to
  `hublaunch.config.js`, any cache, or any other on-disk location.
  `hublaunch.config.js` is commonly committed, and a leaked ingest secret lets
  anyone forge error reports that trigger real, credit-consuming fix runs.
- **Write-only fields stay write-only.** `--secret` and `--error-env` values are
  sent to the server and never echoed back into CLI output, not even in the
  success summary — only the entry count is printed.
- **No secrets in error output.** No key, secret, or `Authorization` header
  appears in any error path.
- **Snippet correctness is a security property.** The snippet must sign
  `` `${timestamp}.${body}` `` exactly. Signing the body alone (dropping the
  timestamp prefix) removes replay protection — the CLI's tests pin the signing
  algorithm to a fixture.

---

## Troubleshooting by `ErrorEvent.status`

`hula error-watcher --events` shows each event's disposition. Use this table to
answer "why was there no PR?".

| Status                | Meaning / what to do                                                        |
| --------------------- | --------------------------------------------------------------------------- |
| `pending`             | Received; the fix run has not started yet.                                   |
| `launched`            | A fix run started — `actionRunId` links to it.                              |
| `deduped`             | Same fingerprint within the dedupe window; `occurrenceCount` was incremented. |
| `skipped_environment` | The report's `environment` is not in the watcher's allow-list. Add it with `--environments`. |
| `skipped_budget`      | The `--max-fixes-per-day` cap was already hit for this UTC day. Raise it or wait. |
| `skipped_credits`     | The account is out of PR credits. Buy more (Pro with credits is required).    |
| `skipped_open_pr`     | An open fix PR already exists and `--pr-policy` is `skip-if-open`.            |
| `failed`              | The fix run failed to launch or errored — inspect the linked run.            |

### Other symptoms

| Symptom                                   | Cause / fix                                                          |
| ----------------------------------------- | ------------------------------------------------------------------- |
| App gets **`409` — "no enabled error watcher is configured for this project"** | Your key is valid; the project has no enabled watcher to apply. `hula error-watcher --create`, or `--list` then `--update <id> --enabled true`. Also check the key and the watcher belong to the **same** project. |
| App gets `401` on every report            | Wrong header (`X-Hula-Api-Key`, not `X-Hula-Watcher`), wrong signing payload (must be `` `${timestamp}.${body}` ``), a revoked key, or a timestamp outside the 5-minute skew window. Re-copy the snippet from `--print-setup`. |
| App gets `401` after rotating a key secret | The old secret is still deployed past the 24-hour grace window. Deploy the new secret everywhere before the printed expiry. |
| App gets `413`                            | Body over 128 KB. Trim `logs`/`context`.                             |
| App gets `429`                            | Rate limited per key (600/min). Sample or batch your reporting.       |
| Every distinct error produces one shared fix | No `key`/`errorName`/`errorCode` sent, so all events share the `all:<watcherId>` bucket. Send identity fields. |
| `--create` fails asking for a provider    | A fix run needs an LLM credential. Pass `--provider-key` (or set `provider.apiKey` / `PROVIDER_AUTH_TOKEN`). |
| `--update` rejects `--container-*`        | Expected — those are create-only; the update endpoint ignores them.   |
| Management route returns "not supported"  | The server predates Error Watchers. Upgrade hula-server.            |

---

## Related

- [Commands Reference](commands.md)
- [Getting Started](getting-started.md)
