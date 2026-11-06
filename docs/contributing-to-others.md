# Contributing to someone else's repository with HubLaunch

HubLaunch's default output is tuned for a repository **you maintain**: it leaves
plan files, lessons, a multi-commit "attempt N" history, and a detailed
machine-written PR body that a maintainer finds useful on their own project.
When you are a **guest** — building a pull request against a repository you do
not own — that same output is unwelcome.

**Contribution mode** makes HubLaunch's output acceptable from a guest. This
guide walks the end-to-end flow.

## Quick start: `hula contribute`

The fastest way in is one command, which forks the upstream, clones your fork,
writes a guest config, and guides the rest:

```bash
curl -fsSL https://hublaunch.site/install.sh | sh   # or: npm install -g hub-launch
hula contribute https://github.com/<owner>/<repo>
```

It leaves you in a fork clone that is ready for contribution mode. See
[`hula contribute`](./commands.md#hula-contribute) for every flag and the
idempotent re-run behaviour. The sections below explain what that setup does and
the flow from there; you can also do each step by hand.

## The flow

1. **Fork the upstream repository** on GitHub (`upstream/project` →
   `you/project`). `hula contribute` does this for you, creating or reusing your
   fork.
2. **Clone your fork** (not the upstream) and point HubLaunch at it. This matters
   for authentication: `hula login` requires **write** access on `origin` (the
   write-access gate in the auth exchange), and you have write on your fork but
   not on the upstream. A plain upstream clone is read-only and cannot log in, so
   always work from the fork clone — which is exactly what `hula contribute`
   leaves you with (`origin` = fork, `upstream` = parent).
3. **Launch with `--contribution`:**

   ```bash
   hula launch fix-the-bug .hublaunch/plans/2026-10-28-fix-the-bug.md --contribution
   ```

   or set it once in `hublaunch.config.js` (what `hula contribute` writes):

   ```js
   contributionMode: true,   // true | false | "auto"
   ```

   When you launch `--contribution` against a repo you lack push access to,
   HubLaunch **creates (or reuses) your fork**, enables Actions on it, mutes its
   notifications, builds and runs CI on the fork branch, and opens the draft PR
   there.
4. **Review the single-commit draft PR on your fork.** HubLaunch opens the PR
   against your fork's default branch. Read the diff and polish the title/body
   directly on GitHub — the fork PR is the source of truth from here on.
5. **Submit it upstream.** When you are happy, run

   ```bash
   hula submit-upstream fix-the-bug
   ```

   (or click **Submit upstream** on the plan in the dashboard). HubLaunch copies
   the fork PR's **current** title and body verbatim into a new PR against
   `upstream/project`, rewriting only the issue reference (the fork says
   "Upstream issue #N" in words; the upstream PR gets `Closes #N`). You are the
   author of record; a human reviewed the change before it reached the
   maintainer. Submitting upstream is always a deliberate human action — it is
   never triggered automatically.

## The contribution lifecycle

A contribution plan carries a persisted stage, separate from the owner-flow
lifecycle, that moves through:

```
draft_on_fork → submitted_upstream → awaiting_maintainer
                                        ├─ changes_requested
                                        ├─ merged_upstream   (terminal)
                                        ├─ declined          (terminal)
                                        └─ withdrawn         (terminal)
```

- **draft_on_fork** — the draft PR is open on your fork (set at launch).
- **submitted_upstream → awaiting_maintainer** — `hula submit-upstream` opened
  the upstream PR; HubLaunch stores its number/URL and the console/`hula status`
  link switches to the upstream PR.
- **changes_requested** — a maintainer requested changes. Their review comments
  are shown **read-only** with a link to the thread; HubLaunch never feeds a
  maintainer's comment text to the agent. You edit the plan and trigger the fix
  run yourself. (`author_association` gates only *who* may trigger a run.)
- **merged_upstream / declined** — detected by polling the public upstream PR
  with your token (the upstream repo has no HubLaunch App installed). On either
  outcome HubLaunch fast-forwards your fork's default branch from upstream.

Because a contribution plan is built on a fork, the owner-flow **Approve /
auto-merge / merge-confidence** controls are hidden in the dashboard **and**
rejected server-side — a fork PR is never merged from HubLaunch.

### Archiving a contribution plan

Forks often have issues disabled, so a contribution plan may have no issue
number. Archive it by its tracking name:

```bash
hula archive fix-the-bug          # resolves by tracking name
hula archive 1234                 # the issue-number form still works
```

`hula archive` is a HubLaunch-only soft close; it never touches GitHub.

## What contribution mode changes

When engaged, a launch:

- **Keeps HubLaunch artifacts off the PR branch.** Nothing under `.hublaunch/`
  or `.claude/`, no `ralph.md`, `launch.md`, plan file, or lessons reaches the
  branch. HubLaunch keeps what it needs server-side (the Task record) and in its
  run-log upload — none of it on the branch. Files the project already has at
  those paths (its own `.claude/` settings, say) are left exactly as they are.
- **Squashes to one commit.** The whole branch collapses into a single commit in
  the repository's **own** message convention — Conventional Commits
  (`fix: …`) or plain sentence case — auto-detected from the repo's recent
  history. No "attempt N" history.
- **Signs off only when required.** A `Signed-off-by` trailer is added **iff**
  the repo's `CONTRIBUTING.md` requires a DCO; otherwise it is omitted.
- **Never puts an issue/PR number in the commit or branch name.** The reference
  lives in the PR body only.
- **Never adapts the repo to the sandbox.** HubLaunch will not edit test config,
  CI workflows, lockfiles, or tool config to make the sandbox pass. When
  something genuinely cannot run in the sandbox, it is recorded honestly as
  "could not run, and why" rather than worked around.
- **Writes a guest PR body:** a plain-words summary, the issue/PR reference, a
  **Verification** section listing the commands that actually ran (and anything
  that could not, with the reason), and a short disclosure. By default the
  disclosure is **generic and product-free** — "This change was made with AI
  assistance and reviewed by a person before this pull request was opened." No
  product name, no link, no "Generated by HubLaunch" banner, no ⚠️ warning
  boxes, no plan links. (Field evidence: PRs that named a product were closed as
  spam; a PR with no product pitch was merged with thanks.) See
  **`linkGuidelines`** below to opt into citing the Responsible Contribution
  Guidelines instead.
- **Opens the PR as a draft,** so you can review it on GitHub before marking it
  ready and asking maintainers for a review. Owner-flow PRs are unchanged.
- **Is rate limited per target repo:** at most 5 contribution plans per hour per
  user on one repository (relaunching the same plan does not count again).
  Over the limit, the launch is refused with the time to wait.

## Turning it on automatically for forks

Set `contributionMode: "auto"` to engage contribution mode **only when the
target repo is a GitHub fork** (a repo with `fork: true` and a `parent`). The
first time it engages automatically on a given fork, HubLaunch prints a one-time
notice so you know it is on. On a non-fork, `"auto"` does nothing.

```js
contributionMode: "auto",
```

> `"auto"` is fully implemented today but is **not** the default — the default is
> `false` (opt-in) this release. A future release will flip the default to
> `"auto"`.

## Issue/plan split, disclosure, and the waiting window

Three config keys shape the day-one contributor flow. All have safe defaults
that leave the owner flow unchanged.

```js
issuePlanSplit: "auto",      // true | false | "auto" (default)
linkGuidelines: false,       // default: product-free disclosure
waitForMaintainerDays: 0,    // 0 = no wait (default)
```

- **`issuePlanSplit`** — when engaged, the posted GitHub issue is a short,
  human-readable draft (what is wanted and why) rendered into the repo's issue
  template when one is present, while the plan stays a private agent-oriented
  document linked to the issue by number. `hula create` builds the draft from
  the plan's summary and problem statement (no plan sections, no links), adds
  the template's title prefix (e.g. `[Feature] `), then shows it and asks
  whether to **post it**, **edit it in your editor** (title on the first line,
  then the body), or **cancel** — nothing is posted until you choose to.
  (`--name` runs non-interactively: the draft is printed and posted as is.) The
  local plan file is kept when it is not on `origin/main`, since the issue no
  longer carries the plan. Tri-valued like `contributionMode`: `"auto"` (the
  default) splits when you do not own the target **or** contribution mode is
  engaged; otherwise the plan body is the issue body, exactly as before.
- **`linkGuidelines`** (or the `--link-guidelines` flag) — when `true`, the
  guest PR disclosure cites the Responsible Contribution Guidelines instead of
  the generic product-free line. Off by default.
- **`waitForMaintainerDays`** — an optional issue-first waiting window in days,
  counted from when the issue was opened. When positive, `hula launch` will not
  start the build of a plan linked to an issue (`--issue`, the PR's linked
  issue, or the issue `hula create` posted) until the window elapses or a
  maintainer (the repo owner, a member or a collaborator) replies on the issue;
  until then it exits with the time the window ends. A maintainer reply is
  shown to you, shortened, and in a terminal you confirm before the build
  starts — it is **never** passed to the agent. If it changes what should be
  built, update the plan before launching. Use `--skip-wait` for small fixes.
  Resumes and relaunches are not held. `0` (the default) means no wait.

## Stored contribution guidelines

HubLaunch keeps a per-project record of the target repo's contribution policy so
it does not have to be re-discovered on every run. On launch it runs
`updateGuidelines`, which reads an **explicit, bounded** set of sources — the
`CONTRIBUTING` files, the PR template, `CODE_OF_CONDUCT`, the README, the
agent-instruction files (`CLAUDE.md`, `AGENTS.md`, `.cursorrules`,
`.github/copilot-instructions.md`), the org-profile README, and recent commit
trailers — and stores:

- an **AI-contribution stance** (`permits` / `requires_disclosure` / `bans`, or
  unknown);
- the **machine-detected requirements** (DCO, CLA, discuss-first, changelog
  policy, PR template) with per-signal provenance;
- the **noted conventions** in markdown, in two sections: `## From the repo`
  (replaced on each refresh) and `## Learned from our runs` (append-only — a
  dated, sourced synopsis of what each run learned).

The refresh runs automatically whenever contribution mode engages, and otherwise
only when the stored guidelines are empty or older than **90 days**. The results
drive real behaviour:

- a repo whose stance is **`bans`** stops a contribution-mode launch at preflight
  with a clear message (owner launches are never blocked);
- a re-sweep never *relaxes* a stored stance: a `bans` set on the dashboard (or
  found earlier) survives the refresh that runs before the gate, so a maintainer's
  override holds until they edit the card;
- a stance of **`requires_disclosure`** makes the guest PR's disclosure line
  say explicitly that AI assistance was used (the generic sentence), with the
  Responsible Contribution Guidelines citation appended only when
  `linkGuidelines` is also on — always a single line;
- the requirements and conventions are surfaced to the agent as **named data**
  before coding and at polish, and a **preflight** (before any change) plus a
  **compliance post-check** (before the PR opens) enforce them — see
  [Preflight and compliance post-check](#preflight-and-compliance-post-check)
  below.

Everything stored is **editable** on the project's **Contribution guidelines**
settings card in the dashboard — an inference can be wrong, so you can correct
the stance (including clearing a mistaken `bans`) or the conventions, see when
the guidelines were last refreshed and where each signal came from, and press
**Refresh now** to re-run the sweep.

## Preflight and compliance post-check

Contribution-mode runs are bracketed by two guardrails that encode what we
learned shipping real PRs to other people's repos. Owner (non-contribution)
launches run neither.

### Preflight (FR-11) — before any code change

1. **Duplicate check.** HubLaunch searches the target repo's **open PRs and
   issues** for the same change (plan-title keywords, plus the feature-branch
   head). If a plausible match is found the run **stops before writing any
   code** — it records the candidates to the run's lessons file and a task
   warning rather than opening a competing PR. To proceed anyway (you have
   confirmed it is not a duplicate), relaunch with the request flag
   `preflightDuplicateOverride: true` (forwarded to the worker as
   `RALPH_PREFLIGHT_DUPLICATE_OVERRIDE`).
2. **Baseline capture.** Before any change, HubLaunch runs the **project's own**
   test / typecheck / lint commands (as detected into `ralph.md`) and records
   the counts — honouring a repo-stated baseline such as a `CLAUDE.md`
   "7 docs warnings" line — to `.hublaunch/tmp/baseline.json`. The file lives
   under `.hublaunch/` so it never leaks into the contribution diff, and it is
   the reference the post-check's no-regression item compares against.

### Compliance post-check (FR-12) — before the PR opens

The post-check produces a per-item **pass / fail / N-A** checklist with
evidence. It is attached to the guest PR body under a collapsed
**"Contribution compliance"** block, mirrored into the run's lessons file, and a
**mechanical failure blocks the PR** (fix the flagged item and relaunch). Items
that cannot be verified mechanically are listed **N/A — for the human gate**,
never assumed to pass.

| Item | What it checks | Blocks on failure? |
| --- | --- | --- |
| DCO sign-off | `Signed-off-by:` trailer present when CONTRIBUTING requires a DCO | ✅ |
| CLA noted | PR body references the CLA when the repo requires one (signing is a human gate) | — (N/A to human) |
| Discuss-first | a tracking issue exists and is linked when CONTRIBUTING asks to discuss first | ✅ |
| Changelog entry | a changelog file is in the diff when contributors are expected to add one | ✅ |
| PR template | the body covers the repo's PR-template sections | — (N/A to human) |
| AI disclosure | the disclosure line is present when the stance is `requires_disclosure` | ✅ |
| Guidelines surfaced | every structured requirement above was actually evaluated | ✅ |
| Changes explained | every changed file is mentioned, or every commit subject appears in the body | — (N/A to human) |
| Scope | no changed path falls outside the plan's declared **Files** list | ✅ |
| No regression | test count not lower, and lint/typecheck/docs warnings not higher, than the baseline | ✅ |
| Claims re-derived | numeric claims in the body match a fresh run (stale numbers are rewritten, not failed) | — (auto-corrected) |
| Runnable examples | fenced `js`/`ts`/`mjs`/`sh`/`bash` blocks the body presents as runnable exit 0 (mark a block `# not runnable` to skip) | ✅ |
| Links resolve | cited links / DOIs return 2xx/3xx | — (N/A to human) |
| No self-promotion | nothing self-serving beyond the disclosure line and the guidelines link | ✅ |

> Security: a target repo's issue template, its CONTRIBUTING/policy files, its
> agent-instruction files and maintainer replies are all **untrusted data**. The
> issue template is used only as a rendering skeleton (front-matter and HTML
> comments stripped); the guidelines sweep turns policy/agent files into named
> requirements and a bounded prose summary stored **as data**. Nothing from any
> of these is ever fed to the agent as an instruction to execute.

## Opting out

Pass nothing (the default `false`), or set `contributionMode: false`, and
HubLaunch behaves exactly as it always has. The `--contribution` flag overrides a
`contributionMode: false` config for a single run.

See also: [Contribution (guest) mode in Advanced
Usage](./advanced.md#contribution-guest-mode-contributionmode----contribution).
