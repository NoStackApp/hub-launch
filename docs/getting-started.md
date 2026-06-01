# Getting Started

This guide walks you through installing HubLaunch, configuring your project, and creating your first issue.

## Prerequisites

- **Node.js** >= 18.0.0
- **pnpm** (or npm) — used for installation and global linking
- **GitHub CLI (`gh`)** >= 2.4.0 — authenticated via `gh auth login`
- **Playwright Chromium** — required for preview deployments, logs, and Copilot interactions: `npx playwright install chromium`

## Installation

### Install from npm (All Platforms)

```bash
npm install -g hub-launch
# or with pnpm
pnpm add -g hub-launch
```

This installs the `hublaunch`, `hula`, and `hl` commands globally.

### Post-Install Setup

**Windows** — Commands are installed but may need to be added to your PATH:

```powershell
pnpm setup
# Restart your terminal afterward
```

If that doesn't work, run `pnpm bin -g` to find the bin directory and add it to your PATH manually.

**macOS / Linux** — Commands should be available immediately. If not:

```bash
pnpm setup
source ~/.bashrc   # or ~/.zshrc
```

### Verify Installation

```bash
hublaunch --version
hula --version
```

Both commands should print the same version.

## Configure Your Project

From the root of your project, run:

```bash
hula init
```

This creates a `.hublaunch/` directory with:

- `hublaunch.config.ts` — your project configuration
- `plans/` — issue plan templates
- `hooks/` (optional) — lifecycle hooks
- `adapters/` (optional) — custom service adapters
- `templates/` (optional) — project-specific templates

It also optionally configures **VS Code auto-approval** (`.vscode/settings.json`) so Copilot Chat stops prompting for every hula, git, and gh command.

The interactive prompts cover editor preference (`cursor` / `vsCode` / `other`), plan directory location, create preference (`chooseRecentPlan` is recommended), number of recent plans to offer, and team members. Accept the defaults to get going quickly — see [Configuration](configuration.md) for the full reference.

## Your First Issue

1. **Create a plan file** under `.hublaunch/plans/`:

    ```bash
    cat > .hublaunch/plans/2026-04-16-my-feature.md <<'EOF'
    # My Feature

    ## Summary
    Brief description.

    ## Requirements
    - Requirement 1
    - Requirement 2

    ## Implementation
    Steps to implement...
    EOF
    ```

2. **Create the GitHub issue** from the plan:

    ```bash
    hula create
    ```

    HubLaunch picks up the plan, creates an issue with Copilot assigned, and adds it to your tracking file.

3. **View your tracked issues**:

    ```bash
    hula view
    ```

    Or launch the interactive TUI:

    ```bash
    hula
    ```

4. **Merge when ready**:

    ```bash
    hula merge
    ```

## Next Steps

- [Commands Reference](commands.md) — every CLI command with its options
- [VS Code Workflow](vscode-workflow.md) — the `/hula-plan → /hula-merge` Copilot Chat flow
