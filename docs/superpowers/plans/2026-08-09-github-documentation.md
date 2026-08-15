# GitHub Documentation Readiness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make ARNES ARGOS understandable and maintainable for GitHub users and contributors while documenting the current Argos startup behavior and fix.

**Architecture:** Keep the public entry point in `README.md`, place technical startup details in `docs/ARGOS-STARTUP.md`, track user-visible changes in `CHANGELOG.md`, explain collaboration in `CONTRIBUTING.md`, and make `docs/WHAT-IS-LEFT.md` match the current repository state.

**Tech Stack:** Markdown, npm package metadata, Windows PowerShell 5.1+, OpenCode CLI.

## Global Constraints

- Document the current implementation, not planned features as completed.
- Preserve existing project terminology where it is still accurate; identify legacy terminology explicitly.
- Do not add dependencies or modify runtime behavior in this documentation pass.
- Do not claim the working tree is clean; existing unrelated changes remain separate from this pass.
- Verify examples against the current `package.json`, `README.md`, and CLI scripts.

---

### Task 1: Document the public project overview and startup troubleshooting

**Files:**
- Modify: `README.md`
- Create: `docs/ARGOS-STARTUP.md`

**Interfaces:**
- `README.md` links readers to `docs/ARGOS-STARTUP.md`.
- `docs/ARGOS-STARTUP.md` documents `argos`, `argos doctor`, the synchronization chain, the named mutex, idempotent writes, and common Windows symptoms.

- [x] Add a concise “Current status” section to `README.md` that distinguishes implemented capabilities from roadmap work.
- [x] Add a troubleshooting link and verify every command uses the current npm binary `argos` or an explicit repository path.
- [x] Create `docs/ARGOS-STARTUP.md` with: observed startup stages, shared config paths, why the first run can be slower, how concurrent invocations are serialized, and how to run `argos doctor`.
- [x] Include a short diagnostic checklist for banner-only pauses, missing OpenCode, missing model configuration, and sharing violations.
- [x] Search the edited files for stale claims such as “Git roto” or “Evenatan” when referring to the current `argos` command.

**Verification:**

Run `argos doctor` from the repository and confirm the documented success shape remains accurate. Search the docs for `argos`, `.config/arnes`, `argos doctor`, and `ARGOS-STARTUP.md`.

### Task 2: Add release history and contributor workflow

**Files:**
- Create: `CHANGELOG.md`
- Create: `CONTRIBUTING.md`

**Interfaces:**
- `CHANGELOG.md` records the current unreleased documentation and startup synchronization improvements.
- `CONTRIBUTING.md` explains setup, validation, scope discipline, and how to report issues without promising unsupported CI commands.

- [x] Add an `Unreleased` section to `CHANGELOG.md` with the mutex, idempotent writes, diagnostics, and documentation work.
- [x] Add a contributor setup using `npm install -g .` only where appropriate and repository-local PowerShell commands for safe testing.
- [x] Document `argos doctor`, PowerShell parser checks for changed `.ps1` files, and manual CLI verification.
- [x] Explain that commits must isolate unrelated pre-existing work and that contributors should not commit secrets or local `.arnes` runtime data.
- [x] Add issue-reporting fields: OS, PowerShell version, command, output, elapsed time, and whether another `argos` process was running.

**Verification:**

Check that every command in both files exists in `package.json`, `README.md`, or the CLI scripts. Confirm no placeholder text (`TBD`, `TODO`, or fake URLs) remains.

### Task 3: Reconcile the project state document

**Files:**
- Modify: `docs/WHAT-IS-LEFT.md`

**Interfaces:**
- The document remains the roadmap/status source of truth and links to the new startup guide and changelog.

- [x] Replace stale completed/pending claims with the current implemented state: npm CLI, Argos doctor, global model configuration, OpenCode synchronization, SQLite memory, graph, SDD/FDD/ADR documentation, and startup locking.
- [x] Keep genuinely incomplete product work in a clearly labeled roadmap section.
- [x] Add a “Known repository state” note explaining that the current worktree contains accumulated changes and that GitHub publication requires an intentional commit split.
- [x] Add links to `README.md`, `CHANGELOG.md`, `CONTRIBUTING.md`, and `docs/ARGOS-STARTUP.md`.

**Verification:**

Cross-check every completed item against the repository files and current CLI behavior. Search for contradictions with the README and ensure all four links resolve.

### Task 4: Final documentation QA

**Files:**
- Verify: `README.md`, `CHANGELOG.md`, `CONTRIBUTING.md`, `docs/ARGOS-STARTUP.md`, `docs/WHAT-IS-LEFT.md`

- [x] Read all changed documentation end-to-end for contradictory commands, stale names, and unsupported guarantees.
- [x] Run `argos doctor` and record only observed results.
- [x] Run PowerShell parser checks for `cli/argos-opencode.ps1` and `cli/argos-models-apply.ps1`.
- [x] Review `git status --short`; runtime, agent, metadata, documentation, security, and test changes were committed separately.
