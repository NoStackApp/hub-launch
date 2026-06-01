# Architecture

Reference for contributors working on HubLaunch itself. End-users should read [Getting Started](getting-started.md) and [Commands Reference](commands.md) instead.

## System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         CLI Entry Point                         │
│                    (bin/hublaunch + index.ts)                   │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                          Command Layer                          │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐           │
│  │ create   │ │ track    │ │ view     │ │ close    │  + more   │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘           │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                     Service Layer (SOLID)                       │
│  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐    │
│  │ IssueService   │  │ PRService      │  │ TrackingService│    │
│  └────────────────┘  └────────────────┘  └────────────────┘    │
│  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐    │
│  │ ProjectService │  │ CopilotService │  │ PlanService    │    │
│  └────────────────┘  └────────────────┘  └────────────────┘    │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Integration Layer                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │ GitHub CLI   │  │ Playwright   │  │ File System  │          │
│  │   (gh)       │  │ (Browser)    │  │   (JSON)     │          │
│  └──────────────┘  └──────────────┘  └──────────────┘          │
└─────────────────────────────────────────────────────────────────┘
```

## Directory Structure

```
hub-launch/
├── bin/
│   └── hublaunch              # Executable entry point
├── src/
│   ├── index.ts               # CLI setup, command registration
│   ├── commands/              # Command implementations (one per command)
│   ├── services/              # Business logic
│   │   ├── github/            # IssueService, PRService, ProjectService, Copilot*
│   │   ├── tracking/          # TrackingService
│   │   ├── plan/              # PlanService
│   │   ├── editor/            # EditorService
│   │   ├── git/               # GitService
│   │   ├── diff/              # DiffService
│   │   └── logs/              # Log service factory + adapters
│   ├── types/                 # Zod schemas + inferred types
│   ├── utils/                 # Pure utility functions
│   ├── config/                # Config loader
│   └── templates/             # Templates copied by `hula init`
├── dist/                      # Compiled JavaScript (generated)
├── install.sh                 # Installer (Unix)
├── uninstall.sh               # Uninstaller
├── package.json
└── tsconfig.json
```

## Technology Stack

| Layer | Technology | Purpose |
|---|---|---|
| Language | TypeScript 5.3+ | Type safety, modern JavaScript |
| CLI Framework | Commander.js 14 | Command parsing, help generation |
| Validation | Zod 3.24 | Schema validation and type inference |
| Prompts | Inquirer 12 | Interactive user input |
| Logging | Chalk 5 | Colored console output |
| Automation | Playwright 1.40 | Browser automation (Copilot, previews) |
| GitHub | GitHub CLI (`gh`) | GitHub API integration |
| Runtime | Node.js 18+ | JavaScript runtime |

## Adding a New Command

1. **Create the command file** in `src/commands/`:

    ```typescript
    // src/commands/mycommand.ts
    import type { Command } from "commander";
    import type { Config } from "../types/index.js";
    import { logger } from "../utils/logger.js";

    export function myCommandCommand(program: Command, config: Config): void {
      program
        .command("mycommand")
        .description("Description of my command")
        .option("-f, --force", "Force the operation")
        .action(async (options) => {
          try {
            logger.info("Executing mycommand...");
            await executeMyCommand(config, options);
            logger.success("Completed!");
          } catch (error) {
            logger.error("Failed to execute mycommand");
            if (error instanceof Error) logger.error(error.message);
            process.exit(1);
          }
        });
    }

    async function executeMyCommand(
      config: Config,
      options: { force?: boolean }
    ): Promise<void> {
      // Implementation
    }
    ```

2. **Register in `src/index.ts`**:

    ```typescript
    import { myCommandCommand } from "./commands/mycommand.js";
    // inside main():
    myCommandCommand(program, config);
    ```

3. **Rebuild and test**:

    ```bash
    pnpm run build
    ./bin/hublaunch mycommand --help
    ```

## Service Layer (SOLID)

### Single Responsibility

Each service has one clear purpose:

```typescript
class IssueService {
  async createIssue() { /* ... */ }
  async getIssue()    { /* ... */ }
}

class TrackingService {
  async addIssue()    { /* ... */ }
  async removeIssue() { /* ... */ }
}
```

### Dependency Inversion

Depend on abstractions, not concrete implementations:

```typescript
interface ITrackingReader {
  getAllIssues(): Promise<TrackedIssue[]>;
}

class TrackingService implements ITrackingReader {
  constructor(private adapter: ITrackingAdapter) {}
}
```

## Type Safety with Zod

```typescript
import { z } from "zod";

export const IssueSchema = z.object({
  number: z.number(),
  title: z.string(),
  status: z.enum(["open", "closed"]),
  priority: z.enum(["Critical", "High", "Medium", "Low", "Minimal"]),
});

export type Issue = z.infer<typeof IssueSchema>;

const issue = IssueSchema.parse(data);      // throws on invalid
const result = IssueSchema.safeParse(data); // { success, data | error }
```

## Error Handling Pattern

Handle errors at the command boundary; let services throw:

```typescript
try {
  const result = await someOperation();
  logger.success("Operation completed");
  return result;
} catch (error) {
  logger.error("Operation failed");
  if (error instanceof Error) {
    logger.error(error.message);
  }
  process.exit(1);
}
```

## Development Workflow

```bash
pnpm install       # install dependencies
pnpm run build     # one-off build
pnpm run watch     # rebuild on change
pnpm run typecheck # tsc --noEmit
pnpm run clean     # remove dist/
```

After running `./install.sh`, the package is globally linked via `pnpm link --global`. You don't need to reinstall between changes — just `pnpm run build` and the new code is picked up on the next invocation.

### Testing Commands

```bash
# After install.sh:
hublaunch --help
hula --version
hula create --help
hula create --plan nonexistent.md   # error path
hula                                 # interactive TUI
```

## Contributor Guidelines

- Use existing service methods before creating new ones
- Validate inputs with Zod schemas
- Log through `utils/logger` (not `console.log`)
- Handle errors at the command boundary
- Prefer `z.infer<typeof Schema>` over manual TypeScript types
- Keep commands thin — real work belongs in services
- Utilities should be pure and stateless

## Related

- [Getting Started](getting-started.md) — user-facing quickstart
- [Commands Reference](commands.md) — the CLI surface contributors extend
- [Hooks & Plugins](hooks-and-plugins.md) — extension points without core changes
