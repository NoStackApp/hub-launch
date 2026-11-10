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

# 2. Publish the plan to its feature branch
#    (Optional — /hula-plan does this at plan time and /hula-launch re-runs it
#    automatically, creating the branch from main if needed and refreshing the
#    plan after validation edits.)
#    The push auto-retries (fetch + rebase, up to 3 attempts) if the target
#    branch advances mid-push; a genuine conflict fails fast with a clear message.
hula upload --branch password-reset-support

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
hula update                                           # upgrade however hula was installed
# equivalent manual forms:
curl -fsSL https://hublaunch.site/install.sh | sh     # standalone (curl) install
npm install -g hub-launch@latest                      # or: pnpm add -g hub-launch@latest
```

`hula update` detects how `hula` was installed — a standalone (curl) binary,
pnpm, or npm — and upgrades it in place: a standalone install downloads the
matching binary for the latest release, verifies its checksum, and atomically
replaces itself; a package-manager install installs the latest release from
your home directory and refreshes the global Claude Code slash commands (see
[`hula update`](commands.md#hula-update) for the full behavior, `--check`,
`--manager`, and `--auto`). Any normal command also prints a one-line notice
when a newer version is available.

After upgrading the CLI, re-run `hula init` inside each project to refresh the
bundled Agent Skills and config scaffolding (workflow scripts and instruction
docs now ship with the package, so they update automatically with the CLI):

```bash
cd <your-project>
hula init   # safe to re-run; preserves your keys and team settings
```

The CLI reminds you automatically when a project was initialized with a
different version than the one currently installed.

### Machine-level files

A few pieces of CLI state live in `~/.hublaunch/` (per machine, not per repo):

- **`update-check.json`** — caches the last npm registry answer (`{ latest,
  checkedAt }`) so the "update available" notice checks at most once per 24 h.
  Delete it to force a fresh check; set `HULA_NO_UPDATE_CHECK=1` to disable the
  check entirely.
- **`settings.json`** — global CLI preferences: `autoUpdate` (apply updates
  automatically after a command, asked once by `hula login` / `hula init`, or
  set via `hula update --auto on|off`) and `updateCheck` (set to `false` to turn
  off the daily notice while still allowing manual `hula update`).

Both are created on demand and are safe to delete; a missing or corrupt file is
treated as empty.

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
- **Platform names blocked** — system/internal variables (e.g. `PATH`, `HOME`,
  `PROVIDER_AUTH_TOKEN`, `GITHUB_TOKEN`, `AWS_SECRET_ACCESS_KEY`, anything in the
  `DAYTONA_`/`HULA_`/`RALPH_` families) are always reserved and cannot be
  forwarded.
- **Your coding assistant's own provider key is blocked** — the key HubLaunch
  injects for your configured provider (and its config family) cannot be
  forwarded, so a forwarded value can never shadow the agent's credential. If
  your provider is Claude, that means `ANTHROPIC_API_KEY`,
  `CLAUDE_CODE_OAUTH_TOKEN`, and any `ANTHROPIC_`/`CLAUDE_` variable; the error
  names the exact variable and explains it is the configured provider's key.
- **A *different* service's provider key *can* be forwarded** — e.g. when your
  coding assistant is Claude but your app or an end-to-end test calls OpenAI, you
  may forward `OPENAI_API_KEY`. It is treated like any other project secret:
  encrypted at rest, never logged, and available to your code and e2e stage. The
  agent's own provider env is applied last, so your forwarded key never collides
  with it. (The blocked set follows your launch's provider(s), so switching your
  assistant to OpenAI would then block `OPENAI_API_KEY` and free `ANTHROPIC_API_KEY`.)
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

> **Note — the e2e stage's off-switch is not a `steps.*` key.** The sandbox
> end-to-end stage is governed entirely by the top-level `e2e` block, not by the
> `steps` table above. To turn it off, set `e2e.skip: true` (config), pass
> `--skip-e2e` (per launch), add the `<!-- hula-e2e: skip -->` plan marker, or
> disable it project-wide from the dashboard settings page. There is no
> `steps.e2e` entry.

### `--skip-e2e`

As a per-launch counterpart to the config `e2e.skip`, `hula launch` accepts a
`--skip-e2e` flag that skips the sandbox end-to-end stage for that one invocation
(it wins over whatever `e2e.skip` is set to in config). A plan containing the
`<!-- hula-e2e: skip -->` marker has the same effect for that one launch, and a
project owner can disable the stage for **every** launch from the dashboard
settings page. A skipped stage is reported as **not executed** (never a forced
pass). Precedence: project-wide off (dashboard) > per-launch skip (flag / marker
/ `e2e.skip`) > `e2e.runOnEveryLaunch`.

```bash
# Skip the sandbox end-to-end stage for a single launch
hula launch feature-auth .hublaunch/plans/my-plan.md --skip-e2e
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

