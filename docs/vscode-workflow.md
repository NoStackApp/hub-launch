# VS Code Copilot Integration

Use HubLaunch with VS Code Copilot Chat for AI-assisted development—from planning to merging.

## Prerequisites

Before using these commands, ensure you have:

- ✅ **VS Code** with GitHub Copilot extension installed
- ✅ **HubLaunch** initialized in your project (`hula init`)

## Quick Start

1. Open VS Code in your project
2. Open Copilot Chat (`Cmd+I` on Mac, `Ctrl+I` on Windows/Linux)
3. Type a workflow command like `/hula-plan Add user authentication`

## The Complete Workflow

Here's the typical flow from idea to merged PR:

```
/hula-plan (auto-validates) → /hula-upload → /hula-launch → [Copilot works] → /hula-verify → /hula-merge
```

> 💡 Validation runs automatically at the end of `/hula-plan` in the same session — no separate `/hula-confirm` call required. The `/hula-confirm` command remains available for re-validating an existing plan standalone.

### Step-by-Step Example

```bash
# 1. Describe what you want to build (plan + validation run together)
/hula-plan Add support for private npm registries

# 2. (Optional) Re-validate a plan you've edited by hand
/hula-confirm

# 3. Upload the plan to origin/main
/hula-upload

# 4. Launch the issue with a branch name
/hula-launch npm-registry-support

# 5. (Copilot creates PR automatically)

# 6. If fixes are needed on the PR
/hula-fix the auth token validation is failing

# 7. Verify all acceptance criteria are met
/hula-verify

# 8. Merge and clean up
/hula-merge
```

## Commands Reference

### `/hula-plan` - Generate Implementation Plan

Creates a detailed implementation plan from your description.

**Usage:**

```
/hula-plan Add support for private npm registries
```

You will be prompted for an optional **folder** to organize related plans together. Nested folders are supported (e.g. `auth`, `refactoring/v2`, `integrations/github`). Leave empty to save in the root plans directory.

**What Copilot generates:**

- Problem statement and motivation
- Proposed solution approach
- Detailed implementation steps
- Testing strategy
- Documentation updates needed

After saving the plan, `/hula-plan` **automatically proceeds to validation** in the same session — running the same workflow as `/hula-confirm`, including any MCQ clarification questions and auto-fixes. No separate command is required.

**Output:**

```
✅ Plan created: `.hublaunch/plans/2025-12-22-14:30-npm-registry-support.md`
<!-- hula-plan: .hublaunch/plans/2025-12-22-14:30-npm-registry-support.md -->

📋 Proceeding to validation now…
```

With a folder specified (e.g. `integrations`):

```
✅ Plan created: `.hublaunch/plans/integrations/2025-12-22-14:30-npm-registry-support.md`
<!-- hula-plan: .hublaunch/plans/integrations/2025-12-22-14:30-npm-registry-support.md -->
```

> 💡 **Tip**: The special HTML comment tag lets Copilot reference the plan in subsequent commands.

---

### `/hula-confirm` - Re-Validate an Existing Plan

> ℹ️ **You usually don't need to run this manually.** `/hula-plan` automatically runs the validation workflow in the same session after saving the plan. Use `/hula-confirm` when you want to re-validate a plan you've edited by hand, or to resume validation if the auto-continue step was interrupted.

**Usage:**

```
/hula-confirm
```

Or specify a specific plan file:

```
/hula-confirm .hublaunch/plans/2025-12-22-14:30-npm-registry-support.md
```

**What happens:**

1. Copilot analyzes the plan for completeness
2. Identifies gaps in technical details, edge cases, and requirements
3. Asks targeted clarifying questions
4. Updates the plan with your responses

**When to use it standalone:**

- You hand-edited a plan after `/hula-plan` finished and want to re-validate
- Auto-validation was interrupted and printed the recovery message
- You want a second validation pass before `/hula-upload`

**Benefits:**

- Catches missing edge cases and error scenarios
- Clarifies vague requirements and implementation details
- Ensures plans are implementation-ready

---

### `/hula-upload` - Upload Plan to origin/main

Uploads the plan from the local worktree to the remote main branch.

