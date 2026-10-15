# hub-launch

> **You just plan and approve. AI does the rest.**

<p align="center">
  <img src="./docs/assets/plan-approve-cycle.svg" alt="The cycle: you plan, AI implements, tests and opens a PR; you approve, AI merges and ships." width="640"/>
</p>

Describe what you want built. HubLaunch drafts an implementation plan with you,
validates it until it's self-contained, then implements it in a clean cloud
sandbox — tests run, PR opened, checked against the plan — and pings you when
it's your turn. Nothing runs on your machine, and nothing touches your current
branch.

## The two commands

Everything happens inside your coding agent (e.g. Claude Code), as slash
commands. There are only two you need.

### 1. Plan

```text
/hula-plan Add password reset support
```

The plan skill asks clarifying questions, studies your codebase, and writes a
detailed implementation plan with acceptance criteria. It then validates the
plan until it stands completely on its own — no hidden chat context — and asks
one question: **ready to launch?**

#### Remote planning

In Claude Code, `/hula-plan` defaults to **remote** planning: the exhaustive
repo analysis and the clarifying questions are produced by the hula-server (for
half a plan's credits). Your session kicks it off, drops a one-line notice, and
ends its turn; when the server has questions it resumes automatically and runs
the follow-up conversation inline (or run `/hula-followup <planId>` from any
checkout of the repo to pick it up anywhere — nothing is lost if the original
session dies). The sandbox runs the same honest assessment as local `/hula-plan`,
so `/hula-followup` shows it first — titled by its overall score, with a
proceed / safer-alternative / stop question when any category scores low and an
offer to save `.hublaunch/goals.md` when none exists. After you confirm the
understanding, you choose: **plan locally**
(you approve the plan before it launches) or let **HubLaunch draft the plan and
launch it automatically**. Pass `--local` to force today's all-local flow (also
the default in harnesses other than Claude Code, and whenever `--pr` is used);
pass `--remote` to force remote. Local planning still backs up its context,
answers, understanding, and plan text to the dashboard when the repo is
configured for hula-server. Remote planning requires a hula-server with the
`/api/v1/planning` endpoints.

Say yes, and the rest is automatic: a GitHub issue is created, a cloud sandbox
implements the plan, runs your checks and tests, opens a pull request, and
verifies the result against the plan — posting a merge-safety score so you know
what you're looking at before you look.

Planning something big? One plan is one PR — if a plan is really several PRs'
worth of work, validation says so and offers to split it into a sequence of
right-sized plans, each independently launched, verified, and approved.

### 2. Approve

```text
/hula-approve
```

Review the verified PR and approve it. HubLaunch merges, closes the issue,
cleans up branches and worktrees, and fast-forwards your local `main`. Plan the
next thing.

That's the whole loop. Everything between the two commands happens without you.

## Why it's different

- **Close your laptop** — work runs remotely in a clean sandbox. Nothing to
  install in your project's environment, nothing hogging your machine; the run
  keeps going when you walk away.
- **Real artifacts, not chat** — every task lands as a GitHub issue, branch,
  and pull request in your repo. Your history reads like engineering, not
  transcripts.
- **Verified before you see it** — every PR is checked against its plan's
  acceptance criteria and scored before it reaches you. Approving is an
  informed decision.
- **Interrupted only on purpose** — you're notified when it's your turn — plan
  ready, PR verified — and only then.

## Setup

```bash
npm install -g hub-launch    # once per machine (or: pnpm add -g hub-launch)
cd <your-project>
hula init                    # configures the project AND logs you in
```

`hula init` is the whole onboarding: it walks you through configuration
interactively, installs the slash commands (Agent Skills) into your project
(so `/hula-plan` and friends are available the next time you open your agent),
and — when you're not already authenticated — flows straight into logging you
in with GitHub + HubLaunch. One command, and you're ready to go. Pass
`--skip-login` to configure without authenticating.

