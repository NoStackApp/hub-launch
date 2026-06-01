# Troubleshooting

Fixes for the most common HubLaunch issues. For authentication-specific problems see [Token Management](token-management.md); for server/tracking issues see [Migration Guide](migration-guide.md#-troubleshooting).

## "hula: command not found" / "hublaunch: command not found"

```bash
# Reload shell config
source ~/.zshrc   # or ~/.bashrc

# Ensure pnpm global bin is in PATH
pnpm setup
source ~/.zshrc

# Or add manually to your shell rc:
export PNPM_HOME="$HOME/.local/share/pnpm"
export PATH="$PNPM_HOME:$PATH"
```

On Windows, run `pnpm bin -g` to find the global bin directory and add it to your PATH.

## Old bash script conflicts

If `hula` still invokes an old script after installing the TypeScript CLI:

```bash
# Look for stale aliases referencing ./scripts/hub-launch and remove them
# from ~/.zshrc or ~/.bashrc

# Then reload
source ~/.zshrc
source <your-project>/.hublaunch/aliases.sh
```

## Start over / clean install

```bash
./uninstall.sh
pnpm run clean
pnpm run build
./install.sh
```

## GitHub CLI version too old

Minimum version is `gh` 2.4.0 (required for GitHub Projects V2):

```bash
gh --version

# macOS
brew upgrade gh

# Windows
winget upgrade GitHub.cli

# Other platforms: https://cli.github.com/
```

## Chromium not installed

`hula preview`, `hula logs`, and `hula respond` all use Playwright. If they fail:

```bash
npx playwright install chromium
# Or re-run init (it offers to install Chromium for you)
hula init
```

## Authentication / Token Errors

See [Token Management — Troubleshooting](token-management.md#troubleshooting) for:

- "Token has expired or is invalid"
- Frequent re-logins
- Refresh failures

Quick recovery:

```bash
hula login
```

## Server Connection / Polling Issues (hula-project)

If hub-launch is configured to talk to a hula-project server (see [Migration Guide](migration-guide.md)) and you see:

```
❌ Failed to connect to hula-project server
```

Verify the server is reachable:

```bash
curl http://localhost:3001/api/v1/plans
```

If not running:

```bash
cd ../hula-project
PORT=3001 pnpm dev
```

Issues not syncing? The remote adapter caches for 10 seconds — restart interactive mode or wait for the cache to expire.

## "You do not have access to this resource" when running `hublaunch clean` or `close`

When a tracked issues list contains entries created by other users on the
same hula-project server, the per-issue `DELETE` calls used to fail with
HTTP 403, leaving rows stuck in tracking forever and making `hublaunch
close <n>` look like it had failed (even though the GitHub close actually
succeeded).

The server now allows any authenticated user to untrack a row whose
`githubState === 'closed'`, so:

- `hublaunch clean` removes closed issues regardless of who originally
  tracked them. A non-owner cleanup is recorded in the server audit log.
- `hublaunch close <n>` exits with code `0` even if the post-close
  tracking removal returns 403 — the GitHub close itself has already
  succeeded, and the server's webhook will catch up the tracking state.

If you still see the 403 warning, the issue is most likely **still open**
on GitHub and tracked by another user. Ask the original tracker (or a
workspace admin) to untrack it, or close the issue first.

## Development Mode Issues

After editing source files:

```bash
cd <hub-launch-repo>
pnpm run build   # rebuild
hula --help      # pick up changes (no reinstall needed — symlinked)
```

## Team Setup

Share HubLaunch with a new team member:

```bash
git clone <repo-url>
cd <project>
./install.sh         # or: pnpm install && pnpm i:hula
source ~/.zshrc
hula init
hula
```

## Still Stuck?

- File an issue: https://github.com/YizYah/hub-launch/issues
- Run commands with `DEBUG=*` for verbose output
- Verify your config: `cat .hublaunch/hublaunch.config.ts`
