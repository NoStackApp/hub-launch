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

Once per machine:

```bash
npm install -g hub-launch    # or: pnpm add -g hub-launch
hula login                   # authenticate with GitHub + HubLaunch
```

Once per project:

```bash
cd <your-project>
hula init
```

`hula init` walks you through configuration interactively and installs the
slash commands (Agent Skills) into your project, so `/hula-plan` and friends are
available the next time you open your agent. It's safe to re-run any time —
your keys and team settings are preserved — and you should re-run it after
upgrading the CLI.

That's the only time you'll meaningfully touch the `hula` CLI: the rest of it
exists mostly for your agent to call on your behalf.

**Requirements:** Node.js ≥ 18, the GitHub CLI (`gh`) authenticated via
`gh auth login`, and a Claude subscription (Pro or Max) for the sandbox agent.

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

## Other commands

You'll rarely need these — the two commands above cover the normal loop — but
they're there when you want them:

| Command          | What it's for                                                                       |
| ---------------- | ----------------------------------------------------------------------------------- |
| `/hula-fix`      | Fix a gap or bug on the PR branch in an isolated worktree — describe the problem     |
| `/hula-verify`   | Full verification report, criterion by criterion (a summary score is auto-posted)    |
| `/hula-info`     | Peek at a run: live logs, PR diff, initial summary, lessons                          |
| `/hula-launch`   | Launch a plan manually (normally offered automatically after `/hula-plan`)           |
| `/hula-confirm`  | Re-validate a plan you've edited by hand                                             |
| `/hula-upload`   | Sync a plan to `origin/main` (normally automatic during launch)                      |
| `/hula-schedule` | Run or schedule autonomous actions (e.g. a nightly `harden` security audit)          |
| `/hula-help`     | Interactive onboarding and reference — walks through setup, the workflow, or any command/skill |
| `/hula-create`   | Legacy: create an issue without launching (the modern flow is `/hula-plan` → launch) |

Full details: [Commands Reference](./docs/commands.md) ·
[Advanced Usage](./docs/advanced.md) (launch pipeline internals, resume,
test mode, env forwarding, scheduling).

## Demo

<a href="https://www.youtube.com/watch?v=4-YRVB7mQZ8" target="_blank">
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