`hula login` still exists for re-authenticating on a machine that's already
set up; it auto-runs `hula init` if the project hasn't been initialized yet.
Either command completes onboarding — whichever you run first, you end up fully
set up.

`hula init` is safe to re-run any time — your keys and team settings are
preserved — and you should re-run it after upgrading the CLI.

That's the only time you'll meaningfully touch the `hula` CLI: the rest of it
exists mostly for your agent to call on your behalf.

**Requirements:** Node.js ≥ 18, the GitHub CLI (`gh`) authenticated via
`gh auth login`, and an LLM provider credential for the sandbox agent — bring
your own model: Claude (subscription Pro/Max or an Anthropic API key), OpenAI, or
400+ models via OpenRouter. Pick one during `hula init`. See
[Choosing your LLM provider](./docs/advanced.md#choosing-your-llm-provider) for
details on all three options and how to switch between them.

**Sandbox image (React Native / Android):** `hula init` also asks what the
project builds and records the answer as `sandboxProfile` in
`.hublaunch/hublaunch.config.js`. `base` (the default) covers Node, Python 3.12
and PHP 8.3; `android` adds JDK 17 & 21, the Android SDK and Ruby + fastlane, so
Gradle builds work in the sandbox. Existing Android projects get `android`
preselected; for a greenfield app, just pick it. Every `hula launch`,
`hula schedule` and `hula error-watcher --create` uses the configured profile;
override one task with `--sandbox-profile base|android|android:17|android:21`.
The question is asked only once per repo — edit the config to change it.
iOS builds are not supported (sandboxes are Linux).

## Updating hula

```bash
hula update          # upgrade to the latest release with your package manager
hula update --check  # just report whether a newer version exists
```

`hula update` detects whether you installed with pnpm or npm (override with
`--manager pnpm|npm`), installs the latest `hub-launch`, refreshes the global
Claude Code slash commands, and prints the new version. It always runs the
install from your home directory, so a repo that pins a specific
`packageManager` can't send the upgrade to the wrong place.

You don't have to remember to run it: any normal `hula` command prints a
one-line notice at the end when a newer version is available (checked at most
once a day). To apply updates automatically, turn on auto-update — `hula login`
and `hula init` ask once, or run `hula update --auto on` (and `--auto off` to
stop). With it on, the upgrade runs **after** your command finishes and tells
you what it did — never in the middle of a command.

Set `HULA_NO_UPDATE_CHECK=1` to silence the check entirely (useful in CI).

> **pnpm users:** pnpm ≥ 10 blocks a package's postinstall until you approve
> builds, which is what refreshes the global `/hula-*` commands on upgrade.
> `hula update` runs that step for you, but to let it happen automatically on
> every future update run `pnpm approve-builds -g` once and select `hub-launch`.

## Planning from the web or your phone

You can plan and launch from the [HubLaunch dashboard](https://hublaunch.site)
or your phone, without uploading a `.env` or typing a token. To do that,
HubLaunch needs a stored set of credentials, and the `hula` CLI already resolves
exactly what a launch needs every time it runs — so it can save them for you.

`hula init` and `hula login` ask once (default **yes**):

```
🌐 Web and phone planning
To plan from the HubLaunch dashboard or your phone, HubLaunch must keep some secrets
permanently, encrypted, in its database: your GitHub token, your provider key, the
env vars you forward to the sandbox and your update-notification settings (the
Slack/webhook URL and name tag). Normally HubLaunch keeps your secrets only while a
launched plan is in flight (until its PR is merged). Enabling this stores them until you
turn it off with `hula init web disable`, which also deletes them from HubLaunch.
```

This writes `saveCredentials: true` to `.hublaunch/hublaunch.config.js`.
Afterwards every `hula launch` and remote `hula plan` refreshes the project's
`default` credential set, so a rotated token never goes stale. The credentials
are already transmitted on every launch; enabling this only changes whether
HubLaunch keeps them.

- Enable at any time: **`hula init web`** (also syncs immediately).
- Disable: **`hula init web disable`** (also deletes the stored set from HubLaunch).
- Push without launching: **`hula credentials sync`** — always re-sends the
  current `gh auth token`, so run it after rotating your GitHub token.
- See what the server holds (hints only, never values): **`hula credentials list`**.

Only hints like `ghp_…k3Q9` are ever printed. See
[`hula credentials`](./docs/commands.md#hula-credentials) and
[revoking stored credentials](./docs/advanced.md#stored-credentials-for-web--phone-planning).

## Notifications

HubLaunch tells you when it's your turn. Set `updateNotificationUrl` in
`.hublaunch/hublaunch.config.js` to any webhook — a Slack channel works out of
the box, and Telegram or anything else works through a tiny bridge:

```js
export const config = {
  // ...
  updateNotificationUrl: "https://hooks.slack.com/services/T0/B0/secret",
};
```

You'll get a message when the task starts, when the issue is created, and when
the PR is ready (with its verification score). See
[Notifications](./docs/notifications.md) for the payloads, a Telegram setup,
and ideas for automating your side of the loop with `hula info`.

## Project goals

State what your project is for in a committed file, `.hublaunch/goals.md`, and
HubLaunch will judge incoming requests against it. Before planning anything,
`/hula-assess` and `/hula-plan` score a request 1–5 on code integrity, project
goals, security, compatibility, and maintenance burden — so when you triage an
issue someone else filed, you see an honest verdict (and a safer alternative
when a score is below 5) before you commit to building it.

The file is plain markdown:

```markdown
# Project goals

A short paragraph on what the project is for and who it serves.

- A concrete goal
- Another goal

## Non-goals
- Something the project deliberately does not do
```

Because it is **committed** (not gitignored like `hublaunch.config.js`), other
maintainers and the remote planning sandbox read the same goals. If the file is
absent, `/hula-assess` and `/hula-plan` infer your goals from the README and
docs and offer to write it for you — commit it so everyone shares one source of
truth.

## Other commands

You'll rarely need these — the two commands above cover the normal loop — but
they're there when you want them:

| Command          | What it's for                                                                       |
| ---------------- | ----------------------------------------------------------------------------------- |
| `/hula-followup` | Answer a remote plan's questions from any checkout and finish planning (`/hula-followup <planId>`) |
| `/hula-fix`      | Fix a gap or bug on the PR branch in an isolated worktree — describe the problem     |
| `/hula-verify`   | Full verification report, criterion by criterion (a summary score is auto-posted)    |
| `/hula-info`     | Peek at a run: live logs, PR diff, initial summary, lessons                          |
| `/hula-launch`   | Launch a plan manually (normally offered automatically after `/hula-plan`)           |
| `/hula-confirm`  | Re-validate a plan you've edited by hand                                             |
| `/hula-upload`   | Sync a plan to its feature branch or `origin/main` (normally automatic)              |
| `/hula-schedule` | Run or schedule autonomous actions (e.g. a nightly `harden` security audit)          |
| `hula error-watcher` | Manage production Error Watchers — inbound error webhooks that auto-launch fix PRs |
| `/hula-help`     | Interactive onboarding and reference — walks through setup, the workflow, or any command/skill |
| `/hula-research` | Research the codebase (or a specific topic) and get a clear, grounded R&D report      |
| `/hula-assess`   | Honest 1–5 verdict on whether a request (or `--issue`/`--pr`) is a good idea before planning it |
| `/hula-create`   | Legacy: create an issue without launching (the modern flow is `/hula-plan` → launch) |

Full details: [Commands Reference](./docs/commands.md) ·
[Advanced Usage](./docs/advanced.md) (launch pipeline internals, resume,
test mode, env forwarding, scheduling).

## Error Watchers

An **Error Watcher** is an inbound webhook: your production app reports an error
to HubLaunch, HubLaunch deduplicates it, and — when the error is new — auto-launches
a fix (a PR, a plan, or a feedback run). Manage watchers from the CLI:

Reporting an error needs **two** pieces, created in different places:

- the **watcher** — the configuration (dedupe window, environments, PR policy,
  agent instructions), managed from the CLI;
- a **project ingest key** — the credential your app presents (`hik_…` plus its
  own signing secret `his_…`), created in the dashboard under **Projects → gear
  icon → Error reporting API keys**.

```bash
# Create a watcher; prints where to mint the ingest key, a .env block, and a
# ready-to-paste signed-request snippet.
hula error-watcher --create --name api-prod

# See what your watchers have been doing, and why each error did or didn't
# launch a fix (omit the id to cover every watcher on the project)
hula error-watcher --events

# List, inspect, patch tuning, or delete
hula error-watcher --list
hula error-watcher --show <watcherId>
hula error-watcher --update <watcherId> --max-fixes-per-day 10
hula error-watcher --update <watcherId> --instructions "Never touch billing/"
hula error-watcher --delete <watcherId>

# Re-print the setup snippet at any time (placeholders only — no secrets, works offline)
hula error-watcher --print-setup
```

Add the printed block to your production environment, filling in the key and
secret from the dashboard:

```bash
HULA_ERROR_WEBHOOK_URL=https://www.hublaunch.site/api/v1/webhooks/error
HULA_INGEST_KEY=hik_…
HULA_INGEST_SECRET=his_…
```

The **key and secret are shown only once** and are never handled by the CLI —
copy them into your deployment's secret store immediately. Every report is signed
with `HMAC-SHA256` over `` `${timestamp}.${body}` `` (the exact payload the printed
snippet produces) and sent as `X-Hula-Api-Key` + `X-Hula-Signature`. Rotate the
secret from the same settings page; the previous one keeps verifying for 24 hours.

Send at least a `key`, `errorName`, or `errorCode` with every report — the dedupe
fingerprint is built from those three fields alone, and a report carrying none of
them shares one bucket with every other such report.

A `409` means the key is valid but the project has no enabled watcher; create one
with `--create`. Requires a hula-server with Error Watcher support; older servers
return a clear "not supported yet" message. Full reference:
[docs/error-watcher.md](./docs/error-watcher.md).

## Multi-repo feature groups

A feature that spans several repositories — say a mobile app plus its backend
API — can be launched as **one correlated group** instead of unrelated jobs you
track by memory. Keep the repos as sibling checkouts under one parent folder,
each already `hula init`'d and `hula login`'d with its own project-scoped API
key:

```
~/code/myapp/
  ├── mobile/   (.git + .hublaunch)
  └── api/      (.git + .hublaunch)
```

Then launch the whole group with one command:

```bash
# Launch the plan in every initialized repo under ~/code/myapp as one group.
# The CLI resolves each repo's newest plan matching the issue name, shows a
# roster, asks once to confirm, then launches each repo with its OWN key plus a
# shared generated groupId (e.g. login-a3f9c1).
hula launch login --folder ~/code/myapp

# Override the auto-resolved plan for one repo (repeatable, path is repo-relative)
hula launch login --folder ~/code/myapp --plan api=.hublaunch/plans/2026-08-10-11:00-login-api.md

# Retry a failed member into the SAME group (idempotent per member)
hula launch login --folder ~/code/myapp --group-id login-a3f9c1

# Combined group status — run inside any member repo, or pass the id explicitly
hula launch --show-group login-a3f9c1

# Stop every member's in-flight task
hula launch login --folder ~/code/myapp --kill
```

| Flag                    | What it does                                                                                       |
| ----------------------- | -------------------------------------------------------------------------------------------------- |
| `--folder <path>`       | Launch the plan in every initialized repo **directly under** `<path>` as one feature group          |
| `--group-id <id>`       | Use/join an explicit group id instead of generating one (`^[A-Za-z0-9_-]{1,64}$`)                   |
| `--plan <repo>=<path>`  | Override the auto-resolved plan for one repo (repeatable; `<path>` is relative to that repo's root)  |
| `--show-group [id]`     | Show combined per-repo status; the id is optional inside a member repo (uses the latest local record)|

> ⚠️ **`hula launch --folder` is NOT the same as `/hula-plan --folder`.** For
> `launch`, `--folder` is the **parent folder that contains your repos**. For
> `/hula-plan`, `--folder` names a **plans subdirectory** inside a single repo.
> The two flags share a name but mean different things — never conflate them.

Each grouped launch is an ordinary single-repo job (billed and gated
individually) that simply carries a shared `groupId`. Grouping and
`--show-group` require a **hula-server with feature-group support**; against an
older server launches still succeed but stay ungrouped and `--show-group`
returns a not-found message.

## Launch from an existing issue or PR

Open-source work usually starts from an issue someone else filed, or from a pull
request that already exists. Instead of writing a plan from scratch, point
`hula launch` at the GitHub source and it builds the plan from the issue or PR
text for you:

```bash
# Take on an existing issue. Branch `issue-42`, plan generated from the issue,
# and the resulting PR links back with `Closes #42`.
hula launch --issue 42

# Continue an existing pull request in THIS repository. The work happens on the
# PR's own head branch and new commits are added on top of what's already there.
hula launch --pr 17

# Open the PR into a non-default base branch (cuts the work branch from it too).
hula launch my-task plan.md --base develop
```

`--issue` and `--pr` accept a number (`42`), a `#`-number (`#42`), or a full
GitHub URL (`https://github.com/<owner>/<repo>/issues/42`). With either flag the
plan file is optional — pass one to use it as the instructions, or omit it to
generate one. A single positional is always the **tracking name**, never a plan
path.

| Flag               | What it does                                                                                     |
| ------------------ | ------------------------------------------------------------------------------------------------ |
| `--issue <ref>`    | Work on an existing issue (number, `#number`, or URL). Never creates or edits the issue.          |
| `--pr <ref>`       | Continue an existing same-repo pull request. Commits the plan to its head branch; fork PRs are rejected. |
| `--base <branch>`  | Cut the work branch from `<branch>` and open the PR into it (default: the repository default branch). |

The same sources work from your coding agent, with a planning step first:
`/hula-plan --issue 42 <extra instructions>` or `/hula-plan --pr 17 <what to
change>` reads the issue or PR, drafts and validates a plan from it, and the
launch that follows carries the `--issue` / `--pr` flag through.

These flags require a **hula-server with launch-from-existing support**; an
older server ignores the extra fields, so the run still starts but the issue/PR
linkage is dropped.

## Demo

<a href="https://www.youtube.com/watch?v=3_mrgaSsRdw" target="_blank">
  <img src="./docs/assets/demo-preview.svg" alt="Watch hub-launch demo on YouTube" width="100%"/>
</a>

> Some command names in the video predate the current flow — the cycle you'll
> use today is the two-command loop above.

## Dashboard

Track all your active plans, runs, and PRs at
[hublaunch.site/dashboard](https://www.hublaunch.site/dashboard). Visit
[hublaunch.site](https://www.hublaunch.site) for plans and pricing.

## Documentation

| Document                                    | Description                                     |
| ------------------------------------------- | ----------------------------------------------- |
| [Commands Reference](./docs/commands.md)    | Every CLI command with options and examples     |
| [Advanced Usage](./docs/advanced.md)        | Pipeline internals, resume, env forwarding      |
| [Notifications](./docs/notifications.md)    | Slack, Telegram, and automating your responses  |

The full documentation index is at [docs/README.md](./docs/README.md).

## Contributing

1. Fork and create a feature branch
2. Run `pnpm run typecheck`
3. Submit a pull request

## Links

- [HubLaunch Website](https://www.hublaunch.site)
- [Dashboard](https://www.hublaunch.site/dashboard)
- [GitHub Repository](https://github.com/NoStackApp/hub-launch)
- [Issue Tracker](https://github.com/NoStackApp/hub-launch/issues)

## License

MIT — see [LICENSE](./LICENSE) for details.
