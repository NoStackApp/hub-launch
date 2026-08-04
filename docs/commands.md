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
| `hula info`    | —     | View plan info (logs, diff, initial, lessons, clientSessionId)    |
| `hula script <name>` | — | Run a bundled cross-platform workflow script (used by the Agent Skills) |
| `hula instructions <name>` | — | Print a bundled instruction doc (`planning`, `proceed`, `skill-creation`) |
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
hula init            # Interactive setup
hula init --force    # Overwrite existing config
```

The interactive setup prompts for all configuration, including (as the final
prompt) the environment variables to forward to tests. Enter a comma-separated
list of variable names (e.g. `TEST_USER_EMAIL,API_KEY`), or type `all` to forward
every non-reserved variable from your `.env`. Reserved system/internal names
(e.g. `PATH`, `HOME`) are rejected with a clear error so you can retry without
re-entering the other fields. Leaving the prompt empty clears the setting.
Existing values are shown as the prompt's initial value when re-running `hula init`.

---

## `hula login`

Authenticate with GitHub and (optionally) the hula-project server.

```bash
hula login                     # Authenticate with GitHub
hula login --url <server-url>  # Also link to a hula-project server
```

---

## `hula approve`

Merge a PR, delete the branch, and update tracking.

```bash
hula approve                   # Interactive
hula approve 123               # Merge PR for issue #123
hula approve 123 --no-delete   # Keep branch after merge
hula approve 123 --no-untrack  # Keep issue in tracking
```

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
An Anthropic OAuth token (`sk-ant-oat…`) is required — the sandbox needs it as
`CLAUDE_CODE_OAUTH_TOKEN` — and is resolved from `--anthropic-key`, `config.anthropicApiKey`,
or the `ANTHROPIC_API_KEY` env var (standard `sk-ant-api03-…` keys are not accepted; get a
token at https://claude.ai/settings, requires a paid Claude.ai plan). The target project is
resolved from `--project`, `config.hulaProject`, or the current git remote.

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
| `--anthropic-key <key>` | Optional | Anthropic OAuth token for Claude Code (ephemeral, `sk-ant-oat…`) |
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
| `--clientSessionId` | Claude Code session id that launched the plan                 |
| `--lines <n>`       | Trailing line count for `--lastLogs` (default: 100)           |
| `-r, --raw`         | For a single content key, print raw content to stdout         |
| `--url <url>`       | Hula server URL (overrides config)                            |
| `--api-key <key>`   | Hula API key (overrides config)                               |

Content keys (`--logs`, `--lastLogs`, `--diff`, `--initial`, `--lessons`) route
to `GET /api/v1/info/:planName`. `--clientSessionId` routes to the status
endpoint `GET /api/v1/ralph-run/:name/status`.

**Output rules** (let K = number of requested keys):

- **K == 1, content key** → the content is formatted, written to a temp file,
  and opened in your editor. With `--raw` the raw content is printed to stdout.
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
hula info my-feature --clientSessionId       # prints the launching session id (plain)
hula info my-feature --logs --diff           # prints a merged JSON object {logs, diff}
hula info my-feature --logs --clientSessionId# prints merged JSON across both endpoints
hula info my-feature --logs --raw            # prints the raw run log to stdout
```

---

## Related

- [Getting Started](getting-started.md) — install, configure, and create your first issue
