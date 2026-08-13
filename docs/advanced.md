# Advanced Usage

Everything here is optional — the core loop (`/hula-plan` → `/hula-approve`)
never requires it. This page collects the deeper controls for power users, moved
out of the README to keep the front page simple.

## The full workflow, spelled out

The primary use case is AI-assisted issue development via the hula-project server:

```bash
# 1. Plan the feature
#    Validation runs automatically in the same session after the plan is saved.
#    When validation finishes, the assistant offers to launch right away with a
#    default issue name derived from the plan (reply "yes" to launch, or decline
#    and run /hula-launch <name> yourself later).
#    Add --autoLaunch (optionally with --test / --handoff <username>) to skip the
#    post-validation confirmation and launch immediately.
/hula-plan Add password reset support

# 2. Upload the plan to origin/main
#    (Optional — /hula-launch runs this automatically if skipped)
#    The upload auto-retries (fetch + rebase, up to 3 attempts) if origin/main
#    advances mid-push; a genuine conflict fails fast with a clear message.
/hula-upload

# 3. Launch — creates the issue and starts the AI coding session
#    Includes /hula-upload automatically, so step 2 can be omitted
/hula-launch password-reset-support

# 4. (AI coding agent works on the issue, creates a PR automatically)

# 5. Apply any fixes needed on the PR branch
/hula-fix the email validation is rejecting valid addresses

# 6. Verify all acceptance criteria are met
/hula-verify

# 7. Merge and clean up
#    Equivalent to merging the PR manually on GitHub
/hula-approve
```

> 💡 `/hula-confirm` remains available as a standalone command for re-validating a plan you've edited by hand.

Or directly via CLI:

```bash
hula launch password-reset-support .hublaunch/plans/2026-05-07-17:00-password-reset.md
```

## Upgrading

```bash
npm install -g hub-launch@latest   # or: pnpm add -g hub-launch
```

re-run `hula init` inside each project to refresh the bundled Agent Skills and
config scaffolding (workflow scripts and instruction docs now ship with the
package, so they update automatically with the CLI):

```bash
cd <your-project>
hula init   # safe to re-run; preserves your keys and team settings
```

The CLI reminds you automatically when a project was initialized with a
different version than the one currently installed.

## `hula launch` and Resume

`hula launch` submits a job to the hula-project server, which runs an AI coding agent (Claude Code) through a fixed 9-step pipeline:

| Step | Description                                                                   |
| ---- | ----------------------------------------------------------------------------- |
| 1    | Change to worktree directory (worktree is created before the pipeline starts) |
| 2    | Bug review & fix loop (LLM-based review with iterative fixes)                 |
| 3    | Commit remaining changes                                                      |
| 4    | TypeScript / lint check (`pnpm check`)                                        |
| 5    | Production build (`pnpm build`)                                               |
| 6    | Regression tests                                                              |
| 7    | Push branch to origin                                                         |
| 8    | Merge latest main                                                             |
| 9    | Cleanup & create PR                                                           |

> 💡 After a PR is merged, `hula approve` automatically fast-forwards your **local**
> `main` at the project root to match `origin/main` — no manual `git pull` needed.
> It is non-destructive (fast-forward only) and works even when run from inside a
> worktree; it is skipped safely if local `main` can't fast-forward. When it is
> skipped, `/hula-approve` reports the specific reason and the exact command to fix it.

### Troubleshooting `/hula-approve`

**Q: My local `main` wasn't updated after the merge.**

The fast-forward is best-effort and is skipped (never failing the merge) when:

- **Uncommitted changes** at the project root — commit or stash them first:
  `git commit -am 'wip'` or `git stash`.
- **On a different branch** — the project root isn't checked out on the default
  branch. Switch to it: `git checkout main`.
- **Non-standard git config** — the project root worktree couldn't be located.
  Inspect with `git worktree list`.
- **`git pull --ff-only` couldn't fast-forward** (e.g. diverged history or a
  network issue). Run it manually: `git pull --ff-only origin main`.

`/hula-approve` prints the specific reason and remediation in its output, and its
summary shows ⚠️ when the local update was skipped.

### Resuming from a specific step

