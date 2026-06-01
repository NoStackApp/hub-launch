# Configuration

HubLaunch reads project-level configuration from `.hublaunch/hublaunch.config.ts`. Run `hula init` to generate this file interactively.

## Config File Location

```
<your-project>/
└── .hublaunch/
    └── hublaunch.config.ts
```

## Minimal Configuration

```typescript
// .hublaunch/hublaunch.config.ts
export const config = {
  editorCommand: "cursor" as const,
  planPath: ".hublaunch/plans",
  trackingFile: ".hublaunch/trackedPlans.json",
  createIssuesPreference: "chooseRecentPlan" as const,
  planChoices: 5,
  skipUntrackedPrompt: false,
} as const;
```

## Full Configuration Reference

```typescript
export const config = {
  // Editor
  editorCommand: "cursor" as const, // "cursor" | "vsCode" | "other"

  // Paths
  planPath: ".hublaunch/plans",
  trackingFile: ".hublaunch/trackedPlans.json",

  // Issue creation behavior
  createIssuesPreference: "chooseRecentPlan" as const, // "alwaysLatest" | "chooseRecentPlan"
  planChoices: 5, // number of recent plans to show

  // Tracking behavior
  skipUntrackedPrompt: false, // skip prompt for untracked assigned issues

  // Team members (optional) — used for assignment prompts
  teamMembers: ["user1", "user2", "user3"],

  // Services (optional)
  services: {
    logs: { provider: "vercel" }, // "vercel" | "custom" | ...
    deployment: { provider: "vercel" },
    authentication: { provider: "clerk" }, // "clerk" | "auth0" | "custom" | "none"
  },

  // Lifecycle hooks (optional) — see hooks-and-plugins.md
  hooks: {
    deploymentStartup: ".hublaunch/hooks/deploymentStartupScript.ts",
    beforeMerge: ".hublaunch/hooks/beforeMerge.ts",
    afterMerge: ".hublaunch/hooks/afterMerge.ts",
  },

  // Browser automation
  browserHeadless: "auto", // "auto" | "always" | "never"

  // GitHub Projects V2 (optional, deprecated in favor of hula-project)
  projectNumber: 1,
  projectId: "PVT_...",
  projectAutoSync: true,
  pollIntervalSeconds: 300, // default 5 minutes

  // hula-project server (optional) — see migration-guide.md
  hulaProjectUrl: "http://localhost:3001",
  hulaApiKey: "hula_sk_...",

  // Webhook notifications for `hula launch` (optional)
  // updateNotificationUrl: "https://hooks.slack.com/services/T0/B0/secret",

  // Command aliases (optional)
  commandAliases: {
    primary: ["hula", "hub-launch", "hl"],
  },

  // Priority levels (optional)
  priorityLevels: [
    { name: "Critical", color: "red", emoji: "🔴" },
    { name: "High", color: "orange", emoji: "🟠" },
    { name: "Medium", color: "yellow", emoji: "🟡" },
    { name: "Low", color: "green", emoji: "🟢" },
    { name: "Minimal", color: "gray", emoji: "⚪" },
  ],

  // Issue sorting (optional)
  issueSortOrder: {
    groupBy: "priority", // "priority" | "status" | "none"
    sortBy: "created", // "created" | "updated" | "number"
    direction: "desc", // "desc" | "asc"
  },
} as const;
```

## Top-Level Fields

**`updateNotificationUrl`** *(optional, string)* — Default URL for webhook notifications sent by hula-server when a launched task reaches a terminal state. Overridden by `--update-notification-url` and by the `HULA_UPDATE_NOTIFICATION_URL` env var. The value is sent as-is; the server validates it must be `http:` or `https:`. See the hula-server API.md `Task Update Webhooks` section for the payload contract.

## Environment Variables

Store secrets and per-machine values in your shell environment or a local `.env` file (gitignored):

```bash
# Vercel (required when services.logs.provider = "vercel")
VERCEL_TOKEN=your-token
VERCEL_TEAM_ID=your-team-id
VERCEL_PROJECT_ID=your-project-id

# Preview authentication (consumed by deploymentStartup hooks)
TEST_USER_EMAIL=test@example.com
TEST_USER_PASSWORD=your-password

# GitHub App (used by `hula login`)
GITHUB_APP_CLIENT_ID=Iv...
```

## Background Polling

When `projectAutoSync: true` is enabled, HubLaunch's interactive mode polls Copilot status using a single batch GraphQL query (≈1 API call per cycle instead of 30–40). Tune it with `pollIntervalSeconds`:

```typescript
export const config = {
  projectAutoSync: true,
  pollIntervalSeconds: 120, // 2 minutes. Recommended: 60–300
} as const;
```

## `hula init` Options

```bash
hula init           # interactive
hula init --force   # overwrite existing config
```

The init command:

- Writes `hublaunch.config.ts` based on your answers
- Creates `plans/`, `hooks/`, `adapters/`, and `templates/` directories as needed
- Generates VS Code prompt files under `.github/prompts/` (see [VS Code Workflow](vscode-workflow.md))
- Optionally writes `.vscode/settings.json` with auto-approve patterns for hula agent commands

## Related

- [Commands Reference](commands.md) — commands that consume this config
- [Hooks & Plugins](hooks-and-plugins.md) — `hooks` and `services` setup
- [Migration Guide](migration-guide.md) — `hulaProjectUrl` and `hulaApiKey` fields
