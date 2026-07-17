# hub-launch

> **AI coding without the chaos**

AI coding agents write great code — but you're still stuck doing the busywork around them: creating issues, wrangling branches, monitoring runs, and cleaning up afterward. That constant context switching can be anything from disruptive to stressful. Anyone who knows how to code would agree that good development requires focus.

hub-launch handles all of that by removing most of the interruptions and only requiring you to perform the critical steps of planning and review. Describe what you want to build, and it creates the GitHub issue, runs Claude Code in an isolated Daytona cloud container, and opens the PR for your review. Nothing touches your local machine or your current branch.

```bash
/hula-plan Add password reset support    # generates plan, auto-validates
/hula-launch password-reset-support      # creates issue, starts AI session
# (Claude Code writes the code, runs tests, pushes branch, opens PR)
/hula-fix                                # perform any follow-up needed locally in a worktree
/hula-merge                              # merge, close issue, restore branch
```

That's the whole fundamental workflow.

## Demo

<a href="https://www.youtube.com/watch?v=4-YRVB7mQZ8" target="_blank">
  <img src="./docs/assets/demo-preview.svg" alt="Watch hub-launch demo on YouTube" width="100%"/>
</a>

## Why hub-launch?

| Without hub-launch                                                                            | With hub-launch                                                                 |
| --------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------- |
| Several steps in the AI cycle, requiring interruptions | complete integration into Github, and many automated validation steps |
| AI agent runs on your machine, taxing your local resources | ralph-like script on a container in a cloud — zero local overhead |
| Coding work and progress clutters your workspace    | Each issue runs in its own isolated container — safe and clean |
| frequent switching between tools and sites | Everything orchestrated from your local agent session |

## Features

