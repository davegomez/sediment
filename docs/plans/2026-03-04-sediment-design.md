# Sediment: Passive Second Brain for Coding Sessions

A shell-script installer that sets up a passive second brain across Claude Code and Pi. Hooks and skills capture session knowledge automatically and write structured notes to an Obsidian vault. The agent does all distillation — no external API calls, no SDK.

## Architecture

Three layers:

1. **Capture** — hooks (Claude Code) and extensions (Pi) trigger the session's own agent to distill decisions, patterns, gotchas, context, and progress into Obsidian notes.
2. **Structure** — a shared `sediment-writer` skill teaches the agent vault conventions, frontmatter schema, note formats, and tag taxonomy.
3. **Retrieval** — session-start hooks inject relevant past notes as context. A decay script ages out stale inbox notes.

Sediment's own state lives in `~/.sediment/` (config, scripts, session markers). Hooks, extensions, and skills are copied into harness-specific locations.

## Dependencies

| Dependency | Install method | Notes |
|---|---|---|
| Node.js / npm | Prerequisite | Script verifies, aborts if missing |
| jq | Prerequisite | Script verifies, aborts if missing |
| git | Prerequisite | Script verifies, aborts if missing |
| Obsidian | User installs manually | Script warns if not detected |
| Obsidian CLI | `npm install -g obsidian-cli` | Script installs |
| Defuddle CLI | `npm install -g defuddle-cli` | Script installs |
| kepano/obsidian-skills | Clone repo, copy 5 skills | obsidian-markdown, obsidian-bases, json-canvas, obsidian-cli, defuddle |

## Install Script

```
install.sh
│
├─ 1. Check prerequisites (node, npm, git, jq)
├─ 2. Detect harnesses (Claude Code, Pi, both)
├─ 3. Ask: global or per-project install
├─ 4. Auto-detect Obsidian vaults → user picks or accepts recommended path
├─ 5. Verify Obsidian installed (warn if not, continue)
├─ 6. Install CLI tools (obsidian-cli, defuddle-cli)
├─ 7. Clone kepano/obsidian-skills → copy 5 skills to harness locations
├─ 8. Install sediment-writer skill (replace vault path placeholder)
├─ 9. Install hooks (Claude Code) / extension (Pi)
├─ 10. Create vault folder structure + seed templates & MOCs
├─ 11. Write ~/.sediment/config.json
└─ 12. Print summary + next steps
```

### Vault Detection

1. Read `obsidian.json` from Obsidian's global settings directory to list existing vaults.
2. If vaults found: present list, let user pick, also offer "Create new vault."
3. If none found: recommend `~/Documents/Sediment/`, let user accept or enter a custom path.
4. Validate: not nested inside another vault, not a system folder, parent is writable.

Platform paths for `obsidian.json`:
- macOS: `~/Library/Application Support/obsidian/obsidian.json`
- Linux: `~/.config/obsidian/obsidian.json`

### Install Scope

The user chooses global or per-project:

| Scope | Claude Code locations | Pi locations |
|---|---|---|
| Global | `~/.claude/settings.json`, `~/.claude/skills/` | `~/.pi/agent/extensions/`, `~/.pi/agent/skills/` |
| Per-project | `.claude/settings.json`, `.claude/skills/` | `.pi/extensions/`, `.pi/skills/` |

### Uninstall

`uninstall.sh` reverses the install: removes hooks from settings, removes extensions, removes skills, removes `~/.sediment/`. Vault is left untouched. CLI tools are left installed.

## Vault Structure

```
<VaultName>/
├── 00-Inbox/              # All automated captures land here
├── 01-Decisions/          # Promoted ADRs
├── 02-Patterns/           # Promoted reusable patterns
├── 03-Reference/          # Promoted context & gotchas
├── 04-Archive/            # Decayed / superseded notes
├── 05-MOCs/               # Maps of Content (.base files)
├── _templates/            # Note templates (one per type)
└── _attachments/          # Binary files
```

Folders represent lifecycle stage, not topic. All automated captures land in `00-Inbox/`. Users promote notes to `01–03` during review. Tags and frontmatter handle topical organization.

