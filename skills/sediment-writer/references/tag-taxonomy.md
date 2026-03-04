# Tag Taxonomy

Tags organize notes by status, type, topic, and project. Every note must have at least one tag from each required category.

## Status Tags (required — exactly one)

| Tag | Meaning |
|-----|---------|
| `status/unreviewed` | Freshly captured by the agent, not yet verified by a human |
| `status/reviewed` | Human has verified the note's accuracy |
| `status/archived` | Manually archived — no longer active but preserved |
| `status/decayed` | Confidence decayed past threshold (automated by decay script) |

New notes always get `status/unreviewed`. Only humans change status to `reviewed` or `archived`. The decay script changes `unreviewed` to `decayed` based on age rules.

## Type Tags (required — exactly one)

| Tag | Meaning |
|-----|---------|
| `type/decision` | Architecture or technology choice with reasoning |
| `type/pattern` | Reusable technique or approach |
| `type/gotcha` | Surprising problem or non-obvious constraint |
| `type/context` | Domain or project background knowledge |
| `type/progress` | Session milestone or accomplishment |

Must match the `type` frontmatter field.

## Topic Tags (at least one recommended)

Freeform. Describe the domain or technical area.

Examples:
- `topic/database`
- `topic/auth`
- `topic/testing`
- `topic/deployment`
- `topic/api-design`
- `topic/performance`
- `topic/error-handling`

Use lowercase, hyphen-separated. Keep tags broad enough to group related notes — avoid one-off tags that will never recur.

## Project Tags (at least one recommended)

Freeform. Derived from the `source_project` frontmatter field.

Examples:
- `project/user-service`
- `project/sediment`
- `project/api-gateway`

Use the project directory name as-is, lowercased.

## Guidelines

1. Every new note must have `status/unreviewed` and `type/<type>`.
2. Add at least one `topic/` or `project/` tag so the note is discoverable.
3. Prefer existing tags over inventing new ones — check the vault first.
4. Keep the tag set small. Five tags per note is plenty.
