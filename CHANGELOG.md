# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.26.0] - 2026-09-03

### Added

- `beforeLaunch` and `afterMerge` project hooks. `beforeLaunch` runs before `hula launch` sends its request, letting a project hook provision per-launch resources (e.g. an isolated database branch) and inject the resulting environment variables into the launch — a hook failure aborts the launch rather than proceeding against the wrong resources. `afterMerge` runs after `hula approve` successfully merges a PR, for best-effort cleanup of whatever `beforeLaunch` provisioned. `hula init` now scaffolds commented-out placeholders for both in generated configs.

### Changed

- Removed the `deploymentStartup` hook and its Clerk/Auth0 preview-auto-login scaffold — unrelated to the new lifecycle hooks and superseded by `hula preview`'s built-in auto-login fallback.

### Fixed

- Hook execution no longer runs through a shell on POSIX systems, so shell metacharacters in a hook's context (e.g. backticks in a PR title) can no longer be reinterpreted instead of passed through as literal text.

## [1.25.0] - 2026-08-23

### Added

- New `hula error-watcher` command to manage production **Error Watchers** — inbound error webhooks that deduplicate reported errors and auto-launch a fix (PR, plan, or feedback run). Seven modes: `--create`, `--list`, `--show`, `--events`, `--update`, `--delete`, and `--print-setup`. `--create` and `--print-setup` print the steps to mint a project ingest key, a paste-ready `.env` block, and a hard-coded signed-request snippet that signs the exact `` `${timestamp}.${body}` `` payload the server verifies. Credentials resolve flags → `.hublaunch/hublaunch.config.js` → env, identical to `hula schedule`, and are never written to any file. `--events` shows each error's disposition (`deduped`, `skipped_environment`, `skipped_budget`, `skipped_credits`, `skipped_open_pr`, `launched`, `failed`) so "why was there no PR?" is answerable from the terminal; with no watcher id it covers every watcher on the project. Requires a hula-server with Error Watcher support; older servers return a clear "not supported yet" message. See [docs/error-watcher.md](./docs/error-watcher.md).
- `--instructions`, `--error-env KEY=VALUE`, and `--secret <literal>` flags on `--create`/`--update` for the three watcher fields that shape what the fix agent sees: trusted guidance rendered into the agent's brief, environment variables injected into the fix sandbox, and extra literal values redacted from every payload. Each replaces the stored value wholesale, with matching `--clear-instructions` / `--clear-error-env` / `--clear-secrets` flags. Values are write-only — the server never echoes them back, and the CLI never prints them.
- Optional `errorWebhookUrl` config key to override the Error Watcher ingest URL for self-hosted servers whose webhook host differs from `hulaProjectUrl`.

### Changed

- **Error Watcher ingest now authenticates on a project ingest key.** Matching the server, the credential a reporting app presents moved from the per-watcher `hew_` token to a project-level `hik_` key signing with its own `his_` secret. The generated `.env` block emits `HULA_INGEST_KEY` / `HULA_INGEST_SECRET` (was `HULA_ERROR_WATCHER_TOKEN` / `HULA_ERROR_WATCHER_SECRET`) and the snippet sends `X-Hula-Api-Key` (was `X-Hula-Watcher`). The watcher now holds configuration only; `--create` prints no credential of its own and instead directs you to **Projects → gear icon → Error reporting API keys**, the only place a key can be minted. **Any reporter wired up against an earlier build of this command must be updated or it will 401.**
- The printed snippet now sends `errorName` and `errorCode` alongside `key`. The server's dedupe fingerprint is built from those three identity fields and nothing else, so a report carrying none of them shares a single bucket with every other such report — one fix per watcher per dedupe window.
- `--events` with no watcher id lists the project's watchers and queries each one, merging the results newest-first. It previously requested a project-wide events route that does not exist on the server and always returned 404.
- `--update` now rejects `--container-cpu`, `--container-memory`, `--container-disk`, `--update-notification-url`, and `--update-notification-name-tag` up front. The update endpoint ignores those fields, so sending them reported success while changing nothing; they remain settable at `--create`.
- `--delete` no longer claims reports will start returning 401. Deleting a watcher revokes no credential — ingest keys keep authenticating, and the webhook answers 409 once the project has no enabled watcher left.
- `--show` displays the watcher's `instructions` and no longer prints the vestigial watcher token prefix.
- A `409` from the ingest webhook now maps to a specific message naming the cause ("no enabled error watcher is configured for this project") and the commands that fix it, instead of falling through to a generic status line.