**Usage:**

```
/hula-upload
```

**What happens:**

1. Finds the plan path from the current chat context
2. Plan upload is now handled automatically by `hula launch` — no separate upload step is needed
3. Confirms successful upload

**Output:**

```
✅ Plan uploaded to origin/main

📄 **Plan**: `.hublaunch/plans/2025-12-22-14:30-npm-registry-support.md`
🔗 **Status**: Synced to remote

<!-- hula-uploaded: .hublaunch/plans/2025-12-22-14:30-npm-registry-support.md -->
```

> 💡 **Why upload?** Plans need to be on `origin/main` so that Copilot can access them when working on the issue.

---

### `/hula-launch` - Launch Issue from Plan

Creates a GitHub issue from the plan and assigns Copilot to implement it.

**Usage:**

```
/hula-launch npm-registry-support
```

**What happens:**

1. Finds the plan path from the current chat context
2. Checks if the plan is synced to origin/main
3. If not synced, prompts to run `/hula-upload` first
4. Creates the GitHub issue and assigns Copilot
5. Outputs the issue number for future reference

**Output:**

```
✅ Launched issue #42 on branch `npm-registry-support`

📋 **Issue**: YizYah/hub-launch#42
🌿 **Branch**: `npm-registry-support`
📄 **Plan**: `.hublaunch/plans/2025-12-22-14:30-npm-registry-support.md`

<!-- hula-issue: 42 -->
```

> 💡 **Tip**: The issue number is stored in the chat context for subsequent commands like `/hula-fix`.

---

### `/hula-create` - Create GitHub Issue from Plan

Creates a GitHub issue from the plan in the current chat.

**Usage:**

```
/hula-create npm-registry-support
```

With optional flags:

```
/hula-create npm-registry-support --priority High --handoff johndoe
```

**Features:**

- Reads plan file path from chat history (from `/hula-plan` output)
- Creates GitHub issue with title from plan
- Tracks issue locally with provided name
- Assigns Copilot automatically
- Optional handoff to team member for follow-up

**Output:**

```
✅ Created issue YizYah/hub-launch#42 (tracked as 'npm-registry-support')
<!-- hula-issue: 42 -->
```

**Available Flags:**

- `--handoff <username>` - Assign to team member (Copilot always assigned)
- `--priority <level>` - Set priority (Critical, High, Medium, Low, Minimal)

---

### `/hula-fix` - Fix Issues on PR Branch

Apply fixes to an issue on its PR branch with full chat context.

**Usage:**

```
/hula-fix the auth token validation is failing
```

Or with explicit issue number (for fresh chat):

```
/hula-fix YizYah/hub-launch#42 the validation logic throws an error
```

**Workflow:**

1. Checks for uncommitted changes (errors if found)
2. Auto-detects issue # from chat history or uses explicit number
3. Stores original branch for later restoration
4. Checks out PR branch via `hula checkout`
5. Applies fixes using full codebase context
6. Auto-commits with Copilot-generated message
7. Pushes changes to remote

**Output:**

```
📍 Stored original branch: `main`
<!-- hula-session: {"originalBranch": "main", "issueNumber": 42} -->
```

> ⚠️ **Important**: Commit or stash changes before using `/hula-fix` to avoid conflicts.

---

### `/hula-verify` - Verify PR Implementation Against Plan

Verify that the PR implementation matches all acceptance criteria from the plan.

**Usage:**

```
/hula-verify
```

Or with explicit issue number (for fresh chat):

```
/hula-verify 42
```

**What it does:**

1. Auto-detects issue number from chat or uses explicit input
2. Fetches issue details and plan from issue body
3. Finds the associated PR
4. Parses acceptance criteria and implementation steps from plan
5. Analyzes PR changes (files, tests, documentation)
6. Generates detailed verification report with pass/fail status
7. Optionally posts report as PR comment mentioning @copilot

**Report includes:**

- ✅ Met acceptance criteria with evidence (files changed, tests added)
- ⚠️ Partially met criteria needing review
- ❌ Missing criteria with recommendations
- Summary of implementation completeness
- Specific action items to address gaps

**Sample Output:**