Use `--resume <step>` to re-run from a specific step after a failure, without re-doing earlier steps:

```bash
# Resume from step 4 (skips setup, bug review, and commit)
hula launch my-issue .hublaunch/plans/my-plan.md --resume 4

# Resume from step 7 with fix instructions
hula launch my-issue .hublaunch/plans/my-plan.md --resume 7 --fix "address build warning in src/utils/shell.ts"
```

> **Note**: `--fix` requires `--resume` and passes instructions to the AI agent for that stage.

### Test mode

Use `--test` for a fast end-to-end run: the server runs the full production
pipeline but swaps the real Claude CLI for a mock, so it finishes in milliseconds
without consuming Anthropic credits. **A real GitHub PR is still created**, so
clean it up afterward.

```bash
hula launch my-branch .hublaunch/plans/my-plan.md --test
```

### Stopping or replacing an in-flight task

Use `--kill-and-relaunch` to cancel the task currently running for a tracking
name and immediately launch a fresh one (stale state is reset server-side):

```bash
hula launch feature-auth .hublaunch/plans/2026-07-07-feature-auth.md --kill-and-relaunch
```

Use `--kill` to just stop the in-flight task without relaunching. It needs
**only the branch name** — no plan path, and it sends no credentials:

```bash
hula launch feature-auth --kill
```

When there is nothing to cancel, `--kill` prints "No active task to cancel…" and
exits 0 (a no-op is a success). `--kill` and `--kill-and-relaunch` are mutually
exclusive, and `--kill` cannot be combined with launch-only flags (`--resume`,
`--fix`, `--test`, `--handoff`, `--regression`).

If you run a normal `hula launch` while a task is already running for that
tracking name, the behavior depends on the context:

- **In an interactive terminal**, you're shown recovery options — kill and
  relaunch, just stop the running task, resume from a step, or cancel — and the
  launch is re-invoked with the flag you pick.
- **Non-interactively** (from the `/hula-launch` skill wrapper, CI, or a pipe),
  the server's message (which names the recovery flags) is printed and the
  process exits non-zero — no prompt, no hang.

## Forwarding environment variables to the container

Tests that need credentials (a test user login, a third-party API key, etc.) can
have those values forwarded from your local `.env` into the launch container.
Configure this by listing the variable **names** in `envVars` in
`.hublaunch/hublaunch.config.js`:

```js
export const config = {
  // ...
  envVars: ["TEST_USER_EMAIL", "API_KEY"], // names only — values are read from .env
};
```

To forward **every** non-reserved variable from `.env` without listing each one,
set `envVars` to the string `"all"`:

```js
export const config = {
  // ...
  envVars: "all", // forward all non-reserved variables found in .env
};
```

At launch time `hula launch` reads your project's `.env`, picks out exactly those
variables, and includes them in the request to the server. Notes:

- **Opt-in** — only the names you list are forwarded (or, with `"all"`, every
  non-reserved variable in `.env`); nothing is sent by default, so existing
  configs are unaffected.
- **Validated early** — if a listed variable is missing from `.env`, or the `.env`
  file is absent, `hula launch` fails before submitting the job.