### Removed

- `hula error-watcher --rotate`. It rotated the watcher's signing secret, which the ingest webhook no longer verifies, and its response handling did not match the server's shape. The signing secret that matters belongs to the project ingest key and is rotated from the dashboard settings page, which has no REST route for the CLI to call.

## [1.24.0] - 2026-08-18

### Fixed

- Entitlement is now verified with the server on every launch instead of being cached indefinitely in local config. A cancelled subscription, an expired free trial, or exhausted PR credits no longer slips past the local gate only to fail later against the server. `usageTier` is now treated as a refreshable cache of the last server answer, consulted only when the server is unreachable.
- Access-denied messages now reflect the account's actual subscription status — never subscribed (offers the free trial), cancelled, payment failed, or the server's status verbatim — instead of always claiming the user is on the free tier.
- Billing and upgrade links point at the configured server's own dashboard rather than a hardcoded hublaunch.site, so preview and self-hosted deployments send users to their own billing page.
- Chained hula skills (`/hula-plan` → confirm → launch) now execute inline explicitly, fixing the "blocked by disable-model-invocation" break under newer Claude Code versions that enforce that flag on model-initiated Skill-tool calls.

### Changed

- Prefer the server's own 402 response message and its `upgradeUrl` / `buyCreditsUrl` over anything the CLI infers, in both the single-repo and `--folder` launch paths.

## [1.23.0] - 2026-08-13

### Added

- Multi-provider LLM support: choose `claude` (default), `openai`, or `openrouter` per launch. Select a provider with `--provider <type>` (or `config.provider.type`) and supply its credential with `--provider-key <key>` (or `config.provider.apiKey`, or the `PROVIDER_AUTH_TOKEN` env var). `hula init` now prompts for the provider first, then its credential. Client-side live validation runs against the selected provider's API before launch.
- `claude` now accepts Anthropic API keys (`sk-ant-api03-…`) in addition to subscription OAuth tokens (`sk-ant-oat01-…`).

### Changed

- **BREAKING:** the `anthropicApiKey` config key, the `--anthropic-key` flag, and the `ANTHROPIC_API_KEY` env fallback have been replaced by the `provider` config block, `--provider`/`--provider-key` flags, and the `PROVIDER_AUTH_TOKEN` env var. Request bodies now send `provider: { type, authToken }` instead of `anthropicApiKey`. A leftover `anthropicApiKey` in config produces an explicit migration error. Requires hula-server with matching multi-provider support.

### Documentation

- Improved multi-provider documentation and discovery.

### Fixed

- Build errors fixed.

## [1.22.0] - 2026-08-12

### Added

- Multi-repo feature groups: client-side `--folder` fan-out enables launching and checking status across a group of repositories from a single parent folder (group launch, group status).

### Fixed

