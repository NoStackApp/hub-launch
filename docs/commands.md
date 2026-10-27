# Commands Reference

Complete reference for every hula CLI command.

## Quick Reference

| Command        | Alias | Description                                                       |
| -------------- | ----- | ----------------------------------------------------------------- |
| `hula`         | `hl`  | Main CLI entry point                                              |
| `hula login`   | —     | Authenticate with GitHub + hula-project                           |
| `hula init`    | —     | Initialize configuration                                          |
| `hula create`  | —     | Create issue from plan file                                       |
| `hula approve` | —     | Merge PR and clean up                                             |
| `hula launch`  | —     | Trigger a launch job on hula-project server                       |
| `hula schedule` | —     | Trigger or schedule an execute-action (e.g. `--built-in harden`) |
| `hula error-watcher` | — | Manage production Error Watchers (inbound error webhooks that auto-launch fix PRs) |
| `hula info`    | —     | View plan info (logs, diff, initial, lessons, verify, clientSessionId) |
| `hula view`    | —     | List tracked plans with status, priority, PR, and merge confidence |
| `hula archive` | —     | Archive a plan (close its issue, keep the record); `--unarchive` to reverse |
| `hula update`  | —     | Upgrade hub-launch to the latest release (or `--check` / `--auto on\|off`) |
| `hula credentials sync` | — | Save the current credentials to HubLaunch as the `default` set (web + phone planning) |
| `hula credentials list` | — | List the credential sets stored on HubLaunch (hints only) |
| `hula init web` | — | Enable web + phone planning and sync now (`hula init web disable` turns it off) |
| `hula plan <subcommand>` | — | Remote-planning command group (used by `/hula-plan` and `/hula-followup`) |
| `hula script <name>` | — | Run a bundled cross-platform workflow script (used by the Agent Skills) |
| `hula instructions <name>` | — | Print a bundled instruction doc (`planning`, `proceed`, `skill-creation`, `assess`, `plan-initiate`, `plan-generate`) |
| `hula session-hook` | — | Claude Code PreToolUse hook that captures launch-session provenance |

## Global Options

```bash
hula --version        # print version
hula --help           # show all commands
hula <cmd> --help     # show options for a specific command
```

---

## `hula create`

Create a GitHub issue from a plan file with Copilot assigned.

```bash
hula create                  # Interactive: pick plan, assign team
hula create username         # Assign to a specific user
hula create --plan file.md   # Use a specific plan file
hula create --no-copilot     # Skip Copilot assignment
hula create --no-track       # Don't add to tracking
```

---

## `hula init`

Initialize hula configuration.

```bash
hula init                # Interactive setup (also logs you in if needed)
hula init --force        # Overwrite existing config
hula init --skip-login   # Configure without the automatic login flow
hula init web            # Enable web + phone planning and sync credentials now
hula init web disable    # Disable it and delete the stored credential set
```

The interactive setup prompts for all configuration, including (as the final
prompt) the environment variables to forward to tests. Enter a comma-separated
list of variable names (e.g. `TEST_USER_EMAIL,API_KEY`), or type `all` to forward
every non-reserved variable from your `.env`. Reserved system/internal names
(e.g. `PATH`, `HOME`) are rejected with a clear error so you can retry without
re-entering the other fields. Leaving the prompt empty clears the setting.
Existing values are shown as the prompt's initial value when re-running `hula init`.

`hula init` first asks which LLM provider you use — Claude, OpenAI, or
OpenRouter — then prompts for that provider's credential. The credential prompt
is optional; press Enter to skip it. If you skip it, `hula init` prints a
reminder, and `hula launch` will ask for the credential interactively the first
time you need it.

