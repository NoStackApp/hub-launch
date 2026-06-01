# Commands Reference

Complete reference for every HubLaunch CLI command.

## Quick Reference

| Command | Alias | Description |
|---|---|---|
| `hublaunch` | `hula`, `hl` | Main CLI entry point / interactive mode |
| `hula login` | — | Authenticate with GitHub + hula-project |
| `hula init` | — | Initialize configuration |
| `hula create` | — | Create issue from plan file |
| `hula merge` | — | Merge PR and clean up |
| `hula launch` | — | Trigger a launch job on hula-project server |
| `hula execute` | — | Trigger or schedule an execute-action (e.g. `--built-in harden`) |

### Shell Shortcuts

If you used `./install.sh`, additional shell aliases are sourced from `.hublaunch/aliases.sh`:

```bash
hula-create   hula-view    hula-track    hula-close
hula-merge    hula-checkout hula-priority hula-project
hula-init     hula-help
```

## Global Options

```bash
hublaunch --version   # print version
hublaunch --help      # show all commands
hublaunch <cmd> --help # show options for a specific command
```

---

## `hublaunch` (Interactive Mode)

Launch the interactive TUI with a paginated issue list, search, and actions menu.

```bash
hublaunch   # or: hula
```

**List-level keys**

- `1-9` — Select issue by index
- `n` / `p` — Next / previous page
- `/term` — Filter issues
- `a` — Admin menu
- `?` — Help
- `q` — Quit

**Issue actions (once selected)**

- `i` — Open in browser
- `p` — Open plan file
- `v` — Preview deployment
- `d` — View diff
- `r` — View PR in browser
- `w` — Watch tests
- `c` — Checkout PR branch
- `m` — Merge PR
- `s` — Set priority
- `u` — Untrack
- `o` — Respond to Copilot
- `x` — Close & untrack

**Admin menu**

- `i` — Track existing issues
- `n` — Create new issue
- `t` — View test results
- `c` — Clean closed issues

---

## `hublaunch create`

Create a GitHub issue from a plan file with Copilot assigned.

```bash
hublaunch create                  # Interactive: pick plan, assign team
hublaunch create username         # Assign to a specific user
hublaunch create --plan file.md   # Use a specific plan file
hublaunch create --no-copilot     # Skip Copilot assignment
hublaunch create --no-track       # Don't add to tracking
```

---

## `hublaunch track`

Add existing GitHub issues to local tracking.

```bash
hublaunch track        # Interactive: multi-select
hublaunch track 123    # Track a specific issue by number
```

---

## `hublaunch view`

View tracked issues, grouped and formatted.

```bash
hublaunch view                          # all tracked issues
hublaunch view --status inProcess       # filter by status
hublaunch view --priority High          # filter by priority
```

**Status values:** `unassigned`, `initialWaiting`, `waiting`, `ready`
**Priority values:** `Critical`, `High`, `Medium`, `Low`, `Minimal`

---

## `hublaunch close`

Close an issue on GitHub and remove it from tracking.

```bash
hublaunch close                  # Interactive
hublaunch close 123              # Close issue #123
hublaunch close 123 --no-remove  # Keep in tracking
```

---

## `hublaunch clean`

Remove closed or merged issues from tracking.

```bash
hublaunch clean            # Interactive confirmation
hublaunch clean --force    # Skip confirmation
```

Issues tracked by other users on the same hula-project server can be
cleaned **once they are closed on GitHub**. Open issues owned by other
users are skipped automatically — only the original tracker (or a
workspace admin) can untrack those.

---

## `hublaunch init`

Initialize HubLaunch configuration. See [Configuration](configuration.md) for what gets created.

```bash
hublaunch init            # Interactive setup
hublaunch init --force    # Overwrite existing config
```

---

## `hublaunch checkout`

Checkout the PR branch for a tracked issue.

```bash
hublaunch checkout                   # Interactive
hublaunch checkout 123               # Checkout PR for issue #123
hublaunch checkout 123 --new-branch  # Create a new branch if no PR exists
```

---

## `hublaunch merge`

Merge a PR, delete the branch, and update tracking.

```bash
hublaunch merge                  # Interactive
hublaunch merge 123              # Merge PR for issue #123
hublaunch merge 123 --no-delete  # Keep branch after merge
hublaunch merge 123 --no-untrack # Keep issue in tracking
```

---

## `hublaunch setPriority`

Set a priority label on a tracked issue.

```bash
hublaunch setPriority 123 High
hublaunch setPriority 123 Critical
```

---

