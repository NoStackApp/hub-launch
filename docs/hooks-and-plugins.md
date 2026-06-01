# Hooks & Plugins

HubLaunch's plugin system lets projects extend core behavior without forking. It has two parts:

1. **Hooks** — scripts that run at specific lifecycle points (preview, merge, etc.)
2. **Service adapters** — pluggable implementations for logs, deployment, and authentication

## Key Principles

- ✅ All hooks are **optional** — commands work without them
- ✅ Hooks receive **context as JSON** (first CLI argument)
- ✅ Hook failures **don't block** main operations (logged as warnings)
- ✅ Hooks can be **TypeScript or JavaScript**
- ✅ Service adapters must implement standard interfaces

## Directory Structure

```
.hublaunch/
├── hublaunch.config.ts              # Core configuration
├── trackedPlans.json               # Issue tracking data
├── hooks/                           # Lifecycle hooks (optional)
│   ├── deploymentStartupScript.ts   # Preview authentication
│   ├── deploymentShutdownScript.ts  # Preview cleanup
│   ├── beforePreview.ts             # Pre-preview hook
│   ├── afterPreview.ts              # Post-preview hook
│   ├── beforeMerge.ts               # Pre-merge validation
│   ├── afterMerge.ts                # Post-merge actions
│   └── README.md                    # Hook documentation
├── adapters/                        # Custom service adapters (optional)
│   ├── logs/
│   │   └── customLogService.ts      # Custom log provider
│   └── deployment/
│       └── customDeployment.ts      # Custom deployment integration
└── templates/                       # Project-specific templates (optional)
    ├── issue-template.md
    └── pr-template.md
```

---

## Hooks

### Available Hooks

| Hook | Trigger | Use Cases |
|---|---|---|
| `deploymentStartup` | Before opening preview | Authentication, browser setup |
| `deploymentShutdown` | After preview closes | Cleanup, session end |
| `beforePreview` | Before preview opens | Pre-flight checks, setup |
| `afterPreview` | After preview closes | Cleanup, notifications |
| `beforeMerge` | Before merging PR | Validation, pre-merge checks |
| `afterMerge` | After successful merge | Notifications, cleanup |

### Execution Model

Hooks run in one of two modes:

1. **Synchronous (blocking)** — HubLaunch waits for completion before continuing
2. **Background (non-blocking)** — runs without blocking the main process

`deploymentStartup` runs in background mode so the CLI can return while a preview browser stays open.

### Hook Context

All hooks receive context as a JSON string in the first CLI argument:

```typescript
interface HookContext {
  issueNumber?: number;      // Associated issue number
  prNumber?: number;         // Associated PR number
  deploymentUrl?: string;    // Preview deployment URL
  prTitle?: string;          // PR title
  prUrl?: string;            // PR URL
  targetBranch?: string;     // Target branch for merge
  [key: string]: unknown;    // Additional context
}
```

### Creating Custom Hooks

All hook files must:

1. Use the `.ts` extension (or `.js`)
2. Accept context as the first CLI argument (JSON string)
3. Handle errors gracefully (try/catch)
4. Exit with code 0 on success, non-zero on failure

#### Basic Template

```typescript
#!/usr/bin/env tsx
/**
 * Custom Hook Template
 * Receives context as first CLI argument (JSON string)
 */

interface HookContext {
  issueNumber?: number;
  prNumber?: number;
  deploymentUrl?: string;
  [key: string]: unknown;
}

async function main() {
  const contextJson = process.argv[2];

  if (!contextJson) {
    console.error("Error: No context provided");
    process.exit(1);
  }

  const context: HookContext = JSON.parse(contextJson);
  console.log("Hook executing with context:", context);

  try {
    // Your custom logic here
    console.log("✅ Hook completed successfully!");
  } catch (error) {
    console.error("❌ Hook failed:", error);
    process.exit(1);
  }
}

main().catch((error) => {
  console.error("❌ Hook failed:", error);
  process.exit(1);
});
```

#### Example: Clerk Authentication (deploymentStartup)

