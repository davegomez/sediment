---
name: sediment-writer
description: Distill coding session knowledge into Obsidian vault notes. This skill is triggered by Sediment's capture hooks — use it whenever you're asked to distill, capture, or write session notes to the vault. Covers decisions, patterns, gotchas, context, and progress notes with structured frontmatter, Zettelkasten file naming, and wikilink cross-references.
---

# Sediment Writer

Distill the current coding session into structured Obsidian vault notes. Every note lands in `VAULT_PATH_PLACEHOLDER/00-Inbox/`.

## Process

### 1. Evaluate

Review the session. If nothing meaningful happened — trivial edits, exploratory questions with no conclusions, routine tasks — say so and stop. Not every session produces notes.

A typical session yields 1–3 notes. If you're writing more than 5, you're probably over-capturing — tighten your filter for what's genuinely worth remembering.

### 2. Extract

Identify distinct items worth capturing. Create **one note per item** — individual notes can be linked, promoted, and decayed independently, while monolithic summaries can't. If a session produced both a database decision and an unrelated gotcha about TypeScript, those are two notes.

| Type | Capture | Skip |
|------|---------|------|
| Decision | Technology or design choice with reasoning and trade-offs | Trivial choices with no trade-offs |
| Pattern | Reusable technique that emerged during the session | One-off solutions unlikely to recur |
| Gotcha | Surprising bug, non-obvious constraint, or unexpected behavior | Well-known issues documented elsewhere |
| Context | Important domain or project background established | Generic knowledge not specific to this project |
| Progress | Significant implementation milestone | Minor edits or exploratory questions |

### 3. Deduplicate

Before writing, check existing note titles in these folders:
- `VAULT_PATH_PLACEHOLDER/00-Inbox/`
- `VAULT_PATH_PLACEHOLDER/01-Decisions/`
- `VAULT_PATH_PLACEHOLDER/02-Patterns/`
- `VAULT_PATH_PLACEHOLDER/03-Reference/`

If a note on the same topic already exists, **update it** rather than creating a duplicate. If the existing note says exactly what you would write, skip it. Duplicate notes create noise that erodes trust in the vault over time — the human reviewing inbox notes will stop reading if they see the same thing twice.

### 4. Write

Create each note in `VAULT_PATH_PLACEHOLDER/00-Inbox/` following the type template from [templates.md](references/templates.md).

**File naming:** Zettelkasten-style timestamp prefix with a slugified title. Slugs use lowercase letters, numbers, and hyphens only — no spaces, underscores, or special characters.

```
YYYYMMDDHHmm-slugified-title.md
```

Example: `202603041022-chose-postgresql-over-mongodb.md`

**Note body length:** A few concise paragraphs per section. Write enough that someone reading the note in six months understands the context without re-reading the session transcript — but don't reproduce the transcript itself.

**Frontmatter rules:**
- `date_created`: current ISO 8601 timestamp
- `session_id`: use the current session ID if available, otherwise leave empty
- `source_project`: derive from the current working directory name
- `confidence`: use the default for the note type (see templates). These defaults reflect how quickly each type goes stale — progress notes (0.6) lose relevance in days, while decisions (0.9) and gotchas (0.9) tend to hold for months.
- `tags`: always include `status/unreviewed` and `type/<type>`, add at least one `topic/` or `project/` tag
- `related`: list of wikilinks to related notes. **Important:** always quote wikilinks in YAML — write `"[[note-name]]"`, not bare `[[note-name]]`, because the brackets are special YAML characters.

See [tag-taxonomy.md](references/tag-taxonomy.md) for the full tag schema.

### 5. Link

Add `[[wikilinks]]` in the note body to reference related existing notes. Check the vault for notes that share the same project, topic, or domain. Only link when genuinely relevant.

## References

- [templates.md](references/templates.md) — frontmatter schema and body structure for each note type
- [tag-taxonomy.md](references/tag-taxonomy.md) — required and optional tag conventions
- [examples.md](references/examples.md) — three fully-worked example notes