- 🤖 **AI-Powered Workflow** — plan → launch → verify → merge skills that are run by your agent
- 🔄 **Github Integration** — creating issues, hand-off if needed, generating PRs, merging and cleaning up
- ☁️ **Cloud Container Isolation** — each issue runs in a dedicated cloud container, keeping your branch and environment clean
-  **Configurable** — we use a Ralph script which can be extended with custom lifecycle hooks, and you can configure locally several options
- 🖥️ **Client Agnostic** — based on skills that can be adapted to most agent harnesses
- 🔔 **Notifications** - you can configure an endpoint for notifications about progress. For instance, a slack channel.
- 📋 **Logging** - run `hula-info` for progress in the container. Also pushes several documents within each PR showing logging.
- 🖥️ **Dashboard** — track all your active plans at [https://www.hublaunch.site/dashboard](https://www.hublaunch.site/dashboard)
- 🔒 **Safe** - tokens are maintained by you locally in your config file, and on our server securely protected and removed when no longer needed.

### The Workflow

All users follow the same workflow:

```
/hula-plan → /hula-launch → /hula-verify → /hula-fix (if needed)
```

`/hula-launch` runs a full automated pipeline in a cloud container (Claude Code via Daytona) — it creates the GitHub issue, runs the implementation, executes tests, and opens a PR, all without touching your local machine. `/hula-verify` checks the PR against the plan's acceptance criteria, and `/hula-fix` addresses any gaps. `/hula-merge` merges and cleans up when you're ready.

Visit [https://www.hublaunch.site](https://www.hublaunch.site) for plans and pricing.

> ℹ️ Historically, HubLaunch offered a Free tier (`/hula-create`, which assigned issues to GitHub Copilot) alongside a Pro tier. The current workflow unifies on Claude Code via `/hula-launch` for all users. The legacy `/hula-create` command remains available for backward compatibility but is no longer the recommended path.

## Quick Start

```bash
# 1. Install
npm install -g hub-launch
# or with pnpm
pnpm add -g hub-launch

# 2. Initialize in your project
cd <your-project>
hula init

# 3. Use it
hula launch <branch-name>   # create the issue and start the AI coding session
hula --help
```

### Upgrading

After upgrading the CLI:

```bash
npm install -g hub-launch@latest   # or: pnpm add -g hub-launch
```

re-run `hula init` inside each project to refresh the bundled Agent Skills,
instruction templates, and config scaffolding:

```bash
cd <your-project>
hula init   # safe to re-run; preserves your keys and team settings
```

The CLI reminds you automatically when a project was initialized with a
different version than the one currently installed.

## Core Workflow

The primary use case is AI-assisted issue development via the hula-project server:

```bash
# 1. Plan the feature
#    Validation runs automatically in the same session after the plan is saved.
#    When validation finishes, the assistant offers to launch right away with a
#    default issue name derived from the plan (reply "yes" to launch, or decline
#    and run /hula-launch <name> yourself later).
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
/hula-merge
```

> 💡 `/hula-confirm` remains available as a standalone command for re-validating a plan you've edited by hand.

Or directly via CLI:

```bash
hula launch password-reset-support .hublaunch/plans/2026-05-07-17:00-password-reset.md
```

## Commands

Top-level commands:

| Command        | Alias | Description                                                      |
| -------------- | ----- | ---------------------------------------------------------------- |
| `hula`         | `hl`  | Main CLI                                                         |
| `hula login`   | —     | Authenticate with GitHub + hula-project                          |
| `hula init`    | —     | Initialize configuration                                         |
| `hula create`  | —     | Create issue from plan file                                      |
| `hula merge`   | —     | Merge PR and clean up                                            |
| `hula launch`  | —     | Trigger AI coding session on hula-project server                 |
| `hula schedule` | —     | Trigger or schedule an execute-action (e.g. `--built-in harden`) |

Run `hula <command> --help` for details, or see the full [Commands Reference](./docs/commands.md).

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

> 💡 After a PR is merged, `hula merge` automatically fast-forwards your **local**
> `main` at the project root to match `origin/main` — no manual `git pull` needed.
> It is non-destructive (fast-forward only) and works even when run from inside a
> worktree; it is skipped safely if local `main` can't fast-forward. When it is
> skipped, `/hula-merge` reports the specific reason and the exact command to fix it.

#### Troubleshooting `/hula-merge`

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

`/hula-merge` prints the specific reason and remediation in its output, and its
summary shows ⚠️ when the local update was skipped.

Use `--resume <step>` to re-run from a specific step after a failure, without re-doing earlier steps:

```bash
# Resume from step 4 (skips setup, bug review, and commit)
hula launch my-issue .hublaunch/plans/my-plan.md --resume 4

# Resume from step 7 with fix instructions
hula launch my-issue .hublaunch/plans/my-plan.md --resume 7 --fix "address build warning in src/utils/shell.ts"
```

> **Note**: `--fix` requires `--resume` and passes instructions to the AI agent for that stage.

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

### Forwarding environment variables to the container

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
  `ANTHROPIC_API_KEY`, `AWS_SECRET_ACCESS_KEY`) cannot be forwarded.
- Only forward variables your tests actually need; treat anything you list as
  leaving your machine.

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
- **Anthropic OAuth token**: an OAuth token (`sk-ant-oat…`) is required — the sandbox needs it as `CLAUDE_CODE_OAUTH_TOKEN`. It is resolved from `--anthropic-key <key>`, then `config.anthropicApiKey` in `.hublaunch/hublaunch.config.js`, then the `ANTHROPIC_API_KEY` environment variable. Get a token at [claude.ai/settings](https://claude.ai/settings) (requires a paid Claude.ai plan — Pro or Max). Standard API keys (`sk-ant-api03-…`) are not accepted.
- **Daytona API key**: required by the server. Resolved from `--daytona-key <key>`, then `config.daytonaApiKey`, then the `DAYTONA_API_KEY` environment variable.

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
See the [Commands Reference](./docs/commands.md#hula-info) for details.

## Documentation

| Document                                 | Description                                 |
| ---------------------------------------- | ------------------------------------------- |
| [Commands Reference](./docs/commands.md) | Every CLI command with options and examples |

The full documentation index is at [docs/README.md](./docs/README.md).

## Requirements

- **Node.js** >= 18.0.0
- **pnpm** (or npm)
- **GitHub CLI (`gh`)** >= 2.4.0, authenticated via `gh auth login`
- **Playwright Chromium** — `npx playwright install chromium`

## Contributing

1. Fork and create a feature branch
2. Run `pnpm run typecheck`
3. Submit a pull request

See the [Commands Reference](./docs/commands.md) for available commands.

## Links

- [HubLaunch Website](https://www.hublaunch.site)
- [Dashboard](https://www.hublaunch.site/dashboard)
- [GitHub Repository](https://github.com/NoStackApp/hub-launch)
- [Issue Tracker](https://github.com/NoStackApp/hub-launch/issues)
- [Documentation](./docs/README.md)

## License

MIT — see [LICENSE](./LICENSE) for details.
