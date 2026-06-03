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
- 📋 **Logging** - run `hula-log` for progress in the container. Also pushes several documents within each PR showing logging.
- 🖥️ **Console** - check out the status of all launched plans on our console
- 🔒 **Safe** - tokens are maintained by you locally in your config file, and on our server securely protected and removed when no longer needed.

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
hula create       # create issue from plan
hula --help
```

Full walkthrough: [docs/getting-started.md](./docs/getting-started.md)

## Core Workflow

The primary use case is AI-assisted issue development via the hula-project server:

```bash
# 1. Plan the feature
#    Validation runs automatically in the same session after the plan is saved.
/hula-plan Add password reset support

# 2. Upload the plan to origin/main
#    (Optional — /hula-launch runs this automatically if skipped)
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
| `hula execute` | —     | Trigger or schedule an execute-action (e.g. `--built-in harden`) |

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

Use `--resume <step>` to re-run from a specific step after a failure, without re-doing earlier steps:

```bash
# Resume from step 4 (skips setup, bug review, and commit)
hula launch my-issue .hublaunch/plans/my-plan.md --resume 4

# Resume from step 7 with fix instructions
hula launch my-issue .hublaunch/plans/my-plan.md --resume 7 --fix "address build warning in src/utils/shell.ts"
```

> **Note**: `--fix` requires `--resume` and passes instructions to the AI agent for that stage.

## Documentation

| Document                                     | Description                                     |
| -------------------------------------------- | ----------------------------------------------- |
| [Getting Started](./docs/getting-started.md) | Install, configure, and create your first issue |
| [Commands Reference](./docs/commands.md)     | Every CLI command with options and examples     |

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

- [GitHub Repository](https://github.com/NoStackApp/hub-launch)
- [Issue Tracker](https://github.com/NoStackApp/hub-launch/issues)
- [Documentation](./docs/README.md)

## License

MIT — see [LICENSE](./LICENSE) for details.