```typescript
#!/usr/bin/env tsx
import { chromium } from "@playwright/test";

interface HookContext {
  deploymentUrl: string;
  issueNumber?: number;
  prNumber?: number;
}

async function main() {
  const context: HookContext = JSON.parse(process.argv[2]);
  console.log(`🚀 Starting preview for: ${context.deploymentUrl}`);

  const headless = process.env.CI === "true";
  const browser = await chromium.launch({ headless });
  const page = await browser.newPage();

  try {
    await page.goto(context.deploymentUrl);
    await page.waitForSelector("[data-clerk-id]", { timeout: 5000 });
    await page.click('button:has-text("Sign in")');

    const email = process.env.TEST_USER_EMAIL;
    const password = process.env.TEST_USER_PASSWORD;
    if (!email || !password) {
      throw new Error("Required: TEST_USER_EMAIL and TEST_USER_PASSWORD");
    }

    await page.fill('input[name="identifier"]', email);
    await page.click('button:has-text("Continue")');
    await page.fill('input[name="password"]', password);
    await page.click('button:has-text("Continue")');
    await page.waitForURL(`${context.deploymentUrl}/**`, { timeout: 10000 });

    console.log("✅ Successfully logged in!");
    // Leave browser open for the developer to use
  } catch (error) {
    console.error("❌ Login failed:", error);
    await browser.close();
    process.exit(1);
  }
}

main().catch(console.error);
```

#### Example: Pre-Merge Validation

```typescript
#!/usr/bin/env tsx

interface HookContext {
  prNumber: number;
  targetBranch: string;
}

async function main() {
  const context: HookContext = JSON.parse(process.argv[2]);
  console.log(`🔍 Validating PR #${context.prNumber}...`);

  const { execSync } = await import("child_process");
  try {
    execSync("npm test", { stdio: "inherit" });
    console.log("✅ All tests passed!");
  } catch {
    console.error("❌ Tests failed - blocking merge");
    process.exit(1);
  }
}

main().catch(console.error);
```

#### Example: Post-Merge Notifications

```typescript
#!/usr/bin/env tsx

interface HookContext {
  prNumber: number;
  prTitle: string;
  targetBranch: string;
}

async function main() {
  const context: HookContext = JSON.parse(process.argv[2]);
  console.log("📣 Notifying team about merge...");

  await fetch(process.env.SLACK_WEBHOOK_URL!, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      text: `✅ PR #${context.prNumber} merged to ${context.targetBranch}!\n${context.prTitle}`,
    }),
  });

  console.log("✅ Team notified!");
}

main().catch(console.error);
```

### Debugging

Run a hook manually to test it:

```bash
# Test with sample context
tsx .hublaunch/hooks/deploymentStartupScript.ts '{"deploymentUrl":"https://example.com","prNumber":123}'

# Enable debug output
DEBUG=true tsx .hublaunch/hooks/deploymentStartupScript.ts '{"deploymentUrl":"https://example.com"}'
```

---

## Service Adapters

Adapters let you plug custom providers into HubLaunch. Two categories are currently supported:

- **Log services** — implement `ILogService` (used by `hula logs`)
- **Deployment services** — deployment URL / status lookup (used by `hula preview`)

### Log Service Providers

| Provider | Status | Description |
|---|---|---|
| `vercel` | ✅ Built-in | Vercel deployment logs |
| `cloudwatch` | 🚧 Planned | AWS CloudWatch logs |
| `datadog` | 🚧 Planned | Datadog log aggregation |
| `custom` | ✅ Supported | Your own implementation |

### Custom Log Adapter

All log adapters must implement `ILogService`:

```typescript
interface ILogService {
  readonly name: string;
  isConfigured(): boolean;
  fetchLogs(requestId: string): Promise<LogResult>;
}
```

Example:

```typescript
// .hublaunch/adapters/logs/customLogService.ts
import type { ILogService, LogResult } from "hublaunch/services/logs";

export default class CustomLogService implements ILogService {
  readonly name = "custom";

  isConfigured(): boolean {
    return Boolean(process.env.CUSTOM_LOG_TOKEN);
  }

  async fetchLogs(requestId: string): Promise<LogResult> {
    const response = await fetch(`https://your-log-service.com/logs/${requestId}`, {
      headers: { Authorization: `Bearer ${process.env.CUSTOM_LOG_TOKEN}` },
    });

    const data = await response.json();

    return {
      requestId,
      timestamp: new Date().toISOString(),
      serviceName: this.name,
      entries: data.entries,
      raw: JSON.stringify(data, null, 2),
    };
  }
}
```

Configure in `hublaunch.config.ts`:

```typescript
export const config = {
  services: {
    logs: {
      provider: "custom",
      customPath: ".hublaunch/adapters/logs/customLogService.ts",
    },
  },
};
```

### Custom Deployment Adapter

Deployment adapters have a lighter interface — they expose the deployment URL and related metadata for a PR.

```typescript
// .hublaunch/adapters/deployment/customDeployment.ts
export default class CustomDeploymentService {
  readonly name = "custom";

  isConfigured(): boolean {
    return Boolean(process.env.CUSTOM_DEPLOY_TOKEN);
  }

  async getDeploymentUrl(prNumber: number): Promise<string> {
    const response = await fetch(`https://your-platform.com/deployments/pr-${prNumber}`, {
      headers: { Authorization: `Bearer ${process.env.CUSTOM_DEPLOY_TOKEN}` },
    });
    const data = await response.json();
    return data.url;
  }
}
```

Configure in `hublaunch.config.ts`:

```typescript
export const config = {
  services: {
    deployment: {
      provider: "custom",
      customPath: ".hublaunch/adapters/deployment/customDeployment.ts",
    },
  },
};
```

All adapters must:

1. Implement the appropriate interface
2. Export a default class
3. Expose a unique `name` property
4. Implement `isConfigured()`

---

## Configuration

### Full Example

```typescript
// .hublaunch/hublaunch.config.ts
export const config = {
  editorCommand: "cursor" as const,
  planPath: ".hublaunch/plans",
  trackingFile: ".hublaunch/trackedPlans.json",
  createIssuesPreference: "chooseRecentPlan" as const,
  planChoices: 5,

  services: {
    logs: {
      provider: "vercel",
      vercel: {
        // Reads from env: VERCEL_TOKEN, VERCEL_TEAM_ID, VERCEL_PROJECT_ID
      },
    },
    deployment: { provider: "vercel" },
    authentication: { provider: "clerk" }, // "clerk" | "auth0" | "custom" | "none"
  },

  hooks: {
    deploymentStartup: ".hublaunch/hooks/deploymentStartupScript.ts",
    beforeMerge: ".hublaunch/hooks/beforeMerge.ts",
    afterMerge: ".hublaunch/hooks/afterMerge.ts",
  },

  browserHeadless: "auto", // "auto" | "always" | "never"
} as const;
```

### Environment Variables

Store sensitive values outside the repo:

```bash
# .env (gitignored)
TEST_USER_EMAIL=test@example.com
TEST_USER_PASSWORD=your-test-password
VERCEL_TOKEN=your-vercel-token
VERCEL_TEAM_ID=your-team-id
VERCEL_PROJECT_ID=your-project-id
CUSTOM_LOG_TOKEN=your-api-token
```

---

## Best Practices

1. **Error handling** — wrap hook logic in try/catch and exit non-zero on failure so HubLaunch can log a warning.
2. **No hardcoded secrets** — read from `process.env` and throw with a helpful message if required values are missing.
3. **Clear logging** — print what the hook is about to do and an ✅/❌ summary at the end.
4. **Graceful degradation** — hook failures don't block the CLI, so design hooks to fail loudly but safely.

---

## Troubleshooting

**Hook not found**

```
Hook not found: .hublaunch/hooks/deploymentStartupScript.ts
```

Ensure the file exists and the path in `hublaunch.config.ts` matches.

**Permission denied**

```
Error: EACCES: permission denied
```

```bash
chmod +x .hublaunch/hooks/deploymentStartupScript.ts
```

**Context parsing error**

```
SyntaxError: Unexpected token
```

Make sure your hook parses the first CLI argument as JSON: `JSON.parse(process.argv[2])`.

**Playwright / Chromium missing**

```bash
npx playwright install chromium
```

**Headless mode in CI**

```typescript
const headless = process.env.CI === "true";
```

For more general issues see [Troubleshooting](troubleshooting.md).

---

## Contributing

Contributions welcome for:

- New service adapters (CloudWatch, Datadog, etc.)
- Additional hook examples
- Documentation improvements

See the repository's [issue tracker](https://github.com/YizYah/hub-launch/issues) to get involved.