```
## 🔍 Verification Report for Issue #42

**Issue**: Add user authentication system
**PR**: #123 - Implement user authentication
**Status**: open (ready for review)

### Acceptance Criteria

✅ **AC1**: Users can sign up with email and password
   - Evidence: Changes in `src/auth/signup.ts`
   - Tests: Added `src/auth/signup.test.ts`

❌ **AC2**: Password reset functionality
   - Missing: No password reset implementation found
   - Recommendation: Add password reset flow

### Summary
- **Acceptance Criteria**: 2/4 met, 1 partial, 1 missing
- **Overall Status**: ⚠️ NEEDS ATTENTION

📝 Post this verification to PR as a comment for @copilot to review? (y/n)
```

**Benefits:**

- Ensures all planned features are implemented
- Catches incomplete implementations early
- Provides clear checklist for Copilot to address gaps
- Saves manual PR review time

---

### `/hula-merge` - Merge PR and Restore Branch

Merge the PR, close the issue, and restore your original branch.

**Usage:**

```
/hula-merge
```

**Workflow:**

1. Reads session from chat history or `.hublaunch/.fix-session.json`
2. Checks for uncommitted changes to commit
3. Asks about running tests (if changes exist)
4. Commits and pushes changes (if any)
5. Merges PR via `hula merge` CLI (closes issue automatically)
6. Restores original branch
7. Cleans up session file

**Features:**

- Skips commit step if no changes
- Prompts to run tests before pushing
- Handles merge conflicts and CI failures gracefully
- Always restores original branch, even on failure

---

## Customization

### Planning Instructions

Edit `.hublaunch/planning-instructions.md` to customize:

- Plan structure and format
- Code style preferences
- Project-specific guidelines
- Required sections

**About Prompt Files**: The prompt file at `.github/prompts/plan.prompt.md` contains the system instructions that Copilot uses when generating plans. It defines the plan template, required sections, and formatting rules. You can modify this file to adjust how Copilot structures and writes implementation plans for your project.

### Confirmation Instructions

Edit `.hublaunch/proceed-instructions.md` to customize:

- Gap detection patterns
- Question templates
- Analysis criteria
- Update strategies

**About Prompt Files**: The prompt file at `.github/prompts/proceed.prompt.md` contains the system instructions for the confirmation workflow. It tells Copilot how to analyze plans, what questions to ask, and how to identify gaps. Customize this file to tailor the confirmation process to your team's needs.

---

## Reducing Approval Dialogs

VS Code Copilot Chat agent mode prompts you with an "Allow" / "Run zsh command?" dialog for every terminal command the agent runs. For hula workflows this can mean 7+ dialogs per command. There are three ways to reduce or eliminate them.

### Option 1: Workspace Auto-Approval Settings (Recommended)

Run `hula init` and accept the **"Configure VS Code auto-approval for hula agent commands?"** prompt. This creates `.vscode/settings.json` with a `chat.tools.terminal.autoApprove` configuration that whitelists known hula, git, and gh commands.

If you prefer to add the settings manually:

```jsonc
// .vscode/settings.json
{
  "chat.tools.terminal.autoApprove": {
    "/^hula\\b/": true,
    "/^git (status|log|diff|fetch|show|branch|worktree list|rev-parse|remote)\\b/": true,
    "/^git (add|commit|push|checkout|worktree add|worktree remove)\\b/": true,
    "/^gh (issue view|pr list|pr view|pr diff|repo view)\\b/": true,
    "/^gh pr (comment|merge)\\b/": true,
    "/^bash \\.github\\/scripts\\/hula-/": true,
    "/^(ls|cat|head|tail|wc|echo|mkdir|rm -f|cd|pwd)\\b/": true
  }
}
```

> Requires VS Code 1.99+. Older versions silently ignore the setting.

### Option 2: Session-Level Bypass

Use the permissions dropdown in the Copilot Chat panel to select **"Bypass Approvals"** or **"Autopilot (Preview)"** for the current session. This applies to all terminal commands, not just hula's.

You can also type `/yolo` in Copilot Chat to toggle auto-approval for the session.

### Option 3: Script Consolidation (Automatic)