**Web and phone planning (`saveCredentials`):** once you are logged in, `hula
init` and `hula login` ask once (default **yes**) whether to enable planning
from the HubLaunch dashboard and your phone. Enabling it stores your GitHub
token, provider key and forwarded env vars permanently (encrypted) on HubLaunch
as the project's `default` credential set, refreshed on every launch — normally
those secrets are kept only while a launched plan is in flight. Change the
answer any time with **`hula init web`** (enable + sync immediately) or **`hula
init web disable`** (disable, and after a confirmation delete the stored set
from HubLaunch). Pass `--yes` to skip the confirmations. See
[`hula credentials`](#hula-credentials).

**Automatic login:** when `hula init` finishes and you are not yet authenticated
(no HubLaunch API key, or no saved GitHub token), it flows straight into the
login flow — the same GitHub Device Flow + HubLaunch key exchange as
`hula login` — so a single command completes onboarding. If login is cancelled
or fails, init still exits successfully and points you to `hula login`. Pass
`--skip-login` to configure without authenticating; when unauthenticated, it
prints a `Run 'hula login' to authenticate.` hint instead. When you are already
authenticated, no browser opens.

---

## `hula login`

Authenticate with GitHub and (optionally) the hula-project server.

```bash
hula login                     # Authenticate with GitHub
hula login --url <server-url>  # Also link to a hula-project server
hula login --fresh             # Always open the browser to sign in again
```

When a valid GitHub login is already stored on the machine (e.g. after logging
into another project), `hula login` reuses it and skips the browser entirely —
printing `🔑 Using your saved GitHub login`. Pass `--fresh` to force the
browser device flow, for example to switch GitHub accounts. If the saved login
is no longer valid or has expired, login falls back to the browser flow
automatically.

When the project has `saveCredentials: true` and a provider key is configured,
a successful login also saves the project's `default` credential set to
HubLaunch immediately, so web and phone planning work without waiting for the
first launch. See [Planning from the web or your phone](../README.md#planning-from-the-web-or-your-phone).

---

## `hula approve`

Merge a PR, delete the branch, and update tracking.

```bash
hula approve                   # Interactive
hula approve 123               # Merge PR for issue #123
hula approve 123 --no-delete   # Keep branch after merge
hula approve 123 --no-remove   # Keep issue in tracking
hula approve 123 --force       # Merge even when confidence is below threshold
```

**Merge-confidence gate.** Before merging, `hula approve` fetches the PR's
stored merge assessment and gates on it (see
[Merge policy](advanced.md#merge-policy)). When the verdict is `ready`, it
merges straight away. Otherwise it prints the confidence, threshold, verdict,
concerns, and recommended end-user test steps, then:

- in an interactive terminal, asks `Merge anyway? (y/n)` (default `n`);
- in a non-interactive context, exits with **code 3** and a message telling you
  to re-run with `--force`.

`--force` skips the prompt / overrides the gate. A repo with no HubLaunch server
configured skips the gate entirely.

After a successful merge, your local `main` at the project root is automatically
fast-forwarded to match `origin/main` (skipped safely if it can't fast-forward —
e.g. diverged local commits, uncommitted changes, or the root not on `main`).
This works even when `hula approve` runs from inside a worktree.

---

## `hula launch`

Trigger a launch job on the hula-project server. The server runs an AI coding agent (Claude Code) through a fixed pipeline — see the [Getting Started guide](getting-started.md) for details.

```bash
hula launch <issueName> <planPath>
hula launch --show <name>     # Show job status
hula launch --logs <name>     # Show job logs
```

**Resume from a specific step after a failure:**

```bash
hula launch my-issue .hublaunch/plans/my-plan.md --resume 4
hula launch my-issue .hublaunch/plans/my-plan.md --resume 7 --fix "address build warning in src/utils/shell.ts"
```

> **Note**: `--fix` requires `--resume` and passes instructions to the AI agent for that stage.

**LLM provider credential:** the launch needs a provider (`claude` (default),
`openai`, or `openrouter`) and its credential. The provider type is resolved
from `--provider <type>`, then `config.provider.type`, then the default
`claude`; the credential from `--provider-key <key>`, then
`config.provider.apiKey`, then `PROVIDER_AUTH_TOKEN`. If none is set and you're
in an interactive terminal, `hula launch` prompts you to paste the credential
once, validates its format for the selected provider, saves it to
`.hublaunch/hublaunch.config.js` (mode `0600`), and continues the launch —
press Enter at the prompt to cancel. In a non-interactive context (piped stdin,
CI) it fails fast with instructions instead. (The old `--anthropic-key` flag,
`anthropicApiKey` config key, and `ANTHROPIC_API_KEY` env fallback have been
removed.)

**Stop or replace an in-flight task:**

```bash
# Kill the in-flight task for a tracking name and launch a fresh one
hula launch feature-auth .hublaunch/plans/2026-07-07-feature-auth.md --kill-and-relaunch

# Just stop the in-flight task (no plan path needed)
hula launch feature-auth --kill
```

`--kill` needs only the branch name — it sends no credentials and does not upload a plan. When nothing is running it prints "No active task to cancel…" and exits 0 (a no-op is a success). If a task is already running and you launch **without** a kill flag, an interactive terminal shows recovery options (kill-and-relaunch / kill / resume / cancel); a non-interactive run (skill/wrapper, CI) prints the server message and exits non-zero.

> **Note**: `--kill` and `--kill-and-relaunch` are mutually exclusive, and `--kill` cannot be combined with launch-only flags (`--resume`, `--fix`, `--test`, `--handoff`, `--regression`).

Selected options:

| Flag | Description |
| --- | --- |
| `--resume <step>` | Re-run from this pipeline step (1–9), skipping earlier steps |
| `--fix <instructions>` | Pass fix instructions to the AI agent (requires `--resume`) |
| `--provider <type>` | LLM provider: `claude` \| `openai` \| `openrouter` (default: config or `claude`) |
| `--provider-key <key>` | Provider credential (ephemeral; never stored server-side beyond the run) |
| `--kill` | Stop the in-flight task for this tracking name without relaunching. Needs only the branch name (no plan path); sends no credentials. |
| `--kill-and-relaunch` | Cancel the in-flight task, reset stale state, and launch a fresh task. Requires a plan path, like a normal launch. |
| `--test` | Run in test mode: the server runs the full production pipeline but swaps the real Claude CLI for a mock (fast E2E run). **A real GitHub PR is still created** — clean it up afterward. Requires Pro tier and valid credentials, exactly like a normal launch. |
| `--update-notification-url <url>` | Webhook URL POSTed by the server on every terminal task transition. Falls back to the `updateNotificationUrl` config field, then `HULA_UPDATE_NOTIFICATION_URL` env var. |
| `--update-notification-name-tag <tag>` | Verbatim "initiated by" label in notifications; Slack mention markup (`<@U12345>`, `<!subteam^ID>`) pings. Falls back to `updateNotificationNameTag` config field, then `HULA_UPDATE_NOTIFICATION_NAME_TAG` env var. |

Run `hula launch --help` for the full option list.

---

## `hula schedule`

Trigger or schedule an `execute-action` on the hula-project server. Used for built-in
actions like `harden` (security audit) or custom action files.

```bash
# One-off built-in run
hula schedule --built-in harden --entry-point src/ --outcome-type feedback

# Custom action file
hula schedule --action-path security/extra-checks.md --outcome-type pr

# Recurring schedule (cron)
hula schedule --built-in harden --entry-point src/ --outcome-type pr --schedule "0 3 * * *"

# Inspect a run
hula schedule --show <runId>

# List recent runs / schedules
hula schedule --list
hula schedule --list-schedules

# Manage schedules
hula schedule --cancel-schedule <scheduleId>
hula schedule --run-now <scheduleId>

# Skill-authoring helpers (primarily used by the /hula-schedule skill)
hula schedule --publish-skill .hublaunch/skills/2026-06-19-16:35-remove-unreachable-code.md
hula schedule --delete-skill .hublaunch/skills/2026-06-19-16:35-remove-unreachable-code.md
```

> **Tip**: the `/hula-schedule` agent skill drives this command from plain language
> (e.g. `/hula-schedule harden src/ every night and open a PR`). It extracts the
> action, entry point, and outcome type, translates schedule phrasing into a cron
> expression, and echoes the resolved cron for confirmation before running.
>
> The skill now also **authors actions from a description** and performs **all
> management** conversationally:
>
> - **Describe an action** (no path/built-in) → the skill asks clarifying
>   questions, confirms a name, writes a free-form action file to
>   `.hublaunch/skills/<YYYY-MM-DD-HH:MM-slug>.md`, commits and pushes it to
>   `origin/main` via a temporary worktree **before** running, then runs or
>   schedules it with `--action-path`.
> - **Manage** → `/hula-schedule list`, `show <id>`, `run now <id>`,
>   `cancel <id>` (offers to delete the related action file, guarded so it
>   refuses when another active schedule still references it), and
>   `update <id> …` (either edit + re-publish the action file, or cancel +
>   recreate the schedule with a new cron on the same action).
>
> The `--publish-skill <path>` / `--delete-skill <path>` flags below back the
> skill's authoring/cleanup steps: they commit or remove a `.hublaunch/skills/`
> action file on `origin/main` through a temporary worktree (never touching your
> current branch). Both reject paths outside `.hublaunch/skills/` and path
> traversal. You normally invoke them through the skill rather than directly.

Either `--built-in <name>` or `--action-path <path>` is required (mutually exclusive).
An LLM provider credential is required. Select the provider (`claude` (default),
`openai`, or `openrouter`) from `--provider`, then `config.provider.type`; and the
credential from `--provider-key`, then `config.provider.apiKey`, then the
`PROVIDER_AUTH_TOKEN` env var — which must match the provider selected in config.
For `claude`, both subscription OAuth tokens (`sk-ant-oat…`) and API keys
(`sk-ant-api…`) are accepted. The target project is resolved from `--project`,
`config.hulaProject`, or the current git remote.

The server URL defaults to `https://www.hublaunch.site` (override with `--url` or the
`HULA_PROJECT_URL` env var). Run `hula login` first so your GitHub token is attached to the
request automatically (the server requires it); alternatively set the `GITHUB_TOKEN` env var.
`--outcome-type` defaults to `pr` when omitted.

Selected options:

| Flag | Required? | Description |
| --- | --- | --- |
| `--built-in <name>` | Required (one of) | Built-in action name (e.g. `harden`) |
| `--action-path <path>` | Required (one of) | Repo-relative path or `https://` URL to a custom action file |
| `--entry-point <path>` | Optional | Entry point for the action (file, directory, or URL) |
| `--outcome-type <type>` | Optional | `pr`, `plan`, or `feedback` (defaults to `pr` when omitted) |
| `--schedule <cron>` | Optional | Cron expression — creates a recurring schedule instead of a one-off run |
| `--provider <type>` | Optional | LLM provider: `claude` \| `openai` \| `openrouter` (default: config or `claude`) |
| `--provider-key <key>` | Optional | Provider credential (ephemeral; never stored server-side beyond the run) |
| `--project <owner/repo>` | Optional | Override the target repository |
| `--update-notification-name-tag <tag>` | Optional | Verbatim "initiated by" label in notifications; Slack mention markup (`<@U12345>`, `<!subteam^ID>`) pings. Falls back to `updateNotificationNameTag` config field, then `HULA_UPDATE_NOTIFICATION_NAME_TAG` env var. |
| `--publish-skill <path>` | Optional | Commit a `.hublaunch/skills/` action file to `origin/main` via worktree (used by the `/hula-schedule` skill) |
| `--delete-skill <path>` | Optional | Remove a `.hublaunch/skills/` action file from `origin/main` via worktree (used by the `/hula-schedule` skill) |

Provide exactly one of `--built-in` / `--action-path`. Cron examples:
`"0 3 * * *"` (every day at 3 AM), `"0 * * * *"` (every hour),
`"0 9 * * 1"` (every Monday at 9 AM), `"0 8 * * 1-5"` (every weekday at 8 AM).

Run `hula schedule --help` for the full option list.

---

## `hula info`

Surface facts about a tracked plan. Each flag adds a requested key.

```bash
hula info <trackingName> [flags]
```

| Flag                | Description                                                    |
| ------------------- | ------------------------------------------------------------- |
| `--logs`            | Full stored run log                                           |
| `--lastLogs`        | Last N lines of live output (uses `--lines`)                  |
| `--diff`            | PR unified diff (fetched server-side from GitHub)             |
| `--initial`         | Initial PR body / AI summary                                  |
| `--lessons`         | Lessons-learned content                                       |
| `--verify`          | Merge assessment (confidence, verdict, categories, steps)     |
| `--clientSessionId` | Claude Code session id that launched the plan                 |
| `--lines <n>`       | Trailing line count for `--lastLogs` (default: 100)           |
| `-r, --raw`         | For a single content key, print raw content to stdout         |
| `--url <url>`       | Hula server URL (overrides config)                            |
| `--api-key <key>`   | Hula API key (overrides config)                               |

Content keys (`--logs`, `--lastLogs`, `--diff`, `--initial`, `--lessons`,
`--verify`) route to `GET /api/v1/info/:planName`. `--clientSessionId` routes to
the status endpoint `GET /api/v1/ralph-run/:name/status`.

**Output rules** (let K = number of requested keys):

- **K == 1, content key** → the content is formatted, written to a temp file,
  and opened in your editor. With `--raw` the raw content is printed to stdout.
- **K == 1, `--verify`** → the merge assessment is pretty-printed to stdout
  (header, category scores, concerns, end-user steps, then the full JSON). It is
  never opened in an editor. `--raw` prints a single compact JSON line. When the
  server has no assessment, prints `No merge assessment available for <name>.`
- **K == 1, `--clientSessionId`** → the session id (or `null`) is printed plain.
- **K >= 2** → the requested keys are merged into one JSON object on stdout.
- **K == 0** → error (exit 1). Pass at least one flag.

`--diff` and `--initial` can be `null` when no PR exists yet or the server's live
GitHub read soft-failed; the client handles this without crashing.

### Examples

```bash
hula info my-feature --logs                 # opens the full run log in the editor
hula info my-feature --lastLogs --lines 50   # opens the last 50 lines of live output
hula info my-feature --diff                  # opens the PR diff
hula info my-feature --initial               # opens the PR body / AI summary
hula info my-feature --lessons               # opens lessons-learned content
hula info my-feature --verify                # prints the merge assessment to stdout
hula info my-feature --verify --raw          # prints the assessment as one JSON line
hula info my-feature --clientSessionId       # prints the launching session id (plain)
hula info my-feature --logs --diff           # prints a merged JSON object {logs, diff}
hula info my-feature --logs --clientSessionId# prints merged JSON across both endpoints
hula info my-feature --logs --raw            # prints the raw run log to stdout
```

---

## `hula view`

List tracked plans with their status, priority, PR, plan file, and — when the
server provides it — their merge confidence.

```bash
hula view                      # all tracked plans
hula view --status waiting     # filter by tracking status
hula view --priority High      # filter by priority
```

| Flag                  | Description            |
| --------------------- | ---------------------- |
| `--status <status>`   | Filter by tracking status |
| `--priority <level>`  | Filter by priority     |

Each plan prints its name, `Status`/`Priority`, any assignees, `PR`, and a
`Confidence` line when the server supplied a merge assessment:

- `Confidence: 87 · review` when a numeric confidence is available;
- `Confidence: — (unavailable)` when the verdict is `unavailable`;
- nothing (the line is omitted) on servers that don't produce an assessment.

See [Merge policy](advanced.md#merge-policy) for how the score is computed and
used.

---

## `hula update`

Upgrade the installed `hub-launch` CLI to the latest published release.

```bash
hula update                      # detect pnpm/npm, install @latest, refresh commands
hula update --manager pnpm       # force the package manager
hula update --check              # report only (exit 0 up to date, 2 available)
hula update --auto on            # enable automatic updates (or: off)
```

| Flag                   | Description                                                            |
| ---------------------- | --------------------------------------------------------------------- |
| `--manager <pnpm\|npm>` | Force the package manager instead of auto-detecting it                |
| `--check`              | Only report whether a newer version exists; don't install (exit 0/2)  |
| `--auto <on\|off>`      | Turn automatic updates on or off (stored in `~/.hublaunch/settings.json`) |

**What it does.** The package manager is detected from how the global binary was
installed (a pnpm path or `PNPM_HOME` → pnpm, otherwise npm). The install always
runs from your home directory, so a repo pinning a specific `packageManager`
(e.g. `pnpm@9`) can't redirect the global bin dir. After installing, it makes
sure the global Claude Code slash commands were refreshed — pnpm ≥ 10 blocks a
package's postinstall until you approve builds, so `hula update` runs that step
directly and, under pnpm, reminds you to `pnpm approve-builds -g` (select
`hub-launch`) so future updates refresh the commands on their own. It finishes by
printing the newly installed version.

A standalone (curl-installed) binary updates itself instead: it downloads the
matching binary from the latest stable release of
[NoStackApp/hub-launch](https://github.com/NoStackApp/hub-launch/releases),
verifies it against that release's `SHA256SUMS`, atomically replaces itself, and
refreshes the global Claude Code slash commands (the same step as
`hula install-claude-commands`). `--manager` forces the package-manager path.

**Exit codes:** `0` success / up to date, `1` the install command failed, `2`
`--check` found an available update.

**The daily notice.** Any normal (interactive) command prints a one-line
`⬆️  hub-launch <latest> is available …` notice at the end when a newer version
is on npm, checked at most once per 24 h and cached in
`~/.hublaunch/update-check.json`. It's suppressed on non-TTY output and on the
`script` / `instructions` / `plan` / `session-hook` fast paths so machine-parsed
output is never touched. Set `HULA_NO_UPDATE_CHECK=1` to disable it (e.g. in CI).

**Automatic updates.** `hula login` and `hula init` ask once whether to keep the
CLI current; `hula update --auto on|off` sets it without the prompt. When on, the
upgrade runs **after** the current command completes (never during it) and
reports what it did; the original command's exit code is preserved.

---

## `hula credentials`

Manage the credential set this project stores on HubLaunch for **web and phone
planning**. When `saveCredentials: true` (see [configuration](../README.md#configuration)),
every `hula launch` and `hula plan start|draft-and-launch` already refreshes the
`default` set after it succeeds; these commands let you push or inspect it
explicitly. Secret values are never printed — only hints (e.g. `ghp_…k3Q9`).

```bash
hula credentials sync [--name <set>] [--project <owner/repo>] [--url <url>] [--api-key <key>]
hula credentials list [--project <owner/repo>] [--url <url>] [--api-key <key>]
```

- **`sync`** resolves the same bundle a launch sends — the GitHub token (always
  re-read from `gh auth token`, so a rotated token is refreshed), the provider
  key, the forwarded env vars, and the update-notification settings
  (`updateNotificationUrl` / `updateNotificationNameTag`, when set) — and upserts
  it as the `default` set (or the `--name` you pass). It runs regardless of
  `saveCredentials`. Exit code is `0` on success and `1` when nothing was saved
  (not logged in, no GitHub token, no provider credential, or the server does not
  support credential sets).

  The success line names the stored env vars (names only, never values), e.g.
  `🔐 Credentials saved to HubLaunch as "default" (GitHub ghp_…k3Q9) · 2 env vars: NEON_API_KEY, NEON_PROJECT_ID`
  (up to 8, then `, +N more`), or `· no env vars` when none were forwarded.

  A sync **replaces** the stored set: env vars are forwarded only when their
  names are listed in `envVars` (or `envVars: "all"`) in
  `.hublaunch/hublaunch.config.js`, so a sync that sends none **clears** any
  previously stored env vars. `sync` warns in that case:
  - when `envVars` is unset, that dashboard and phone launches only see
    forwarded variables (and, if a `beforeLaunch` hook is configured, that the
    sandbox hook only sees those variables — list the ones it reads);
  - when `envVars` is set but nothing was found in `.env`;
  - which previously stored env vars this sync removed.
- **`list`** prints a hint-only table: set name, GitHub hint, providers, env-var
  count, the notification URL (`NOTIFY URL`) and name tag (`NOTIFY TAG`) — shown
  verbatim, or `—` when unset — source, and last-synced date.

`--url` / `--api-key` follow the same precedence as `hula info`.

To enable or disable the feature, use `hula init web` / `hula init web disable`
(see [`hula init`](#hula-init)).

---

## `hula error-watcher`

Manage production **Error Watchers** — inbound error webhooks that deduplicate
reported errors and auto-launch a fix. Thin REST client over
`/api/v1/error-watchers`; one mode flag per invocation. Full reference:
[Error Watchers](error-watcher.md).

```bash
hula error-watcher --create --name api-prod
hula error-watcher --events
hula error-watcher --update <id> --instructions "Never touch billing/"
hula error-watcher --print-setup
```

| Flag                     | Description                                                       |
| ------------------------ | ---------------------------------------------------------------- |
| `--create`               | Create a watcher; print the setup steps, `.env`, and snippet      |
| `--list`                 | List the project's watchers                                       |
| `--show <id>`            | Show one watcher's configuration                                 |
| `--events [id]`          | Recent error events with status/skipReason (all watchers if no id) |
| `--update <id>`          | Patch tuning fields (only supplied fields are sent)              |
| `--delete <id>`          | Soft-delete (interactive confirm unless `--yes`)                |
| `--print-setup [id]`     | Re-print `.env` + snippet with placeholders (offline-safe)      |
| `--json`                 | Emit raw server JSON for read modes                              |

Watcher tuning also covers the three agent-facing fields: `--instructions`
(trusted guidance for the fix agent), `--error-env KEY=VALUE` (env vars for the
fix sandbox), and `--secret <literal>` (extra redaction values). Each is
repeatable where it makes sense and **replaces** the stored value wholesale; the
matching `--clear-*` flags remove it.

The watcher holds configuration only. The credential your app presents is a
separate **project ingest key** (`hik_…` + `his_…`), created in the dashboard
under **Projects → gear icon → Error reporting API keys** — there is no REST
route for it, so the CLI points you there rather than minting one (and therefore
has no `--rotate`). Credentials resolve flags → `.hublaunch/hublaunch.config.js`
→ env, exactly like `hula schedule`, and are never written to any file.

---

## `hula script <name>`

Runs a bundled, cross-platform Node workflow script (no `bash`/`jq` needed). These
are invoked by the `/hula-*` Agent Skills, not usually typed by hand; each prints a
single JSON object on stdout and logs to stderr. The name is resolved against a
fixed allow-list — arbitrary paths are rejected.

Backlog scripts (the per-chat, dashboard-synced backlog):

| Script | What it does |
| ------ | ------------ |
| `backlog-init -- <key>` | Create the per-chat backlog file if absent (idempotent) |
| `backlog-add -- <key> "<text>" [--project <o>/<r> --tracking-name <n>\|--issue <N>]` | Append an item; best-effort push to the dashboard |
| `backlog-resync -- <key> --project <o>/<r> (--tracking-name <n>\|--issue <N>)` | Retry the push for any unsynced items |
| `backlog-pull -- <key> --project <o>/<r> (--tracking-name <n>\|--issue <N>)` | Two-way sync: push unsynced, merge the dashboard's items by `remoteId`, push back local `done` |
| `backlog-list -- [<key>] [--project <o>/<r> (--tracking-name <n>\|--issue <N>)] [--all]` | Print the backlog as JSON — from the local file, the server, or both merged; `--all` includes done items |

`backlog-list` works with a key alone (local file), a plan target alone (the
server's items — e.g. from another machine), or both (pull then list). See
[Advanced Usage → Backlogs](advanced.md#backlogs) for the file format and sync rules.

---

## `hula plan`

The remote-planning command group. Every subcommand prints exactly one JSON
object on stdout (logs go to stderr) so the `/hula-plan` and `/hula-followup`
skills can parse one shape. You rarely run these by hand — the skills do.

```bash
hula plan start --name <trackingName> (--prompt <text> | --prompt-file <path>) \
  [--issue <n>] [--folder <sub>] [--local | --remote] [--test] [--handoff <user>]
hula plan wait <planId> [--interval <seconds>=20] [--max-minutes <n>=120] [--force]
hula plan followup <planId>
hula plan answer <planId> --file <json> [--local]
hula plan understanding <planId> --file <markdown> [--local]
hula plan context <planId> --file <markdown> [--assessment-file <md>] [--questions <json>] [--local]
hula plan plan-text <planId> --file <planPath> [--local]
hula plan draft-and-launch <planId> [--test] [--handoff <user>]
```

- **`start`** records a planning run. Mode is `--local` / `--remote`, or auto:
  remote under Claude Code (`CLAUDECODE=1`), local everywhere else. Remote mode
  needs `hulaApiKey` + `hulaProjectUrl`; local mode records best-effort and
  degrades silently with no server config.
- **`wait`** polls the stage endpoint every 20 s (min 10) up to 2 h and exits on
  a stage change, a failed/cancelled task, a timeout, or 5 consecutive network
  failures. It refuses to run outside Claude Code unless `--force`.
- **`followup`** fetches the full record; **`answer`** / **`understanding`** /
  **`context`** / **`plan-text`** persist each planning artifact; and
  **`draft-and-launch`** hands the confirmed plan to the server to draft and
  launch automatically.
- When `--file` is in the plan-initiate layout (H2 `Assessment` … `Questions`),
  **`context`** splits it itself: the Assessment body becomes `assessment`, the
  fenced json in `## Questions` becomes `questions`, and the rest is sent as
  `context`; `--assessment-file` / `--questions` override the parsed values.
- **`--local`** (on `context` / `answer` / `understanding` / `plan-text`) sends
  the write as a local-chat write: it carries `expectPlanMode: local` so the
  server rejects it once the plan was continued on HubLaunch (the dashboard or
  `/hula-followup`), and `answer`/`understanding`/`plan-text` first read the plan
  back — failing if it was continued on HubLaunch, refusing to overwrite an
  answer already given on the dashboard, and reporting any `dashboardAnswers` in
  their JSON. `/hula-followup` does **not** pass `--local` (its writes are
  allowed in both modes).

All subcommands accept `--url <serverUrl>` and `--api-key <key>` overrides with
the same precedence as `hula info`. See [Advanced Usage](advanced.md) for the
full remote-planning flow.

---

## `hula archive`

Archive a plan — a **soft close that keeps the plan record**. The server moves
the plan to the `archived` lifecycle stage and closes its GitHub issue, but the
plan is retained (it appears in the Archive view rather than being untracked).
The action is reversible with `--unarchive`.

```bash
hula archive [issueNumber]              # archive (prompts for the number if omitted)
hula archive 123                        # archive plan for issue #123
hula archive 123 --unarchive            # return plan #123 to its active stage
```

| Flag          | Description                                                        |
| ------------- | ----------------------------------------------------------------- |
| `--unarchive` | Un-archive instead (plan returns to its derived active stage)     |

**`archive` vs. `close`.** `close` closes the GitHub issue **and removes the plan
from tracking** (destructive). `archive` closes the issue but **retains** the plan
record so you can still see it in the Archive view and un-archive it later. They
are separate commands; `close`'s behavior is unchanged.

Archiving an already-closed/deleted GitHub issue still marks the plan `archived`
and keeps the record. Against an older server that does not support archiving, the
command reports a clear "server does not support archiving" error.

### Lifecycle stages

Every plan has a single **lifecycle stage** — one ordered axis from creation to
retirement:

```
analyzing → backlog → QUESTIONS → UNDERSTOOD → GENERATE_PLAN → LAUNCHED
          → initialWaiting → waiting → ready → failed
          → backlogBlocked → failedMerge → completed → archived
```

- **`analyzing`** — a planning job is in flight.
- **`backlog`** — created, not yet advanced past initiation.
- **`QUESTIONS … LAUNCHED`** — the planning stages.
- **`initialWaiting … ready`** — the post-launch tracking statuses.
- **`failed`** — the planning job or the tracked run failed.
- **`backlogBlocked`** (📌 open backlog) — the PR is merged but backlog items are
  still open. Stays in the active list until they are done.
- **`failedMerge`** (🚨 deploy failed) — the PR is merged, no backlog is open, but
  the recorded deployment failed. Stays in the active list.
- **`completed`** — auto-derived: the plan's PR is merged, no backlog item is
  open, and the deployment succeeded **or** the project records no deployments
  at all. A plan with no PR is never auto-completed; a merged plan whose deploy
  is still pending stays `ready`.
- **`archived`** — set by `hula archive` (terminal, retained).

The active plan list is sorted earliest-stage-first, with priority as the
within-stage tiebreaker. `completed` and `archived` plans are hidden from the
active list and shown in the Archive view (`hula view --archived`, or the
interactive Archive toggle), which also includes plans whose issue is closed.

The canonical stage and the `completed` derivation live on the hula-server; the
CLI falls back to deriving a best-effort stage from the local tracking status when
talking to an older server.

---

## Related

- [Getting Started](getting-started.md) — install, configure, and create your first issue
- [Error Watchers](error-watcher.md) — full Error Watcher command reference and troubleshooting
