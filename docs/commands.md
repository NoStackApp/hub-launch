# Commands Reference

Complete reference for every hula CLI command.

## Quick Reference

| Command        | Alias | Description                                                       |
| -------------- | ----- | ----------------------------------------------------------------- |
| `hula`         | `hl`  | Main CLI entry point                                              |
| `hula login`   | —     | Authenticate with GitHub + hula-project                           |
| `hula init`    | —     | Initialize configuration                                          |
| `hula create`  | —     | Create issue from plan file                                       |
| `hula merge`   | —     | Merge PR and clean up                                             |
| `hula launch`  | —     | Trigger a launch job on hula-project server                       |
| `hula execute` | —     | Trigger or schedule an execute-action (e.g. `--built-in harden`) |
| `hula logs`    | —     | View logs by request ID                                           |

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

## `hula merge`

Merge a PR, delete the branch, and update tracking.

```bash
hula merge                   # Interactive
hula merge 123               # Merge PR for issue #123
hula merge 123 --no-delete   # Keep branch after merge
hula merge 123 --no-untrack  # Keep issue in tracking
```

After a successful merge, your local `main` at the project root is automatically
fast-forwarded to match `origin/main` (skipped safely if it can't fast-forward —
e.g. diverged local commits, uncommitted changes, or the root not on `main`).
This works even when `hula merge` runs from inside a worktree.

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

Selected options:

| Flag | Description |
| --- | --- |
| `--resume <step>` | Re-run from this pipeline step (1–9), skipping earlier steps |
| `--fix <instructions>` | Pass fix instructions to the AI agent (requires `--resume`) |
| `--update-notification-url <url>` | Webhook URL POSTed by the server on every terminal task transition. Falls back to the `updateNotificationUrl` config field, then `HULA_UPDATE_NOTIFICATION_URL` env var. |

Run `hula launch --help` for the full option list.

---

## `hula execute`

Trigger or schedule an `execute-action` on the hula-project server. Used for built-in
actions like `harden` (security audit) or custom action files.

```bash
# One-off built-in run
hula execute --built-in harden --entry-point src/ --outcome-type feedback

# Custom action file
hula execute --action-path security/extra-checks.md --outcome-type pr

# Recurring schedule (cron)
hula execute --built-in harden --entry-point src/ --outcome-type pr --schedule "0 3 * * *"

# Inspect a run
hula execute --show <runId>

# List recent runs / schedules
hula execute --list
hula execute --list-schedules

# Manage schedules
hula execute --cancel-schedule <scheduleId>
hula execute --run-now <scheduleId>

# Skill-authoring helpers (primarily used by the /hula-execute skill)
hula execute --publish-skill .hublaunch/skills/2026-06-19-16:35-remove-unreachable-code.md
hula execute --delete-skill .hublaunch/skills/2026-06-19-16:35-remove-unreachable-code.md
```

> **Tip**: the `/hula-execute` agent skill drives this command from plain language
> (e.g. `/hula-execute harden src/ every night and open a PR`). It extracts the
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
> - **Manage** → `/hula-execute list`, `show <id>`, `run now <id>`,
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
token at https://claude.ai/settings, requires a paid Claude.ai plan). The Daytona API key is
required and resolved from `--daytona-key`, `config.daytonaApiKey`, or the `DAYTONA_API_KEY`
env var. The target project is resolved from `--project`, `config.hulaProject`, or the current
git remote.

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
| `--daytona-key <key>` | Optional | Daytona API key (required by hula-server) |
| `--project <owner/repo>` | Optional | Override the target repository |
| `--publish-skill <path>` | Optional | Commit a `.hublaunch/skills/` action file to `origin/main` via worktree (used by the `/hula-execute` skill) |
| `--delete-skill <path>` | Optional | Remove a `.hublaunch/skills/` action file from `origin/main` via worktree (used by the `/hula-execute` skill) |

Provide exactly one of `--built-in` / `--action-path`. Cron examples:
`"0 3 * * *"` (every day at 3 AM), `"0 * * * *"` (every hour),
`"0 9 * * 1"` (every Monday at 9 AM), `"0 8 * * 1-5"` (every weekday at 8 AM).

Run `hula execute --help` for the full option list.

---

## `hula logs`

View logs by request ID. Alias: `hula g`.

```bash
hula logs <requestId>
```

---

## Related

- [Getting Started](getting-started.md) — install, configure, and create your first issue