HubLaunch prompts already bundle multiple terminal commands into bash scripts (deployed to `.github/scripts/` by `hula init`). Even without auto-approval settings, each workflow uses at most 2–3 terminal commands instead of 7–10.

| Command | Without Scripts | With Scripts |
|---|---|---|
| `/hula-fix` | 7+ dialogs | 2 dialogs |
| `/hula-verify` | 5–6 dialogs | 1–2 dialogs |
| `/hula-merge` (Path A) | 8–10 dialogs | 1–2 dialogs |

### Security Considerations

- Auto-approval patterns are **workspace-scoped** (`.vscode/settings.json`), not global
- Patterns are restrictive — only specific commands, not wildcards
- Users must explicitly opt in via `hula init` or manual configuration
- Session-level bypass and Autopilot require explicit selection each session
- For high-security environments, consider VS Code's terminal sandboxing feature

---

## Tips & Best Practices

### 🎯 For Best Results

1. **Be specific in `/hula-plan`**: Include context, requirements, and constraints
2. **Use folders to organize plans**: Group related plans using the optional folder parameter (e.g. `auth`, `api/v2`)
3. **Auto-validation runs after `/hula-plan`**: Catch issues before implementation. Answer the MCQ questions when prompted in the same session. Use `/hula-confirm` standalone to re-validate after hand-edits.
4. **Leverage chat history**: Commands auto-detect previous context
5. **Use `/hula-verify` before merging**: Prevent incomplete implementations
6. **Keep chat focused**: One feature/issue per chat session

### 🔧 Troubleshooting

**Issue: Copilot can't find the plan file**

- Make sure you ran `/hula-plan` in the same chat session
- Or explicitly provide the plan file path to `/hula-confirm` or `/hula-create`

**Issue: `/hula-fix` says "uncommitted changes"**

- Commit or stash your changes before running the command
- Run `git status` to check what needs to be committed

**Issue: `/hula-merge` can't find session**

- The session is stored in chat history or `.hublaunch/.fix-session.json`
- Make sure you ran `/hula-fix` in the same chat or that the session file exists

**Issue: Commands not showing in Copilot Chat**

- Verify you ran `hula init` in your project
- Check that `.github/prompts/*.prompt.md` files exist
- Restart VS Code to reload the prompts

---

## Complete Example: End-to-End

Here's a real-world example of using the full workflow:

```bash
# 1. Plan: You want to add OAuth support
/hula-plan Add Google OAuth authentication for user login

# Copilot generates a detailed plan with:
# - OAuth flow diagram
# - Required environment variables
# - Implementation steps
# - Testing strategy

# 2. Auto-validation runs immediately in the same session:
# Copilot asks:
# - "Should we support multiple OAuth providers or just Google?"
# - "Do we need to migrate existing email/password users?"
# - "What should happen if OAuth email doesn't match existing user?"

# You answer the questions, Copilot updates the plan
# (No separate /hula-confirm command needed. Run /hula-confirm only to re-validate later.)

# 3. Create: Make the GitHub issue
/hula-create oauth-support --priority High

# Copilot creates issue #42 and assigns itself

# 4. (Copilot automatically creates PR #123)

# 5. Fix: You notice the callback URL is wrong
/hula-fix the OAuth callback URL should use HTTPS in production

# Copilot checks out the PR branch, fixes the code, commits and pushes

# 6. Verify: Check if everything's implemented
/hula-verify

# Copilot generates report:
# ✅ OAuth login flow implemented
# ✅ Tests added
# ⚠️ Environment variables documented but not in .env.example
# ❌ Migration script for existing users missing

# You add the migration script and update .env.example

# 7. Merge: All done!
/hula-merge

# Copilot merges the PR, closes issue #42, restores your branch
```

---

## Related Documentation

- [Commands Reference](commands.md) — the CLI commands these prompts wrap
- [Hooks & Plugins](hooks-and-plugins.md) — custom lifecycle hooks
- [Token Management](token-management.md) — GitHub token configuration

---

**Need help?** Open an issue at [github.com/YizYah/hub-launch/issues](https://github.com/YizYah/hub-launch/issues)