- `--folder` group launch now works when invoked from the `/hula-launch` Agent Skill in non-TTY environments (#344).

## [1.21.0] - 2026-08-06

### Added

- Single-command onboarding: `hula init` now chains directly into login, with Anthropic token entry deferred until actually needed.
- When login fails with `repo_not_found`, guidance is shown for installing the GitHub App.

### Changed

- Generated config no longer emits a default `containerResources` block.
- Obsolete Daytona keys are scrubbed from existing config on re-init.

## [1.20.0] - 2026-08-04

### Added

- Added a one-plan-one-PR scope check to plan validation.
- Made `/hula-plan` output clearer with a summary, folded detail section, optional diagram, and pre-save checklist.

### Changed

- Renamed the `hula-merge` Agent Skill to `hula-approve`, updating the CLI command, wrapper scripts, and docs.

### Security

- Removed client-side Daytona API key handling.

### Documentation

- Updated the plan/approve-first README, notifications guide, and skill descriptions.

## [1.19.0] - 2026-07-29

### Added

- Added `--autoLaunch` flag to `/hula-plan`.

### Documentation

- Documented the `envVars: "all"` forwarding option everywhere it's surfaced to users (generated config, hooks README).

## [1.18.0] - 2026-07-28

### Added

- Verify reports now auto-post to the PR by default; use `--no-post` to restore the old confirm-before-posting behavior.
- Added a `hula-help` Agent Skill for interactive onboarding and reference guidance.
- Moved `hula-verify`'s tmp writes from OS `/tmp` to a repo-local, gitignored `.hublaunch/tmp/` directory (#325).

## [1.17.0] - 2026-07-23

### Added

- `hula launch` now supports per-pipeline-step model and iteration-cap overrides via a `steps` block in `.hublaunch/hublaunch.config.js` (hula-server PR #442), plus a `--skip-regression` flag to force-skip regression tests for a single launch. Conflicting `bugfix.model`/`mergeConflict.model` values, or `regression.skip` combined with the legacy `--regression` flag, are rejected locally before any network call.

## [1.16.0] - 2026-07-17

### Fixed

- Plan upload to `origin/main` now survives a concurrent push to `main`. When the remote branch advances between the temporary worktree's commit and its push, the upload automatically fetches, rebases the plan commit onto the new head, and retries (up to 3 attempts with exponential backoff) instead of failing with `cannot lock ref`. Genuine content conflicts still fail fast with a clear message, and non-race errors (auth, network) are no longer retried. This fixes transient `hula launch`/`hula upload` failures on active repositories (#318).

## [1.15.0] - 2026-07-15

### Added

- `hula info <trackingName>` is now the single command for surfacing plan facts. It supports `--logs`, `--lastLogs`, `--diff`, `--initial`, `--lessons`, and `--clientSessionId` (plus `--lines` and `--raw`). Content keys are fetched from the server's new `GET /api/v1/info/:planName` endpoint (hula-server PR #421); `--clientSessionId` continues to use the status endpoint. A single content key opens in your editor (or stdout with `--raw`), a single `--clientSessionId` prints the id plain, and two or more keys print one merged JSON object.

### Removed

- **Breaking:** removed the `hula logs` command and the `/hula-log` chat skill. Use `hula info` / `/hula-info` instead (`hula info <name> --lastLogs` replaces the old default live-tail behavior; `--logs`/`--lessons` map directly).

## [1.14.0] - 2026-07-15

### Added

- Capture and send `clientSessionId` at launch for session tracking.
- New `hula info` command to display client/session details.

### Changed

- Groundwork for the free-tier upgrade funnel in the hula launch flow.

## [1.13.0] - 2026-07-14

### Changed

- `hula init` now prompts for **only** the two required API keys (Anthropic OAuth token and Daytona API key). Every other setting is written to `.hublaunch/hublaunch.config.js` with a sensible default (documented inline) for the user to edit manually, instead of being asked one field at a time. Re-running `hula init` preserves all previously-set values, including non-prompted fields such as `daytonaTier` and `envVars`.
- The generated config no longer includes commented-out placeholder sections for `teamMembers`, `commandAliases`, `priorityLevels`, `issueSortOrder`, `services`, and `hooks`. These sections are written only when they hold a real value (or are preserved from an existing config on re-init); an unset optional setting is simply omitted, keeping the file compact.
- The generated config no longer writes `trackingFile`, `createIssuesPreference`, `planChoices`, `pollingProvider`, `pollIntervalSeconds`, or `browserHeadless`. Each falls back to its documented default at load time, so behavior is unchanged; setting any of them manually in the config file still works and is preserved across re-runs.
- Reworded the `hula init` intro and "Next steps" output to reflect the minimal prompt and point users to the config file for further customization.

### Fixed

- `hula init` now creates (and logs) the plans directory at the config's actual `planPath` on re-init, instead of always using the default `.hublaunch/plans`.

### Removed

- Removed the `daytonaTier`, `editorCommand`, `planPath`, `trackingFile`, `createIssuesPreference`, `planChoices`, `skipUntrackedPrompt`, `teamMembers`, `authProvider`, `configureVsCodeAutoApproval`, and `envVars` prompts from `hula init`. These are now configured by editing the generated config file. (VS Code auto-approval is still applied by default; auth provider defaults to `none`.)

## [1.12.0] - 2026-07-13

### Changed

- `hula init` now preserves **all** existing config values on re-run, including custom/arbitrary keys and `hulaProject`/`hulaProjectUrl`, emitting any keys not in the documented template under a `// Preserved custom settings` block.
- `hula init` loads an existing config via native dynamic `import()` only; the lossy regex config parser has been removed. A syntactically broken config now fails fast with guidance to fix the file or run `hula init --force` to regenerate a fresh config (custom edits will be lost). `hula init --force` now correctly skips parsing the existing file.

### Removed

- Removed the `overrideStartupScript` prompt from `hula init`. An existing `.hublaunch/hooks/deploymentStartupScript.ts` is never overwritten (created only when missing).

## [1.11.1] - 2026-07-09

### Added

- Offer to launch automatically after plan validation completes, so you can go straight from a validated plan into a run without a separate step.

## [1.11.0] - 2026-07-08

### Added

- Client support for the unified launch/cancel `ralph-run` API, with `--kill` to stop an active run and `--kill-and-relaunch` to restart it. (#287)

## [1.10.0] - 2026-07-07

### Added

- `hula logs` now supports `--logs`, `--lessons`, and `--all` flags for client-side artifact retrieval.
- `hula launch` CLI and the `hula-launch` skill template gained a `--test` flag.
- Integrated `updateNotificationNameTag` on the hub-launch client.

### Changed

- Renamed `hula execute` to `hula schedule` across the CLI, skill, wrapper scripts, and docs.

### Fixed

- `/hula-merge` now correctly updates the local main branch and reports status properly.

## [1.9.0] - 2026-06-26

### Added

- Environment Variables to Interactive Init Prompts: Users can now pass environment variables directly through interactive initialization prompts for flexible runtime configuration.

## [1.8.1] - 2026-06-25

### Added

- Consolidate Hula Workflow to Single `/hula-launch` Path for a more streamlined execution flow.
- Pass Environment Variables from Hub-Launch to Hula Server to enable dynamic configuration at runtime.
- Fix JSON Parsing Mismatch in hula-fix Workflow to handle edge cases in workflow state management.

### Fixed

- Write compact JSON in hula-fix session files to ensure correct parsing and prevent data corruption.

## [1.8.0] - 2026-06-24

### Added

- Updated `LaunchJobResponse` type and display logic to reflect the new server response shape.

## [1.7.0] - 2026-06-23

### Fixed

- **`/hula-launch` relaunch now checks the remote for a plan file before failing.** When relaunching a project, the CLI previously failed immediately if the local plan file was missing. It now checks the remote repository first, so a relaunch succeeds on a fresh clone or after the local `.hublaunch/` directory has been cleaned — without requiring a manual `git pull`.

## [1.6.0] - 2026-06-23

### Changed

- chore: upload plan via hula

## [1.5.0] - 2026-06-22

### Fixed

- **`hula execute` now sends Slack notifications.** The `/hula-execute` skill was not triggering Slack notifications on job completion. The `execute` command now correctly invokes the notification path, giving parity with `hula launch`. No config changes required — notifications fire automatically when `SLACK_WEBHOOK_URL` is set or a webhook URL is configured.

- **SSH remote URLs with custom host aliases are now parsed correctly.** `GitService` previously matched only `git@github.com:owner/repo.git`; the regex now accepts any SSH alias (`git@github-work:owner/repo.git`, `git@gh-personal:owner/repo.git`, etc.). This unblocks users who use `~/.ssh/config` host aliases for multi-account GitHub setups.

### Changed

- **Generic AI-agent language in plan instructions.** The planning and confirmation instruction templates (`planning-instructions.md`, `proceed-instructions.md`) and the `hula-plan` / `hula-confirm` skills no longer describe the execution target as "GitHub Copilot" or reference the deprecated `/hula-upload` command. End-of-plan completion messaging now uses generic "AI-assisted implementation" / "AI implementation agent" wording that covers both pro mode (Claude at hula-server) and free mode (GitHub Copilot agent), and directs users to run `/hula-create` — which syncs the plan to `origin/main` automatically — as the next step. Functional GitHub Copilot references (bot assignment in `hula-create`, Copilot-authored PRs in `hula-merge`) are unchanged. **Existing projects must re-run `hula init` to pick up the updated `.hublaunch/planning-instructions.md` and `.hublaunch/proceed-instructions.md`** (use the override flags or delete the files first, since these are not overwritten if they already exist); skill files are always refreshed by `hula init`.

- **`release.sh` now builds before bumping the version.** A failed TypeScript compile aborts the release before the tag, commit, or npm publish — so a broken build can never produce a published package with a new version number. Local `dist/` is also refreshed so linked binaries reflect the released source immediately.

## [1.4.1] - 2026-06-21

### Added

- **Re-init reminder after CLI upgrades.** `hula init` now stamps the generating CLI version into the project's `hublaunch.config.*` as a new optional top-level `version` field. On every subsequent command (except `init`, `help`, `--help`/`-h`, and `--version`/`-V`), the CLI compares that recorded version against the installed one and prints a one-line warning to re-run `hula init` when they differ — so upgraded skills, instruction templates, and config scaffolding don't silently go stale. The check is synchronous, cheap, and crash-proof (it can never break a command). Existing projects initialized before this release have no `version` field, so they will see the reminder until they re-run `hula init` once. No `postinstall` script is involved.

## [1.4.0] - 2026-06-21

### Added

- The `/hula-execute` skill can now **author an execute action from a plain-language description** and **manage runs and schedules conversationally**. Describe a task with no `--built-in`/`--action-path` (e.g. `/hula-execute remove unreachable code in src/ every night and open a PR`) and the skill asks clarifying questions, confirms a name, writes a free-form action file to `.hublaunch/skills/<YYYY-MM-DD-HH:MM-slug>.md`, publishes it to `origin/main` **before** the run, then runs or schedules it. Management is now conversational too: `list`, `show <runId>`, `run now <scheduleId>`, `cancel <scheduleId>` (offers to delete the related action file, guarded so it refuses while another active schedule still references it), and `update <scheduleId> …` (either edit + re-publish the action file, or cancel + recreate the schedule with a new cron on the same action).
- `hula execute --publish-skill <path>` and `--delete-skill <path>` — commit or remove a `.hublaunch/skills/` action file on `origin/main` through a temporary detached worktree, so the hula-project server can read it from the default branch at run time without ever touching your current branch. Both reject absolute paths, path traversal, and any path outside `.hublaunch/skills/`. These back the skill's authoring/cleanup steps; you normally invoke them through the skill rather than directly.
- `hula init` now installs `.hublaunch/skill-creation-instructions.md` (read by the `/hula-execute` skill at runtime, parallel to how `/hula-plan` reads its planning instructions) and ensures the `.hublaunch/skills/` action-file directory exists (seeded with a `.gitkeep`). The new `hula-execute-manage.sh` wrapper is added to the bundled scripts.

### Changed

- Extracted `FilePublishService` (`src/services/git/FilePublishService.ts`), which encapsulates the temporary-worktree commit/push/delete flow that was previously inlined in `hula upload`. Both plan upload and the `/hula-execute` skill-publish path now share this single tested implementation (DRY), including the git-push refspec injection guard.

### Documentation

- Documented the new `/hula-execute` authoring and conversational management flows, and the `--publish-skill` / `--delete-skill` flags, in `README.md` and `docs/commands.md`.

## [1.3.0] - 2026-06-19

### Added

- `hula merge` now automatically fast-forwards your **local** root `main` to match `origin/main` after a successful merge — no manual `git pull` needed. It is cwd-independent (works even when `hula merge` runs from inside a worktree, via the new `WorktreeService.getMainWorktree()`), fast-forward only, and fully guarded: the update is skipped with a warning (never an error, since the PR is already merged remotely) when the project root isn't on the default branch, has uncommitted changes, or can't fast-forward. When it succeeds, the merge summary reports `✓ Local main updated to latest origin`.
- `WorktreeService.getMainWorktree()` — returns the project root (main) worktree's path and checked-out branch by reading the first entry of `git worktree list --porcelain`, so it stays correct even when called from inside a linked worktree.

### Documentation

- Documented the post-merge local `main` fast-forward behavior in `README.md` and `docs/commands.md`.
- Expanded the `hula execute` reference: marked each flag as required/optional, added cron schedule examples, and noted that the `/hula-execute` agent skill can drive the command from plain language (translating schedule phrasing into cron and confirming before running).

## [1.2.3] - 2026-06-16

### Fixed

- `hula logs` no longer fails with "Server URL and API key are required" when `.hublaunch/hublaunch.config.js` has a `hulaApiKey` but no `hulaProjectUrl` (and `HULA_PROJECT_URL` is unset). It now falls back to the default `HULA_PROJECT_URL` (`https://www.hublaunch.site`), matching `launch`, `execute`, and `login`. The same fallback was applied to the job-status and job-log paths in `hula launch`.
- `hula login` now writes `hulaProjectUrl` to the config even when an API key is already present. Previously the URL was only saved on first login, so re-running `hula login` on a config that already had `hulaApiKey` but no URL never repaired it — leaving commands like `hula logs` unable to resolve the server.

### Internal

- `publish-to-npm` workflow now posts a Slack notification on release publish success and failure (`notify-success` / `notify-failure` jobs). Self-guarded: skips on forks and no-ops when the optional `SLACK_RELEASE_WEBHOOK_URL` secret is unset.

## [1.2.2] - 2026-06-16

### Fixed

- `hula execute` now attaches the Anthropic OAuth token to the request, matching `hula launch`. Previously the token was never sent, so sandbox runs failed because the container had no `CLAUDE_CODE_OAUTH_TOKEN`. The token is resolved from `--anthropic-key`, then `config.anthropicApiKey` in `.hublaunch/hublaunch.config.js`, then the `ANTHROPIC_API_KEY` environment variable, and must be an OAuth token (`sk-ant-oat…`) — standard API keys (`sk-ant-api03-…`) are rejected with a clear error.

### Added

- `hula execute --anthropic-key <key>` flag for supplying the Anthropic OAuth token directly.

### Changed

- Extracted a shared `resolveEphemeralCredentials()` resolver (`src/utils/ephemeral-credentials.ts`) used by both `launch` and `execute`, making credential precedence and validation a single source of truth (DRY). Resolution is now pure and side-effect free; each command owns how it presents errors.

### Documentation

- Documented the Anthropic OAuth token and Daytona API key requirements for `hula execute` in `README.md` and `docs/commands.md`, including the new `--anthropic-key` and `--daytona-key` options.

## [1.2.1] - 2026-06-12

### Fixed

- `hula execute` now attaches the GitHub token to the request (parity with `hula launch`), resolved from `hula login` credentials or the `GITHUB_TOKEN` environment variable — the server hard-requires it on `POST /api/v1/execute`.
- `hula execute` defaults the server URL to `https://www.hublaunch.site` instead of erroring out when no URL is configured; still overridable via `--url` or `HULA_PROJECT_URL`.
- `--outcome-type` now defaults to `pr` when omitted and is validated against `pr`, `plan`, and `feedback`, rejecting invalid values with a clear error.

### Documentation

- Added a `hula execute` section to `README.md` and documented the new server URL, GitHub token, and `--outcome-type` defaults in `docs/commands.md`.

## [1.2.0] - 2026-06-11

### Added

- `GitService.showFile(ref, path)` — retrieves any file from git history by ref and path, with injection guards.
- `upload.ts` fallback: if the plan file no longer exists on disk, automatically recovers it from `git show main:<path>` so uploads never silently fail after a branch clean-up.
- `launch.ts` resilience: treats working-tree-only plans as needing upload, so the launch flow works even when the plan hasn't been committed yet.

### Improved

- `/hula-launch` skill rewritten to a single-step branch + plan extraction, removing a redundant `Read` call and multi-turn reasoning overhead.
- `hula-launch-run.sh`: `json_escape` now uses `jq` with a `sed` fallback, producing valid JSON for multi-line git error messages and removing a pre-existing double-escape bug.

## [1.1.0] - 2026-06-08

### Fixed

- Register `create` command in CLI entry point so it is accessible from the command line.

## [1.0.3] - 2026-06-05

### Fixed

- Bug fixes and stability improvements for the official release.

## [1.0.2] - 2026-06-02

### Fixed

- `hula --version` now reports the correct version from `package.json` instead of a hardcoded value.

## [1.0.1] - 2026-06-02

### Fixed

- npm package now only ships compiled `dist/` output; TypeScript source is no longer included in the tarball.

## [1.0.0] - 2026-06-02

### Changed — BREAKING

- **Slash commands renamed**: `/hula.plan` → `/hula-plan`, `/hula.fix` → `/hula-fix`,
  `/hula.create` → `/hula-create`, `/hula.verify` → `/hula-verify`,
  `/hula.merge` → `/hula-merge`, `/hula.launch` → `/hula-launch`,
  `/hula.upload` → `/hula-upload`, `/hula.log` → `/hula-log`,
  `/hula.confirm` → `/hula-confirm`. The Agent Skills spec (which both
  GitHub Copilot and Claude Code natively support) forbids dots in skill
  names. After running `hula init`, the new names are available; the
  legacy `.github/prompts/*.prompt.md` files are no longer generated and
  can be deleted manually if you have them from a prior install.

### Added

- **Agent Skills support** — `hula init` now generates skill files in the
  vendor-neutral standard path `.agents/skills/<name>/SKILL.md` and creates
  a `.claude/skills` symlink pointing to `.agents/skills` so that the same
  files are picked up by **both GitHub Copilot (VS Code) and Claude Code**
  (and 30+ other Agent Skills-compatible tools). Spec:
  https://agentskills.io/specification. The `.claude/skills` symlink
  should be committed so all team members get Claude Code support.

### Removed

- `initializePromptFiles()` and the 9 `src/templates/vscode-*.prompt.md`
  source templates. Their replacements live at
  `src/templates/skills/<name>/SKILL.md`. The old `.github/prompts/`
  directory is no longer generated by `hula init`.

### Fixed

- `hula upload` command reference corrected to `hula chore upload` in
  templates (`src/templates/scripts/hula-launch-run.sh`,
  `src/templates/vscode-upload-prompt.md`,
  `src/templates/vscode-create-prompt.md`) and documentation
  (`docs/vscode-workflow.md`). Without this fix, the auto-upload step
  inside `/hula.launch` failed with `error: unknown command 'upload'`
  because `upload` is registered under the `chore` subcommand group.
  Users who have already run `hula init` must re-run `hula init`
  (with override confirmation) to update their `.github/` files.

### Added

- `hula execute` command — drives the new hula-server Execute Pipeline
  (`/api/v1/execute`, introduced in hula-server PR #225). Supports
  built-in actions (`--built-in harden`) and custom action files
  (`--action-path`), one-off runs and recurring cron schedules
  (`--schedule "0 3 * * *"`), plus management subflags
  `--show`, `--list`, `--list-schedules`, `--cancel-schedule`,
  `--run-now`. Replaces the now-removed `/api/v1/harden-run` endpoint.
- `hula launch` now supports `--update-notification-url <url>` (and the
  `updateNotificationUrl` config field / `HULA_UPDATE_NOTIFICATION_URL`
  env var) to opt into per-task webhook notifications introduced in
  NoStackApp/hula-server PR #183. The server POSTs a single
  notification on every terminal task transition.

### Changed

- Utility/maintenance commands are now grouped under `hula chore
<subcommand>` for a cleaner top-level CLI. Affected subcommands:
  `view`, `track`, `clean`, `close`, `checkout`, `setPriority`,
  `diff`, `watch`, `respond`, `preview`, `logs`, `upload`,
  `worktree`, `project`. Top-level commands remaining: `login`,
  `init`, `create`, `merge`, `launch`, `execute`, `ralph`
  (deprecated alias for `launch`).

### Changed (BREAKING)

- **Plan / Project / Task rename to match hula-project server.**
  Aligns the CLI with hula-project PR #159, which renamed the
  `Repository` model to `Project` and the `Issue` model to `Plan`
  (jobs are now `Tasks` server-side).
  - Server endpoints: `/api/v1/issues*` → `/api/v1/plans*`. Any older
    server is now refused at startup with an `IncompatibleServerError`
    that points operators at this version.
  - Local config: `hulaRepository` → `hulaProject`. The CLI now refuses
    to start if the legacy key is present in `.hublaunch/hublaunch.config.js`.
  - Local tracking file default: `.hublaunch/trackedIssues.json` →
    `.hublaunch/trackedPlans.json`. The CLI auto-renames the legacy
    file the first time it loads config and rewrites the contents to
    schema `version: '3.0'` (renaming `repoOwner`/`repoName` →
    `projectOwner`/`projectName` and dropping per-task `job*` fields).
  - Per-task job-status UI in `hublaunch view` and `hublaunch interactive`
    has been removed. The standalone `/api/v1/ralph-run/<name>/status`
    endpoint and `hublaunch launch --show <name>` continue to work.

  **Upgrade steps for users:**
  1. Update the hula-project server to a build that includes PR #159
     (any release ≥ 2026.04.28 will do).
  2. Edit `.hublaunch/hublaunch.config.js`: rename `hulaRepository:` to
     `hulaProject:` (same value).
  3. Run any `hublaunch` command. The first run automatically renames
     `trackedIssues.json` → `trackedPlans.json` and migrates its contents.

### Fixed

- Fixed `hublaunch clean` and `hublaunch close` failing with HTTP 403
  "You do not have access to this resource" for closed issues tracked by
  other users on the same hula-project server. The server now allows any
  authenticated user to untrack a row whose `githubState === 'closed'`,
  with an audit log entry recorded for non-owner deletes. The CLI handles
  403 responses from older servers gracefully — `close` no longer reports
  the close as failed when only the tracking removal step was denied, and
  `clean` no longer prompts users to retry permanently-denied entries.
- Fixed connection reset errors in long-running background processes (#36)
  - Added retry logic with exponential backoff to `getRepoInfo()` function
  - Added in-memory caching for repository information (5-minute TTL)
  - Enhanced error classification to detect connection reset errors (`ECONNRESET`, `connection reset`, `read tcp`)
  - Improved error messages for network issues during background polling

### Improved

- Background polling now recovers gracefully from network interruptions
- Reduced error message spam during transient network failures
- Added intelligent caching to reduce API calls and survive brief network outages