- **Reserved names blocked** — system/internal variables (e.g. `PATH`, `HOME`,
  `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `OPENROUTER_API_KEY`, `CODEX_API_KEY`,
  `PROVIDER_AUTH_TOKEN`, `AWS_SECRET_ACCESS_KEY`) cannot be forwarded.
- Only forward variables your tests actually need; treat anything you list as
  leaving your machine.

## Choosing your LLM provider

HubLaunch supports three LLM providers, each with its own native agent harness:

| Provider   | Harness | Key Format | Where to Get |
|---|---|---|---|
| `claude` | Claude Code | `sk-ant-oat01-…` (OAuth) or `sk-ant-api03-…` (API key) | [claude.ai/settings](https://claude.ai/settings) or [platform.claude.com](https://platform.claude.com) |
| `openai` | OpenAI Codex CLI | `sk-…` or `sk-proj-…` | [platform.openai.com/api-keys](https://platform.openai.com/api-keys) |
| `openrouter` | OpenAI Codex CLI (via OpenRouter gateway) | `sk-or-…` | [openrouter.ai/settings/keys](https://openrouter.ai/settings/keys) — one key, 400+ models |

### How to switch providers

**During setup** (`hula init`):
```bash
hula init
# Prompted: "Choose your LLM provider"
# Select one of the three options, then provide that provider's credential
```

**After setup** — change config in `.hublaunch/hublaunch.config.js`:
```js
export const config = {
  // ...
  provider: {
    type: "openai",           // or "claude" or "openrouter"
    apiKey: "sk-…",           // required key format per provider above
  },
};
```

Or pass flags to `hula launch`:
```bash
hula launch my-branch .hublaunch/plans/my-plan.md --provider openrouter --provider-key sk-or-v1-…
```

Or use environment variable (supports all three providers):
```bash
export PROVIDER_AUTH_TOKEN=sk-or-v1-…
hula launch my-branch .hublaunch/plans/my-plan.md --provider openrouter
```

### Provider precedence

When launching, the provider type is resolved in this order (first match wins):
1. `--provider <type>` flag
2. `config.provider.type` in `.hublaunch/hublaunch.config.js`
3. Default: `claude`

The credential is resolved in this order:
1. `--provider-key <key>` flag
2. `config.provider.apiKey` in config
3. `PROVIDER_AUTH_TOKEN` environment variable

### Per-provider model defaults

When you omit a step's `model` override (see next section), the server uses a per-provider default:

| Step tier | `claude` | `openai` | `openrouter` |
| --- | --- | --- | --- |
| implementation, bugfix, mergeConflict | `opus` | `gpt-5.6-sol` | `openrouter/auto` |
| findBugs review, lintfix, build, summary, verify | `sonnet` | `gpt-5.6-terra` | `openrouter/auto` |

> **Note:** All pipeline steps in a single launch use the same global provider. Per-step provider selection (e.g., Claude for implementation, OpenAI for testing) is planned for a future release.

## Configuring per-step model & iteration overrides

`hula launch` runs your plan through a fixed 9-step server-side pipeline. By
default every step uses the server's built-in model, loop-iteration cap, and
skip behavior. To override those per step for your project, add a `steps` block
to `.hublaunch/hublaunch.config.js` (config-file only — this is a persistent
project setting, not a per-launch flag):

```js
export const config = {
  // ...
  steps: {
    implementation: { model: "opus" },
    lintfix: { model: "haiku", maxIterations: 2 },
    regression: { skip: true },
  },
};
```

Each of the 9 keys maps to a pipeline step. All fields are optional; omit a step
(or the whole `steps` block) to keep the server default:

| Step key         | `model` | `maxIterations` | `skip` | Other |
| ---------------- | :-----: | :-------------: | :----: | ----- |
| `implementation` |   ✅    |                 |        |       |
| `findBugs`       |   ✅    |   ✅ (1–20)     |        | `diffMaxLines` (≥1), `excludeRegex` (string) |
| `bugfix`         |   ✅    |                 |        |       |
| `lintfix`        |   ✅    |   ✅ (1–20)     |        |       |
| `build`          |   ✅    |   ✅ (1–20)     |        |       |
| `regression`     |         |                 |   ✅   |       |
| `mergeConflict`  |   ✅    |                 |        |       |
| `summary`        |   ✅    |   ✅ (1–20)     |        |       |
| `verify`         |   ✅    |   ✅ (1–20)     |   ✅   |       |

`model` values are free-form strings passed straight through to the server and
interpreted by the selected provider's harness (`claude --model <value>` for
`claude`; `codex --model <value>` for `openai`/`openrouter`); no allowlist is
enforced. Values are validated at config-load time — an out-of-range
`maxIterations`, a non-boolean `skip`, or an empty `model` string fails
immediately with a clear error.

When you omit a step's `model`, the server applies its per-provider default for
that step's tier (see [per-provider model defaults](./advanced.md#per-provider-model-defaults) above).

### `--skip-regression`

As a per-launch counterpart to the config `steps.regression.skip`, `hula launch`
accepts a `--skip-regression` flag that force-skips the regression-tests step for
that one invocation (it wins over whatever `steps.regression.skip` is set to in
config):

```bash
# Skip regression tests for a single launch
hula launch feature-auth .hublaunch/plans/my-plan.md --skip-regression
```

### Conflict rules (validated locally before any network call)

Two combinations are rejected client-side — `hula launch` exits `1` immediately
with the same message the server would return, so misconfigurations fail fast:

- **`bugfix.model` ≠ `mergeConflict.model`** — both map to the same
  `RALPH_BUGFIX_MODEL` env var on the server, so they cannot be set to different
  values:
  `bugfix.model and mergeConflict.model both map to RALPH_BUGFIX_MODEL and cannot conflict`
- **`regression.skip: true` combined with the legacy `--regression` flag** — one
  forces the step off, the other forces it on. This also covers passing both
  `--skip-regression` and `--regression`, and a config `steps.regression.skip:
  true` combined with a one-off `--regression`:
  `regression.skip and the legacy regression flag are contradictory`

## Cross-platform, low-footprint tooling

The workflow scripts and instruction documents that power the Agent Skills ship
**inside the `hula` package** as cross-platform Node — they are no longer copied
into your repo, and they need **no `bash` and no `jq`**, so they run identically
on macOS, Linux, and Windows. `hula init` therefore does not write
`.github/scripts/*.sh` or `.hublaunch/*-instructions.md`.

Skills invoke them via the global bin:

```bash
# Run a bundled workflow script (cross-platform, no bash/jq)
hula script approve-local -- 42 ".hula-worktrees/issue-42" "fix(#42): message"

# Print a bundled instruction document
hula instructions planning
```

**Migration:** upgrading from an older version? Existing
`.github/scripts/hula-*.sh` and `.hublaunch/*-instructions.md` keep working, but
are now obsolete and safe to delete — `hula init` prints a reminder listing them
(it never deletes anything).

**Claude Code commands:** the `/hula-*` commands are available as a Claude Code
plugin so they load globally, so `hula init` no longer writes `.claude/commands/*`
symlinks by default. Prefer repo-local command files instead? Run
`hula init --with-claude-commands`. The committed `.agents/skills/` directory
(read by GitHub Copilot, Cursor, Codex, and 30+ tools) is unchanged.

## `hula schedule`

`hula schedule` triggers a built-in or custom execute-action (e.g. the `harden` security audit) on the hula-project server, which provisions a sandbox to run it and opens a PR / plan / feedback as the outcome.

```bash
# Run the built-in harden action against src/
hula schedule --built-in harden --entry-point src/

# Run a custom action file
hula schedule --action-path skills/my-action.md

# Recurring schedule (cron)
hula schedule --built-in harden --entry-point src/ --schedule "0 3 * * *"
```

> **Tip**: prefer the `/hula-schedule` agent skill to drive this command from plain
> language — e.g. `/hula-schedule harden src/ every night and open a PR`. It
> translates schedule phrasing into cron and confirms before running.
>
> The skill can also **author an action from a description** and **manage** runs
> and schedules conversationally:
>
> ```text
> # Describe an action — the skill asks questions, writes & publishes the file, then runs it
> /hula-schedule remove unreachable code in src/ every night and open a PR
>
> # Manage
> /hula-schedule list
> /hula-schedule show <runId>
> /hula-schedule run now <scheduleId>
> /hula-schedule cancel <scheduleId>          # offers to delete the related action file
> /hula-schedule update <scheduleId> cron to every Monday 9am
> /hula-schedule update the skill file for <scheduleId> to also remove unused imports
> ```
>
> Authored actions are written to `.hublaunch/skills/<YYYY-MM-DD-HH:MM-slug>.md`
> and pushed to `origin/main` via a temporary worktree **before** the run (the
> server reads the file from the default branch at run time).

Required (provide exactly one):

- **`--built-in <name>`** — a built-in action name (e.g. `harden`).
- **`--action-path <path>`** — a repo-relative path or `https://` URL to a custom action file.

Optional flags include `--entry-point <path>`, `--outcome-type <pr|plan|feedback>`, and `--schedule "<cron>"`. Run `hula schedule --help` for the full grouped list and cron examples.

Defaults and requirements:

- **Server URL**: defaults to `https://www.hublaunch.site`. Override with `--url <url>` or the `HULA_PROJECT_URL` environment variable.
- **`--outcome-type`**: defaults to `pr`. Valid values are `pr`, `plan`, and `feedback`.
- **GitHub login**: run `hula login` first so your GitHub token is attached to the request automatically (the server requires it). Alternatively, set the `GITHUB_TOKEN` environment variable.
- **LLM provider credential**: HubLaunch supports three providers — `claude` (default), `openai`, and `openrouter` — each running on its own native agent harness server-side (Claude Code for `claude`; the OpenAI Codex CLI for `openai`/`openrouter`). Select one via `--provider <type>`, then `config.provider.type` in `.hublaunch/hublaunch.config.js`, then the default `claude`. Supply its credential via `--provider-key <key>`, then `config.provider.apiKey`, then the `PROVIDER_AUTH_TOKEN` environment variable. Per-provider key formats:
  - `claude` — a subscription OAuth token (`sk-ant-oat01-…`, from [claude.ai/settings](https://claude.ai/settings), requires Claude Pro or Max) **or** an Anthropic API key (`sk-ant-api03-…`, from [platform.claude.com](https://platform.claude.com)). Both are accepted.
  - `openai` — an OpenAI API key (create one at [platform.openai.com/api-keys](https://platform.openai.com/api-keys)).
  - `openrouter` — a key starting with `sk-or-` (create one at [openrouter.ai/settings/keys](https://openrouter.ai/settings/keys)); one key, 400+ models.

  Configure it in `.hublaunch/hublaunch.config.js`:

  ```js
  export const config = {
    // ...
    provider: {
      type: "openrouter",        // "claude" (default) | "openai" | "openrouter"
      apiKey: "sk-or-v1-…",      // optional here; can come from --provider-key or PROVIDER_AUTH_TOKEN
    },
  };
  ```

  > **Breaking change:** the old `anthropicApiKey` config key, `--anthropic-key` flag, and `ANTHROPIC_API_KEY` env fallback have been removed. Use the `provider` block above. A leftover `anthropicApiKey` in your config produces an explicit migration error.

## `hula info`

`hula info <trackingName>` surfaces facts about a tracked plan. Each flag adds a
key to the request:

| Flag                | Meaning                                                  |
| ------------------- | -------------------------------------------------------- |
| `--logs`            | Full stored run log                                      |
| `--lastLogs`        | Last N lines of live output (see `--lines`)              |
| `--diff`            | PR unified diff (fetched server-side from GitHub)        |
| `--initial`         | Initial PR body / AI summary                             |
| `--lessons`         | Lessons-learned content                                  |
| `--clientSessionId` | Claude Code session id that launched the plan            |
| `--lines <n>`       | Trailing line count for `--lastLogs` (default: 100)      |
| `-r, --raw`         | For a single content key, print raw content to stdout    |

```bash
hula info my-feature --logs                 # opens the full run log in the editor
hula info my-feature --lastLogs --lines 50   # opens the last 50 lines of live output
hula info my-feature --diff                  # opens the PR diff
hula info my-feature --clientSessionId       # prints the launching session id (plain)
hula info my-feature --logs --diff           # prints a merged JSON object {logs, diff}
hula info my-feature --logs --raw            # prints the raw run log to stdout
```

**Output rules** (let K = number of requested keys):

- **K == 1, content key** → the content is formatted, written to a temp file,
  and opened in your editor. With `--raw` the raw content is printed to stdout.
- **K == 1, `--clientSessionId`** → the session id (or `null`) is printed plain.
- **K >= 2** → the keys are merged into one JSON object printed to stdout.

Content keys route to `GET /api/v1/info/:planName`; `--clientSessionId` routes to
the status endpoint. `--diff`/`--initial` can be `null` when there is no PR yet.
See the [Commands Reference](./commands.md#hula-info) for details.

## Legacy: `/hula-create`

Historically, HubLaunch offered a Free tier (`/hula-create`, which assigned
issues to GitHub Copilot) alongside a Pro tier. The current workflow unifies on
Claude Code via `/hula-launch` for all users. The legacy `/hula-create` command
remains available for backward compatibility but is no longer the recommended
path.