## Merge policy

The server attaches a structured **merge assessment** to every launched PR — a
confidence score (0–100, the lowest of five category scores), a verdict
(`ready` / `review` / `blocked` / `unavailable`), the concerns it found, and
recommended end-user test steps. `mergePolicy` in `hublaunch.config.js` declares
what "safe enough to merge" means for the repo:

```js
mergePolicy: { minConfidence: 90, autoMerge: false },
```

- **`minConfidence`** — integer `0–100`; the lowest-category score a PR must
  reach to earn the `ready` verdict. Defaults to `90` when absent.
- **`autoMerge`** — boolean; opt into server-side auto-merge of `ready` PRs.
  Defaults to `false`.
- **`autoMergeRiskClasses`** — optional array of **change-risk classes** allowed
  to auto-merge under the threshold flow (see
  [Change-risk profile](#change-risk-profile)). **Omitting it keeps today's
  behaviour** — the risk gate stays off and threshold auto-merge is unchanged.
  When set, a PR auto-merges only if confidence ≥ threshold **and** every change
  class of the diff is on this allowlist. Recommended starting value: the three
  "loud" classes that announce themselves when wrong —
  `["visible-ui", "visible-cli", "orchestration-loud"]`. Any other class (or the
  never-allowlisted `unknown`) then **needs a human**, even at confidence 100.

Both keys are optional. The value is forwarded to the server on every
`hula launch`. **Precedence:** the config wins over the dashboard setting field
by field; a field absent in both falls back to the server default
(`minConfidence: 90`, `autoMerge: off`, risk gate off).

### How `hula approve` uses it

Before merging, `hula approve` fetches the PR's **stored** assessment (it never
recomputes confidence locally) and gates on it:

- **`ready`** → prints `✓ Merge confidence <n>/100 ≥ threshold <t>` and merges.
- **anything else** (`review`, `blocked`, `unavailable`, or no assessment) →
  prints a warning block with the confidence, threshold, verdict, category
  scores, concerns, and end-user test steps, then:
  - in an interactive terminal, asks `Merge anyway? (y/n)` (default `n`);
  - in a non-interactive context (a script, `hula script approve-remote` with
    stdin redirected), exits with **code 3** and the message
    `Merge confidence <n>/100 is below the threshold <t> (verdict <v>). Re-run
    with --force to merge anyway.`

Pass **`--force`** to skip the prompt / override the gate. The threshold shown
is the assessment's own `threshold`, frozen at launch time, so the gate uses the
value in force when the PR was launched — not the current local config value.

A repo that is not configured for a HubLaunch server skips the gate entirely
(`ℹ️  No HubLaunch server configured — merge confidence not checked.`). Older
servers that don't produce an assessment report `unavailable` and prompt.

### A note on server-side auto-merge

`autoMerge: true` lets the **server** merge a `ready` PR for you. Those merges
happen remotely, so they do **not** run the local `afterMerge` hook and do
**not** fast-forward your local `main`. Run `hula approve` later (it will see the
PR already merged) or `git pull --ff-only` to catch your local checkout up.

The `afterRevert` hook — the symmetric rebuild counterpart of `afterMerge`, run
by `hula revert --merge` after it squash-merges the revert PR — is likewise
**local only**: a server-side auto-merge of a revert PR does not trigger it.

### Change-risk profile

Alongside the 0–100 confidence number, the server derives a **change-risk
profile** — a second, independent signal. Confidence answers *"how sure are we
the change is correct?"*; the risk profile answers a different question: *"if we
were wrong, how loudly would the defect announce itself?"* It is derived
deterministically from the PR diff (paths + hunks), never feeds back into the
confidence number, and is shown everywhere confidence is — the dashboard (a chip
beside the number, hover for the triggering files), `hula view` / `hula info`,
and one extra line on the single confidence PR comment.

A change may carry several classes; the **headline** is the most severe. The
fixed taxonomy, most-severe first:

| Class | Meaning |
|---|---|
| `credentials-env` | touches env/secret handling, reserved-env filtering, or auth |
| `data-schema` | alters `prisma/schema.prisma` or a migration |
| `access-visibility` | changes who may see or do what (ownership / authorization / visibility) |
| `data-write` | creates/updates/deletes/upserts persisted data |
| `external-side-effect` | posts to GitHub/Slack/email or calls an external API with side effects |
| `unknown` | matched no known class — **never** auto-mergeable |
| `orchestration-loud` | worker/queue/dispatcher step that fails loudly on the next run |
| `visible-cli` | CLI output / print path |
| `visible-ui` | dashboard component / UI |

The "quiet-damage" group (the first five) can do damage before anyone notices
and ranks **above** the "loud" group (the last three), which announces itself
immediately. `unknown` sits between them and is never on an allowlist — an
unrecognised change always needs a human when the gate is on. The
`autoMergeRiskClasses` allowlist (above) is the opt-in that turns the gate on;
absent, the profile is **information only** and threshold auto-merge is
unchanged.

### Project maturity stage

On top of the change-risk gate, a project can set a **maturity stage** that
decides *how liberally* a threshold-qualified PR is auto-merged. The stage only
ever acts **inside** the threshold flow (confidence ≥ threshold with the required
evidence present) — it never changes the confidence number, the threshold, or the
"review recommended" label; it only decides whether an otherwise-eligible merge
**waits** for a person. Auto-merge is **never looser than today by default**.

A plan also records an **origin** at creation — who the change came from:
`user-prompt` / `user-backlog` (a person started it) vs `agent-backlog` /
`unknown` (an agent, or an unattributable/legacy item — always treated as
agent-originated, never guessed as a person). The origin is shown as a small
label on the plan page, `hula view`, and the API rows.

| Stage | Auto-merge behaviour |
|---|---|
| *(unset)* | **Exactly today's behaviour** — the change-risk gate only; origin ignored. Every existing project stays here (no backfill). |
| `concept` | **Bypasses the change-risk gate** — a qualified PR merges on its own regardless of risk or origin. The one deliberate loosening; only ever applies when a person explicitly selects it (the settings UI shows a plain warning). |
| `experimental` | Stacks the gates: the risk gate **and** a user-originated plan. Agent/unknown plans **wait** (and raise one follow-up for the plan owner) even when the risk gate passes. The default for *new* projects — stricter than today, never looser. |
| `mature` | **Exactly the change-risk gate** (every change class on `autoMergeRiskClasses`); origin ignored. |
| `robust` | **Never** auto-merges. |

The decision and its one-line reason are shown on the plan page, in `hula info` /
`hula approve` (an `Auto-merge: …` line), and as one extra line on the single
confidence PR comment. Set the stage from the dashboard project settings, or from
the CLI:

```bash
hula project set stage experimental   # concept | experimental | mature | robust
```

Invalid values are rejected (no editor opens). The stage is also exposed through
the API (`hula info`, the status route).

## PR comments

The merge assessment is **HubLaunch-internal** — raw category scores, concerns,
and the full verification report. It is **never posted on the PR**. Instead it
lives in three reader-appropriate places:

- the **dashboard** plan page,
- **`hula info`** (and `hula reassess`),
- the **`hula approve` gate** (described above).

The only HubLaunch line a PR may ever carry about the assessment is an opt-in
one-liner at merge approval, controlled by `prComments` in
`hublaunch.config.js`:

```js
prComments: { mergeAssessment: 'never' }, // default
```

- **`mergeAssessment: 'never'`** (default, and the behaviour when the key is
  absent) — nothing is posted on the PR in any mode.
- **`mergeAssessment: 'final'`** — on your **own-repo** PRs, `hula approve` posts
  exactly one short line after a successful merge:
  `✅ Verified by HubLaunch — details on the dashboard: <link>`. It contains no
  scores or categories, and is posted **only** at merge approval — never during
  the run, on fix rounds, or on contribution (fork) PRs.

The `<!-- hula-e2e-report v1 -->` harness comment (opt-in via `e2e.postReport`)
is a separate, legitimate reader-facing artifact and is unaffected.

### Removing old assessment comments — `hula assessments prune`

Older runs used to post the full merge-assessment comment on the PR. To clean
those up on a project's **open** PRs:

```bash
hula assessments prune                 # dry run — lists what it would delete
hula assessments prune --yes           # actually delete
hula assessments prune --project owner/repo --yes
```

It deletes **only** HubLaunch-authored `<!-- hula-merge-assessment v1 -->`
marker comments, using the same `gh` credentials the rest of the CLI uses. Human
comments and `<!-- hula-e2e-report v1 -->` harness comments are never touched.
Dry-run is the default; `--yes` performs the irreversible deletion.

## Grounding Loop (`groundingLoop` / `--groundUntil` / `--maxGroundingRounds`)

An LLM can only honestly assess what has actually been executed. By default a
launch produces exactly **one** merge-assessment snapshot. The **Grounding Loop**
is an opt-in run mode (default **OFF**) that keeps grounding the assessment with
newly-**executed** evidence until it earns a target confidence: each round names a
concrete *testable* uncertainty, turns it into new `## End-to-End Test Cases`,
runs them, ingests the results as evidence, and reassesses.

Enable it per launch:

```sh
hula launch my-feature --maxGroundingRounds 3 --groundUntil 90
```

- **`--maxGroundingRounds <n>`** — integer `≥ 1`; the hard cap on grounding rounds
  that **enables** the mode. Required to turn grounding on.
- **`--groundUntil <0-100>`** — optional; the confidence to ground up to. When
  omitted it defaults to the resolved merge-confidence threshold (see
  [Merge policy](#merge-policy)).

Out-of-range values exit non-zero with a clear range error. Config equivalent in
`hublaunch.config.js` (the CLI flags override it, field by field):

```js
groundingLoop: { groundUntil: 90, maxGroundingRounds: 3 },
```

The block is `.strict()` — an unknown key or out-of-range value is a config error.
**Precedence:** flag > project config > OFF. With neither present, the request body
is **byte-identical** to a legacy launch.

Each round targets the weakest assessment category that executed evidence can
still move. The agent names concrete *testable* uncertainties behind that score and
writes **one runnable shell check per case**, which the sandbox **executes**. Exit
code 0 means pass. A timeout, a missing command, or a check that would pass
regardless of the code (`true`, `exit 0`, echo-only, a trailing `|| true`) counts as
no evidence.

Because the agent writes these checks itself, a pass is treated as weak evidence and
can raise only two things:

- coverage of a criterion the plan actually lists;
- a model-judged category, which the model re-scores from the executed results. The
  re-score may raise the category only if every check in the round ran and passed.

Passing checks never set the executed-verification tier or the e2e check. Those stay
driven by your project's own regression and e2e commands. A **failing** check is
strong evidence: it blocks the assessment, just as any other failed executed check
does. The server scores every round with the same per-PR evidence aggregate that the
final stored confidence uses.

The loop stops when:

- confidence reaches `groundUntil` (`threshold-reached`), checked before round 1
  too;
- a check fails, or one already failed before round 1 (`check-failed`);
- no testable uncertainty can be named, nothing executes, a round does not move
  the targeted category, or the weakest category is one that executing checks
  cannot change (executed verification, or a category pinned by a deterministic
  rule such as the related-test ratio) — all reported as `grounding-exhausted`;
- the round cap is hit (`round-cap-reached`).

The threshold and round-cap values come from the policy frozen at launch, and the
server rejects a round number above the cap. Every executed check is listed in a PR comment so a reviewer can judge
whether the checks were meaningful. Every round is recorded with its cost (credits
plus measured sandbox minutes) and shown on the launched-plan dashboard next to the
merge assessment, along with a pre-round-1 cost estimate. A per-run **credit
budget** (`--groundingBudget`) is a planned follow-up. v1 enforces the round cap,
the threshold and the diminishing-returns stop, and records each round's cost.

## Settings forward-compatibility

When a newer `hub-launch` adds a setting inside a known block (`e2e`,
`prComments`, `groundingLoop`) and writes it into your project's
`hublaunch.config.js`, an **older** installed CLI that predates the key would
otherwise reject the whole file. To keep your saved login key and other settings
intact across a version skew, the loader is **forgiving but version-gated**:

- An unrecognized setting **inside a known block** is tolerated — dropped with a
  warning that names its full dotted path (e.g. `e2e.runOnEveryLaunch`) — **only
  when** the config declares a CLI `version` newer than the one installed. The
  warning tells you to run `hula update` to actually use the new setting.
- Otherwise (the version is absent, the same, or older — i.e. an up-to-date
  file) an unrecognized setting is a **config error** naming the exact path, so a
  typo still fails loudly. A genuinely invalid **value** for a known setting also
  always fails, naming the path, regardless of the declared version.
- Unknown **top-level** keys keep today's behaviour (silently ignored).

**Maintainer rule:** the published CLI must be **re-released after any change to
the settings schema** (`src/types/config.schema.ts`), so installed CLIs never lag
`main` and reject configs written by newer versions. CI enforces this with
`pnpm run guard:schema-release`, which fails when the schema changed without a
prepared version bump.

## PR-hygiene defaults (`defaults`)

HubLaunch ships five mode-independent **PR-hygiene behaviours** that a careful
contributor — and a careful maintainer — always wants. They are **on by default
for every launch**, no opt-in required. The `defaults` block in
`hublaunch.config.js` lets you opt any of them out, one behaviour at a time:

```js
defaults: {
  styleSurvey: true,            // survey the repo's idioms and match the majority style
  scopeLock: true,              // touch only the files the fix needs — no drive-by changes
  contributingDocs: true,       // read and obey CONTRIBUTING.md and any PR template
  environmentFailureOnce: true, // record an un-runnable env failure once, don't loop on it
  windowsSafeNames: true,       // Windows-safe plan filenames (hyphen, not ":")
},
```

- **`styleSurvey`** — before writing new logic, the agent surveys the codebase's
  dominant idioms (lookup tables vs `switch`, early-return vs nesting, error
  handling, test structure, naming) and writes in the **majority** style even
  when an issue sketches it differently, explaining any departure in one PR-body
  sentence.
- **`scopeLock`** — edits are restricted to the files the fix needs: no drive-by
  refactors, dependency bumps, reformatting, or unrelated fixes.
- **`contributingDocs`** — the agent reads `CONTRIBUTING.md` and any PR template
  and honours them: DCO sign-off (`git commit -s`), a required CLA,
  "discuss in an issue first" rules, and the changelog policy (contributor-edited
  vs maintainer-only).
- **`environmentFailureOnce`** — when the regression step fails for a diagnosed
  environment reason the sandbox cannot satisfy (a missing system library like
  `libnspr4.so`, no display for a GUI/browser test, or no root), HubLaunch
  records it **once** as a factual "could not run, and why" note instead of
  re-running and re-reporting it up to five times.
- **`windowsSafeNames`** — generated plan/lessons filenames use
  `YYYY-MM-DD-HH-MM-<slug>.md` (a hyphen between hour and minute). A `:` is an
  invalid path character on Windows and breaks `actions/checkout` on
  `windows-latest`. Already-committed colon-named plans keep resolving; nothing
  is renamed.

Every key is optional and defaults to `true`. An absent `defaults` block (the
common case) means **all five are on**, so existing configs behave as if they
had opted into every behaviour. The block is forwarded to the server on every
`hula launch` and `hula plan start` and surfaced to the sandbox; a field left at
`true` sends nothing, so legacy request bodies are byte-identical.

## Contribution (guest) mode (`contributionMode` / `--contribution`)

When HubLaunch builds a pull request on a **fork of someone else's** repository
(you fork it, HubLaunch builds on the fork, a human reviews and opens the PR
upstream), the maintainer-grade output HubLaunch produces on its *own* repos is
unwelcome from a guest. **Contribution mode** makes the output acceptable from a
guest. When engaged, a launch:

- keeps **every HubLaunch artifact off the PR branch** — nothing under
  `.hublaunch/` or `.claude/`, no `ralph.md`, `launch.md`, plan file, or lessons;
- **squashes to a single commit** in the repository's own message convention
  (Conventional Commits vs sentence case, auto-detected from recent history),
  with a `Signed-off-by` trailer only when `CONTRIBUTING.md` requires a DCO — and
  **never** an issue/PR number in the commit message or branch name;
- never adapts the repo to the sandbox (no edits to test config, CI workflows,
  lockfiles, or tool config to make the sandbox pass);
- writes a **guest PR body**: a plain summary, the issue/PR reference, a
  **Verification** section reporting only what actually ran (and what could not,
  and why), and a short, product-free disclosure that the change was made with
  AI assistance and reviewed by a person (`linkGuidelines: true` or
  `--link-guidelines` cites the Responsible Contribution Guidelines instead) —
  no "Generated by HubLaunch" banner, no ⚠️ warning boxes, no plan links;
- opens the PR as a **draft**.

```js
// hublaunch.config.js
contributionMode: false,   // true | false | "auto"  (default: false)
```

- **`false`** (the default this release) — contribution mode is off; output is
  byte-identical to before this feature existed.
- **`true`** — always engage the guest behaviours. Use this to opt in on any
  repo, including your own.
- **`"auto"`** — engage **only when the target repo is a GitHub fork** (a repo
  with `fork: true` and a `parent`). The first time it engages automatically on
  a given fork, HubLaunch prints a one-time notice. `"auto"` is fully implemented
  and documented but is **not** the default yet; a future release flips the
  default to `"auto"`.

The **`--contribution`** flag on `hula launch` and `hula plan start` forces
contribution mode on for that run, overriding a `contributionMode: false` config.

The choice is resolved server-side: `"auto"` is resolved against the fork
metadata the server already reads from `GET /repos/{owner}/{repo}`, so the
worker only ever receives a resolved boolean. An off/absent `contributionMode`
is omitted from the request body, so legacy launches stay byte-identical.

See the guide [Contributing to someone else's repository with
HubLaunch](./contributing-to-others.md) for the end-to-end flow.

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

## Backlogs

A **backlog** is a per-chat list of out-of-scope items that surface mid-conversation
in a `/hula-plan`, `/hula-fix`, or `/hula-approve` chat. Each chat keyed by a
model-generated `<key>` (threaded through the chat as an `<!-- hula-backlog: <key> -->`
comment) owns one file:

```
.hublaunch/.backlogs/<key>.json
```

```jsonc
{
  "version": "1.0",
  "key": "bl-m3x9k2p1",
  "createdAt": "2026-10-11T00:00:00.000Z",
  "sessionId": "<real Claude Code session id, or null>",
  "items": [
    {
      "id": "1",                 // local sequential id (display/order independent)
      "text": "Add a retry timeout",
      "status": "open",          // "open" | "done"
      "createdAt": "2026-10-11T00:00:00.000Z",
      "synced": true,            // pushed to the server?
      "remoteId": "blog_abc",    // server item id once synced (null otherwise)
      "origin": "local",         // "local" | "dashboard" | "other-session"
      "remoteStatus": "open",    // last-known server status for a synced item
      "pulledAt": "2026-10-11T01:00:00.000Z",
      "doneAt": "2026-10-11T02:00:00.000Z",
      "type": "plan",            // "plan" | "local" | "note" | "external" (optional; default plan)
      "detail": "# why\n…",      // optional markdown context
      "blockedBy": [             // optional typed blocker refs
        { "kind": "pr", "ref": "NoStackApp/hula-server#747" }
      ]
    }
  ]
}
```

The local file is the source of truth; remote sync is additive and best-effort —
nothing in the backlog flow ever fails the calling skill. Fields beyond
`id`/`text`/`status`/`createdAt` are optional, so files written by older CLI
versions stay valid (`version` remains `"1.0"`).

### Project-level items and states

On the server, backlog items are **project-owned** (not tied to a single plan),
so archiving a chat/session never loses them. A server item carries a richer
state machine than the local file's `open`/`done`:

- **`type`** — `plan` (the only launchable kind) · `local` · `note` · `external`.
- **`status`** — `parked` → `ready` → `planned` → `done`, with `archived`
  reachable from any state. A `plan` item with every `blockedBy` ref resolved is
  `ready` (an orange "progress needed" dot in the dashboard) but **starts
  nothing** on its own — launching is always explicit.
- **`enabled`** — a `false` lever hides an item from default lists, the
  plan-initiate offer, and anything an AI reads, without deleting it.
- **`blockedBy`** — an ordered list of typed refs
  `{ kind: 'plan'|'pr'|'item'|'issue', ref, resolvedAt? }`. PR/issue refs
  (`owner/repo#N`), plan ids, and item ids auto-resolve when the HubLaunch App
  observes them land **on installed repos**; external/uninstalled refs are
  resolved by a manual tick in the dashboard.

The REST/tRPC surface is **dual-accept**: it still takes legacy `open`/`done`
(mapping them to `parked`/`done`) and returns a value older CLIs can read, so
existing CLI versions keep syncing unchanged. Launch a `ready` `plan` item from
the dashboard or with `hula backlog launch <itemId>`: it opens an editable
prompt (prefilled from `text` + `detail`) and, on confirm, starts a remote plan,
sets `launchedPlanId`, and moves the item to `planned`; the item becomes `done`
when that plan merges.

### Dashboard sync

When `hulaApiKey` is set in `.hublaunch/hublaunch.config.js` (the project URL
defaults to the public server when `hulaProjectUrl` is absent), items sync to the
plan's dashboard card two ways:

- **Push** — new local items are sent to the server; `backlog-resync` / `backlog-pull`
  retry any that couldn't be pushed yet (e.g. added before the plan was tracked).
- **Pull** — `backlog-pull` merges the server's items into the file by `remoteId`.

Sync rules:

- **Server status wins for synced items.** A server `done` marks the local item
  `done`; the pull never changes an item's text.
- **Local `done` is pushed back.** If an item is `done` locally but still `open`
  on the server, the pull PATCHes the server to `done` (two-way).
- **Unseen server items are appended** with an `origin` of `dashboard` (no
  session), `other-session` (a different session pushed it), or `local` (this
  chat's session pushed it).
- **Deleted on the dashboard?** A previously-synced *open* item that's gone from
  the server keeps its local copy but drops the stale `remoteId` (so the next
  push re-creates it); a *done* item is left untouched.

### Viewing a backlog

`/hula-approve` ends by printing the chat's open items in a **suggested order**
(smallest independent item first, blocked items listed separately), and
`/hula-followup` prints the same block before its questions. To see any plan's
backlog from another machine or without a chat file:

```text
/hula-help backlog <trackingName>
```

The underlying scripts are `backlog-pull` and `backlog-list` (see
[Commands Reference](commands.md#hula-script-name)).

## Remote planning

`/hula-plan` can run its repo analysis on the hula-server instead of entirely in
your chat session. This lets you "set a plan in motion" and finish it later — or
from a different machine — without keeping the original session alive.

**Modes.** `--remote` forces remote; `--local` forces today's all-local flow.
With neither flag, the mode is auto-detected: **remote** inside Claude Code
(detected by the `CLAUDECODE=1` environment variable, which is the only signal
consulted), **local** in every other harness (GitHub Copilot, a plain terminal,
CI). `--pr` is not supported remotely yet, so it forces local. Remote planning
requires `hulaApiKey` + `hulaProjectUrl` in `.hublaunch/hublaunch.config.js`
(run `hula login`) and a hula-server with the `/api/v1/planning` endpoints; it
costs half a plan's credits.

**The flow (remote).**

```text
/hula-plan "<prompt>"         (Claude Code)
  → hula plan start            POST /api/v1/planning (remote); returns a planId
  → hula plan wait <planId>    background poll (every 20 s, up to 2 h)
  ↓ (the session ends its turn and resumes when the stage changes)
  stage QUESTIONS        → run the /hula-followup flow inline
  stage GENERATE_PLAN /  → "no questions needed — drafting and launching"
        LAUNCHED
```

When the server finds no questions, it drafts and launches the plan on its own;
your session only reports it. Otherwise, the follow-up flow asks the questions,
records the answers (and any follow-up rounds), stores a confirmed
understanding, then asks whether to **plan locally** (you approve the plan
before launch) or let **HubLaunch draft and launch it automatically**.

**`hula plan wait` limits.** It polls every 20 s (minimum 10), for at most 2
hours, and exits on a stage change, a failed/cancelled task, the timeout, or 5
consecutive network failures — so a stuck server can never leave a zombie wait.
It refuses to run outside Claude Code unless you pass `--force`; in other
harnesses you resume manually with `/hula-followup <planId>` when notified.

**`/hula-followup <planId>`.** Resume planning from any checkout of the repo
(that is where the config, API key, and "plan locally" live). It fetches the
server record, asks any unanswered questions, iterates, confirms the
understanding, and runs the local-or-remote choice — identical whether it was
entered automatically from a waiting `/hula-plan` session or run by hand. The
server holds all state; the planId is the only thing the local side needs, so a
dead session loses nothing.

**Local planning still syncs.** Even in `--local` mode (or a non-Claude
harness), `/hula-plan` creates the server record and uploads the context,
questions, answers, understanding, and final plan text with short best-effort
calls, so every plan is backed up on the dashboard. No server credentials → it
skips silently; a failed call → one warning line, and planning continues.

## Stored credentials for web & phone planning

With `saveCredentials: true` in `.hublaunch/hublaunch.config.js`, HubLaunch keeps
a stored credential set so the dashboard and the phone PWA can launch without a
file upload or a hand-typed token. **What is saved** (the exact bundle a launch
sends): your **GitHub token** (re-read from `gh auth token` on every sync), your
**provider key** (`config.provider.apiKey`, or the `--provider-key` /
`PROVIDER_AUTH_TOKEN` fallback a launch would use), the **env vars** you
forward via `envVars` — all stored encrypted on HubLaunch and marked secret so
the dashboard never shows their values — and your **update-notification
settings** (`updateNotificationUrl` / `updateNotificationNameTag`, when set;
stored non-secret so a web/phone launch fires the same Slack/webhook
notification a CLI launch does). Nothing else (plan text, flags, etc.) is
stored by this feature.

Every `hula launch` and remote `hula plan start|draft-and-launch` refreshes the
`default` set **after** the request succeeds, so a failed launch never writes
credentials and a rotated token never goes stale. The sync is best-effort: it
never blocks or fails the command, and prints one hint-only line
(`🔐 Credentials saved to HubLaunch as "default" (GitHub ghp_…k3Q9)`).

**To revoke** stored credentials:

1. Run `hula init web disable` (writes `saveCredentials: false` and, after a
   confirmation, deletes the `default` set from HubLaunch), **or**
2. Delete the set in the dashboard's project settings and set
   `saveCredentials: false` yourself.

Against a hula-server without the `/api/v1/credential-sets` endpoints, every path
reports `server-unsupported` and nothing is stored.

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
| `--verify`          | Merge assessment (confidence, verdict, categories, steps)|
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

## Assessing requests

Before planning a change, `/hula-assess` (and `/hula-plan`, inline) judge whether
the request is a **good idea for the project** — not whether it can be built.
Both follow one shared rubric (`hula instructions assess`), so a local and a
remote assessment read identically.

Five categories, each scored 1–5:

| Category | What it weighs |
| --- | --- |
| Code integrity | Fit with existing architecture; duplication; load-bearing modules; test coverage |
| Project goals | Alignment with stated/inferred goals; scope creep; who it serves |
| Security | New inputs, auth/secrets, injection, new dependencies, data exposure |
| Compatibility | Breaking API/CLI/config/schema/behavior changes; migrations; semver |
| Maintenance burden | Ongoing cost, added surface area, docs and support load |

Labels run **5 Great idea · 4 Good · 3 Safe · 2 Caution · 1 Unwise**. A 5 is the
expected normal; anything below 5 is a concern that must be explained with
`file:line` evidence. The **overall verdict is the lowest category score** (never
an average), so a single serious concern is never hidden behind four good ones.
When any category is below 5, the block is titled **"Honest assessment"** and
includes a concrete **Safer alternative** — a modified goal that keeps the
benefit and drops the drawback. When every category is 5 the title is simply
"Assessment".

Project goals come from `.hublaunch/goals.md` when it exists (a committed file:
an H1 `# Project goals`, a short paragraph, a bullet list, and an optional
`## Non-goals`). When it is absent, goals are inferred from the README and docs,
listed under "Inferred project goals", and the skill offers to write the file so
future assessments and remote planning share the same goals. Assessment output
stays in chat — nothing is posted to GitHub.

```bash
/hula-assess "add a --json flag to hula info"   # a free-text request
/hula-assess --issue 42                          # an open issue
/hula-assess --pr 17                             # an open same-repo PR
```

## Legacy: `/hula-create`

Historically, HubLaunch offered a Free tier (`/hula-create`, which assigned
issues to GitHub Copilot) alongside a Pro tier. The current workflow unifies on
Claude Code via `/hula-launch` for all users. The legacy `/hula-create` command
remains available for backward compatibility but is no longer the recommended
path.
