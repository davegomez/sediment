# Sediment

A passive second brain for coding sessions. Sediment hooks into [Claude Code](https://docs.anthropic.com/en/docs/claude-code) and [Pi](https://github.com/badlogic/pi) to automatically distill decisions, patterns, gotchas, context, and progress into an [Obsidian](https://obsidian.md) vault.

You don't change your workflow. Sediment captures knowledge in the background while you code.

## How It Works

Three layers:

1. **Capture** — hooks (Claude Code) and extensions (Pi) trigger the session's own agent to distill what happened.
2. **Structure** — a shared `sediment-writer` skill teaches the agent vault conventions, note formats, and tagging.
3. **Retrieval** — at session start, relevant past notes are injected into the agent's context.

No external API calls. The agent doing your coding work is the same one writing the notes.

## Prerequisites

- **Node.js** and **npm**
- **git**
- **jq**
- **Obsidian** ([download](https://obsidian.md)) — for viewing your vault
- **Claude Code** and/or **Pi** — at least one must be installed

## Installation

```bash
git clone https://github.com/user/sediment.git
cd sediment
./install.sh
```

The installer will:

1. Check prerequisites
2. Detect which harnesses you have (Claude Code, Pi, or both)
3. Ask for global or per-project install scope
4. Auto-detect Obsidian vaults or create a new one
5. Install CLI tools (`obsidian-cli`, `defuddle-cli`)
6. Install Obsidian skills from [kepano/obsidian-skills](https://github.com/kepano/obsidian-skills)
7. Install the `sediment-writer` skill
8. Set up hooks (Claude Code) and/or extensions (Pi)
9. Seed the vault with folders, templates, and MOC views

## What Gets Installed

| Component          | Global location                    | Project location           |
| ------------------ | ---------------------------------- | -------------------------- |
| Claude Code hooks  | `~/.claude/settings.json`          | `.claude/settings.json`    |
| Claude Code skills | `~/.claude/skills/`                | `.claude/skills/`          |
| Pi extension       | `~/.pi/agent/extensions/sediment/` | `.pi/extensions/sediment/` |
| Pi skills          | `~/.pi/agent/skills/`              | `.pi/skills/`              |
| Scripts            | `~/.sediment/scripts/`             | `~/.sediment/scripts/`     |
| Config             | `~/.sediment/config.json`          | `~/.sediment/config.json`  |

## Vault Structure

```
YourVault/
├── 00-Inbox/         ← All automated captures land here
├── 01-Decisions/     ← Promoted ADRs
├── 02-Patterns/      ← Promoted reusable patterns
├── 03-Reference/     ← Promoted context & gotchas
├── 04-Archive/       ← Decayed or superseded notes
├── 05-MOCs/          ← Maps of Content (.base views)
├── _templates/       ← Note templates
└── _attachments/     ← Binary files
```

Folders represent lifecycle stage, not topic. Tags and frontmatter handle topical organization.

## Note Types

| Type         | What it captures                                                       | Default confidence |
| ------------ | ---------------------------------------------------------------------- | ------------------ |
| **Decision** | Technology or design choice with reasoning, alternatives, consequences | 0.9                |
| **Pattern**  | Reusable technique — what it is, when to use it, trade-offs            | 0.85               |
| **Gotcha**   | Surprising problem — what went wrong, root cause, solution             | 0.9                |
| **Context**  | Domain/project background — key facts and implications                 | 0.7                |
| **Progress** | Session milestone — what was accomplished, next steps                  | 0.6                |

Notes use Zettelkasten-style naming: `YYYYMMDDHHmm-slugified-title.md`

## How Capture Works

### Claude Code

A **Stop hook** fires at the end of each session. It blocks the agent from stopping and asks it to follow the `sediment-writer` skill. The agent evaluates the session, writes any notes worth capturing, then stops. A `stop_hook_active` flag prevents infinite loops.

### Pi

Pi uses **deferred distillation**. When a session ends, an extension writes a marker file. At the start of the next session, the extension detects the marker and sends a message asking the agent to distill the previous session.

|                 | Claude Code            | Pi                                |
| --------------- | ---------------------- | --------------------------------- |
| **When**        | End of current session | Start of next session             |
| **Mechanism**   | Stop hook block/allow  | Extension + sendUserMessage       |
| **Reliability** | Always fires           | Requires starting another session |

## How Retrieval Works

At session start, a script scans the vault for notes matching the current project (by `source_project` frontmatter or `project/` tag). Recent high-confidence notes from other projects are included for cross-pollination. The result is injected into the agent's system prompt.

Example context injection:

```
[Sediment] Relevant notes from your vault:

DECISIONS:
- [[chose-postgresql-over-mongodb]]: PostgreSQL with JSONB for user data (3 days ago)

GOTCHAS:
- [[prisma-json-field-typing]]: Prisma requires JsonValue cast for JSONB (1 day ago)
```

## Confidence Decay

Not every note stays relevant forever. A decay script runs at session start:

| Note type                 | Decays after | Scope            |
| ------------------------- | ------------ | ---------------- |
| Progress                  | 7 days       | `00-Inbox/` only |
| Context                   | 30 days      | `00-Inbox/` only |
| Decision, Pattern, Gotcha | Never        | —                |

Decay replaces the `status/unreviewed` tag with `status/decayed`. No files are moved or deleted. Promoted notes (in `01–03`) are permanent — only inbox notes decay.

## Reviewing Notes

Notes arrive in `00-Inbox/` with `status/unreviewed`. To review:

1. Open the **Inbox** base view in `05-MOCs/Inbox.base`
2. Read each note — verify accuracy, fix details
3. Change `status/unreviewed` to `status/reviewed`
4. Move the note to the appropriate folder:
   - Decisions → `01-Decisions/`
   - Patterns → `02-Patterns/`
   - Gotchas, Context → `03-Reference/`

The `05-MOCs/` folder contains [Obsidian Bases](https://help.obsidian.md/bases) views (no plugins required):

- **Inbox.base** — unreviewed notes grouped by type
- **Decisions.base** — all decisions grouped by project
- **Patterns.base** — all patterns
- **Gotchas.base** — all gotchas
- **Context.base** — context notes with decay status
- **Progress.base** — progress notes with decay status
- **By-Project.base** — all active notes grouped by project
- **Recent-Activity.base** — last 30 notes

## Uninstalling

```bash
cd sediment
./uninstall.sh
```

This removes hooks, extensions, skills, and `~/.sediment/`. Your vault is left untouched. CLI tools (`obsidian-cli`, `defuddle-cli`) are left installed.

## License

AGPL-3.0-or-later