### File Naming

Zettelkasten-style timestamp prefix: `YYYYMMDDHHmm-slugified-title.md`

Example: `202503041022-chose-postgresql-over-mongodb.md`

### Note Types

Five types, each with a template in `_templates/`:

**Decision** — ADR format: context, decision, alternatives considered, consequences (positive/negative). Default confidence: 0.9.

**Pattern** — Reusable approach: what it is, when to use it, example, trade-offs. Default confidence: 0.85.

**Gotcha** — Surprising problem: what went wrong, root cause, solution. Default confidence: 0.9.

**Context** — Domain/project background: background, key facts, implications. Default confidence: 0.7.

**Progress** — Session milestone: what was accomplished, next steps. Default confidence: 0.6.

### Common Frontmatter

```yaml
---
title: ""
date_created: YYYY-MM-DDTHH:MM:SS
type: decision | pattern | gotcha | context | progress
tags:
  - status/unreviewed
  - type/<type>
  - topic/<freeform>
  - project/<freeform>
session_id: ""
source_project: ""
confidence: 0.0-1.0
related: []
---
```

### Tag Taxonomy

```
status/unreviewed       # Freshly captured
status/reviewed         # Human-verified
status/archived         # Manually archived
status/decayed          # Confidence decayed past threshold

type/decision
type/pattern
type/gotcha
type/context
type/progress

topic/<freeform>        # e.g., topic/database, topic/auth
project/<freeform>      # e.g., project/user-service
```

### MOCs via Obsidian Bases

`.base` files in `05-MOCs/` — no community plugin dependency (Bases is built into Obsidian):

- **Inbox.base** — unreviewed notes grouped by type
- **Decisions.base** — all decisions with age
- **Patterns.base** — all patterns
- **Gotchas.base** — all gotchas
- **Context.base** — all context notes
- **Progress.base** — all progress notes
- **By-Project.base** — non-archived notes grouped by source_project
- **Recent-Activity.base** — last 30 notes across all types

## Capture Mechanism

### Claude Code: Stop Hook

A command hook on `Stop` blocks the agent from stopping and instructs it to distill. The `stop_hook_active` field prevents infinite loops.

Flow:

1. Claude finishes responding → `Stop` fires.
2. Hook checks `stop_hook_active` — if true, writes session marker, exits 0.
3. Hook checks session marker — if exists, exits 0.
4. Hook returns `decision: "block"` with reason referencing the sediment-writer skill.
5. Claude follows the skill: evaluates session content, writes notes to `00-Inbox/` (or decides nothing worth capturing and stops).
6. Claude finishes → `Stop` fires again → `stop_hook_active` is true → marker written, exits 0.

Hook config merged into `settings.json`:
```json
{
  "hooks": {
    "Stop": [{
      "hooks": [{
        "type": "command",
        "command": "$HOME/.sediment/scripts/sediment-capture.sh",
        "timeout": 120
      }]
    }],
    "SessionStart": [{
      "hooks": [{
        "type": "command",
        "command": "$HOME/.sediment/scripts/sediment-decay.sh && $HOME/.sediment/scripts/sediment-context.sh \"$PWD\""
      }]
    }]
  }
}
```

### Pi: Extension (Deferred Distillation)

Pi lacks `stop_hook_active` and a blockable Stop event. Instead, distillation is deferred to the next session.

Flow:

1. Session ends → `session_shutdown` fires → extension writes `pending.json` with session info (only if session had 3+ assistant turns).
2. Next session starts → `session_start` fires → extension detects `pending.json`.
3. Extension calls `sendUserMessage()` with distillation instructions referencing the sediment-writer skill.
4. Agent distills previous session, writes notes to vault.
5. Agent finishes, user proceeds normally.

The extension also handles retrieval: on `before_agent_start`, runs the decay and context scripts and injects output into the system prompt.

### Trade-off

| | Claude Code | Pi |
|---|---|---|
| When | End of current session | Start of next session |
| Reliability | Always fires | Requires user to start another session |
| Mechanism | Stop hook block/allow | Extension + sendUserMessage |

