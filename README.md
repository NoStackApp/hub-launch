# hub-launch

GitHub Issue and PR automation CLI with a plugin/hook system for project-specific customizations.

## Features

- 🚀 **Interactive TUI** — paginated issue list with keyboard shortcuts for all actions
- 🤖 **AI-Powered Workflow** — plan → launch → verify → merge with GitHub Copilot
- 🔄 **PR Automation** — create, watch, merge, and clean up pull requests end-to-end
- 🌿 **Worktree Isolation** — issues run in isolated git worktrees, keeping your branch clean
- 📋 **GitHub Projects V2** — native board integration with priority and status tracking
- 🔌 **Plugin System** — extend with custom lifecycle hooks and service adapters
- 🖥️ **VS Code Copilot Chat** — full `/hula-plan → /hula-merge` slash-command workflow

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
hula              # interactive mode
hula create       # create issue from plan
hula --help
```

Full walkthrough: [docs/getting-started.md](./docs/getting-started.md)

## Core Workflow

The primary use case is AI-assisted issue development via the hula-project server:

```bash
# 1. Plan the feature (in VS Code Copilot Chat)
#    Validation runs automatically in the same session after the plan is saved.
/hula-plan Add password reset support

# 2. Upload the plan to origin/main
/hula-upload

# 3. Launch — creates the issue and starts the AI coding session
/hula-launch password-reset-support

# 4. (AI coding agent works on the issue, creates a PR automatically)

# 5. Apply any fixes needed on the PR branch
/hula-fix the email validation is rejecting valid addresses

# 6. Verify all acceptance criteria are met
/hula-verify

# 7. Merge and clean up
/hula-merge
```

> 💡 `/hula-confirm` remains available as a standalone command for re-validating a plan you've edited by hand.

Or directly via CLI:

```bash
hula launch password-reset-support .hublaunch/plans/2026-05-07-17:00-password-reset.md
```

## Commands

Top-level commands:

| Command | Alias | Description |
|---|---|---|
| `hublaunch` | `hula`, `hl` | Main CLI / interactive mode |
| `hula login` | — | Authenticate with GitHub + hula-project |
| `hula init` | — | Initialize configuration |
| `hula create` | — | Create issue from plan file |
| `hula merge` | — | Merge PR and clean up |
| `hula launch` | — | Trigger AI coding session on hula-project server |
| `hula execute` | — | Trigger or schedule an execute-action (e.g. `--built-in harden`) |

Run `hula <command> --help` for details, or see the full [Commands Reference](./docs/commands.md).

## VS Code Copilot Chat

After `hula init`, use these slash commands in Copilot Chat for the full AI-assisted development workflow:

| Command | Description |
|---|---|
| `/hula-plan <description>` | Generate a detailed implementation plan **and auto-run validation in the same session** |
| `/hula-confirm` | Runs automatically after `/hula-plan`; invoke standalone to re-validate a plan you've edited |
| `/hula-upload` | Sync the plan to origin/main |
| `/hula-launch <name>` | **Start the AI coding session** — triggers full server-based pipeline |
| `/hula-create <name>` | Create a GitHub issue only (no server session) |
| `/hula-fix <problem>` | Apply fixes on the PR branch |
| `/hula-verify` | Check all acceptance criteria are met |
| `/hula-merge` | Merge PR, close issue, and restore your branch |

Full walkthrough: [docs/vscode-workflow.md](./docs/vscode-workflow.md).

## `hula launch` and Resume

`hula launch` submits a job to the hula-project server, which runs an AI coding agent (Claude Code) through a fixed 9-step pipeline:

| Step | Description |
|---|---|
| 1 | Change to worktree directory (worktree is created before the pipeline starts) |
| 2 | Bug review & fix loop (LLM-based review with iterative fixes) |
| 3 | Commit remaining changes |
| 4 | TypeScript / lint check (`pnpm check`) |
| 5 | Production build (`pnpm build`) |
| 6 | Regression tests |
| 7 | Push branch to origin |
| 8 | Merge latest main |
| 9 | Cleanup & create PR |

Use `--resume <step>` to re-run from a specific step after a failure, without re-doing earlier steps:

```bash
# Resume from step 4 (skips setup, bug review, and commit)
hula launch my-issue .hublaunch/plans/my-plan.md --resume 4

# Resume from step 7 with fix instructions
hula launch my-issue .hublaunch/plans/my-plan.md --resume 7 --fix "address build warning in src/utils/shell.ts"
```

> **Note**: `--fix` requires `--resume` and passes instructions to the AI agent for that stage.

## Documentation

| Document | Description |
|---|---|
| [Getting Started](./docs/getting-started.md) | Install, configure, and create your first issue |
| [Commands Reference](./docs/commands.md) | Every CLI command with options and examples |
| [Configuration](./docs/configuration.md) | Config file, env vars, polling, init options |
| [VS Code Workflow](./docs/vscode-workflow.md) | Copilot Chat `/hula-*` commands |
| [Hooks & Plugins](./docs/hooks-and-plugins.md) | Lifecycle hooks and custom service adapters |
| [Token Management](./docs/token-management.md) | GitHub tokens, storage, and refresh flow |
| [Migration Guide](./docs/migration-guide.md) | Switching to the hula-project server |
| [Architecture](./docs/architecture.md) | For contributors: structure, patterns, SOLID |
| [Troubleshooting](./docs/troubleshooting.md) | Common issues and fixes |

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

See [docs/architecture.md](./docs/architecture.md) for project structure, SOLID patterns, and how to add a new command.

## Links

- [GitHub Repository](https://github.com/NoStackApp/hub-launch)
- [Issue Tracker](https://github.com/NoStackApp/hub-launch/issues)
- [Documentation](./docs/README.md)

## License

MIT — see [LICENSE](./LICENSE) for details.