## `hublaunch diff`

View PR code changes with clickable file links.

```bash
hublaunch diff                     # Interactive
hublaunch diff 123                 # Diff for issue #123
hublaunch diff 123 --editor cursor # Open files in Cursor
```

---

## `hublaunch watch`

Monitor a PR for Copilot completion and test results. Provides an interactive menu for testing, viewing diffs, and communicating with Copilot.

```bash
hublaunch watch                                        # Interactive
hublaunch watch 123                                    # Watch issue #123
hublaunch watch 123 integrationTest/addCalling.jest.int.ts  # Auto-run test on start
hublaunch watch 123 --interval 30                      # Check every 30 seconds
```

**Interactive menu**

- `d` — View diffs
- `t` — Run test (posts `/test` and monitors GitHub Actions)
- `o` — Respond to Copilot
- `q` — Quit

---

## `hublaunch respond`

Respond to Copilot on an issue.

```bash
hublaunch respond              # Interactive
hublaunch respond 123          # Respond on issue #123
hublaunch respond 123 --approve
```

---

## `hublaunch preview`

Open the PR deployment preview with automated login (uses the `deploymentStartup` hook if configured).

```bash
hublaunch preview       # Interactive
hublaunch preview 123   # Open preview for issue #123
```

---

## `hublaunch project`

Manage GitHub Projects V2 integration.

```bash
hublaunch project setup     # Interactive setup
hublaunch project list      # List available projects
hublaunch project info 1    # Get project #1 details
```

---

## `hublaunch login`

Authenticate with GitHub and (optionally) the hula-project server. See [Migration Guide](migration-guide.md) for server mode.

```bash
hublaunch login                     # Authenticate with GitHub
hublaunch login --url <server-url>  # Also link to a hula-project server
```

---

## `hublaunch logs`

View logs by request ID. Alias: `hula g`.

```bash
hublaunch logs <requestId>
```

Requires a configured log service (see [Configuration](configuration.md)).

---

## `hublaunch worktree`

Manage git worktrees associated with tracked issues. Run `hublaunch worktree --help` for available subcommands.

---

## `hublaunch upload`

Upload a plan file to `origin/main` so it can be accessed by the hula-project server when launching.

```bash
hublaunch upload                          # Upload the most recent plan
hublaunch upload .hublaunch/plans/my-plan.md  # Upload a specific plan
```

The command creates a temporary worktree from `origin/main`, commits the plan file, pushes it, then removes the worktree. Your local working tree is untouched.

> **Note**: This step is handled automatically by `/hula-upload` in the VS Code workflow.

---

## `hublaunch launch`

Trigger a launch job on the hula-project server. Alias: `hula launch`.

```bash
hublaunch launch <issueName> <planPath>
hublaunch launch --show <name>     # Show job status
hublaunch launch --logs <name>     # Show job logs
```

Selected options:

| Flag | Description |
| --- | --- |
| `--update-notification-url <url>` | Webhook URL POSTed by the server on every terminal task transition. Falls back to the `updateNotificationUrl` config field, then `HULA_UPDATE_NOTIFICATION_URL` env var. |

Run `hublaunch launch --help` for the full option list.

---

## `hublaunch execute`

Trigger or schedule an `execute-action` on the hula-project server. Used for built-in
actions like `harden` (security audit) or custom action files. Replaces the older
`/api/v1/harden-run` endpoint.

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
```

Either `--built-in <name>` or `--action-path <path>` is required (mutually exclusive).
The Daytona API key is required and resolved from `--daytona-key`, `config.daytonaApiKey`,
or the `DAYTONA_API_KEY` env var. The target project is resolved from `--project`,
`config.hulaProject`, or the current git remote.

Selected options:

| Flag | Description |
| --- | --- |
| `--built-in <name>` | Built-in action name (e.g. `harden`) |
| `--action-path <path>` | Repo-relative path or `https://` URL to a custom action file |
| `--entry-point <path>` | Entry point for the action (file, directory, or URL) |
| `--outcome-type <type>` | `pr`, `plan`, or `feedback` (built-in actions default from server registry) |
| `--schedule <cron>` | Cron expression — creates a recurring schedule instead of a one-off run |
| `--project <owner/repo>` | Override the target repository |

Run `hublaunch execute --help` for the full option list.

---

## Related

- [Configuration](configuration.md) — options that affect command behavior
- [VS Code Workflow](vscode-workflow.md) — equivalent commands via Copilot Chat
- [Hooks & Plugins](hooks-and-plugins.md) — extend commands with lifecycle hooks