## Sediment-Writer Skill

Teaches the agent how to distill sessions. Installed identically for both harnesses.

```
sediment-writer/
├── SKILL.md
└── references/
    ├── templates.md
    ├── tag-taxonomy.md
    └── examples.md
```

### SKILL.md Core Instructions

1. **Evaluate** — review session content. If nothing meaningful, say so and stop.
2. **Extract** — one note per distinct item. No monolithic summaries.
3. **Deduplicate** — check existing note titles in `00-Inbox/`, `01-Decisions/`, `02-Patterns/`, `03-Reference/`. Skip or update rather than duplicate.
4. **Write** — create each note in `00-Inbox/` following the type template.
5. **Link** — add `[[wikilinks]]` in note body for related existing notes.

### What to Capture vs. Skip

| Type | Capture | Skip |
|---|---|---|
| Decision | Technology/design choice with reasoning | Trivial choices, no trade-offs |
| Pattern | Reusable technique that emerged | One-off solutions unlikely to recur |
| Gotcha | Surprising bug or non-obvious constraint | Well-known issues documented elsewhere |
| Context | Important domain/project background | Generic knowledge not project-specific |
| Progress | Significant implementation milestone | Minor edits or exploratory questions |

## Retrieval & Confidence Decay

### Context Injection

A shared script (`sediment-context.sh`) reads vault notes relevant to the current project directory and formats a compact summary. Both harnesses call the same script at session start.

Output format:
```
[Sediment] Relevant notes from your vault:

DECISIONS:
- [[chose-postgresql-over-mongodb]]: PostgreSQL with JSONB for user data (3 days ago)

GOTCHAS:
- [[prisma-json-field-typing]]: Prisma requires JsonValue cast for JSONB (1 day ago)
```

Notes are matched by `source_project` frontmatter against the current working directory. Recent high-confidence notes from other projects are included for cross-pollination. Decayed and archived notes are excluded.

### Confidence Decay

A script (`sediment-decay.sh`) runs at session start before context injection.

| Note type | Decay after | Scope |
|---|---|---|
| Progress | 7 days | `00-Inbox/` only |
| Context | 30 days | `00-Inbox/` only |
| Decision, Pattern, Gotcha | Never | — |

Only inbox notes decay. Promoted notes (in `01–03`) are human-verified and permanent. Decay adds `status/decayed` tag — no files are moved, no wikilinks break.

## Repo Structure

```
sediment/
├── install.sh
├── uninstall.sh
├── README.md
├── LICENSE
├── scripts/
│   ├── sediment-capture.sh
│   ├── sediment-context.sh
│   └── sediment-decay.sh
├── extensions/
│   └── sediment/
│       └── index.ts
├── skills/
│   └── sediment-writer/
│       ├── SKILL.md
│       └── references/
│           ├── templates.md
│           ├── tag-taxonomy.md
│           └── examples.md
└── vault-seed/
    ├── 00-Inbox/.gitkeep
    ├── 01-Decisions/.gitkeep
    ├── 02-Patterns/.gitkeep
    ├── 03-Reference/.gitkeep
    ├── 04-Archive/.gitkeep
    ├── 05-MOCs/
    │   ├── Inbox.base
    │   ├── Decisions.base
    │   ├── Patterns.base
    │   ├── Gotchas.base
    │   ├── Context.base
    │   ├── Progress.base
    │   ├── By-Project.base
    │   └── Recent-Activity.base
    ├── _templates/
    │   ├── decision.md
    │   ├── pattern.md
    │   ├── gotcha.md
    │   ├── context.md
    │   └── progress.md
    └── _attachments/.gitkeep
```

### ~/.sediment/ (created at install)

```
~/.sediment/
├── config.json
├── sessions/
└── scripts/
    ├── sediment-capture.sh
    ├── sediment-context.sh
    └── sediment-decay.sh
```

### config.json

```json
{
  "vault_path": "/Users/user/Documents/Sediment",
  "install_scope": "global",
  "harnesses": ["claude-code", "pi"],
  "installed_at": "2026-03-04T09:18:45-05:00",
  "version": "1.0.0"
}
```
