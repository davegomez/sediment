# Note Templates

Each note type has a frontmatter schema and body structure. Follow these templates, but use judgment — if an "Alternatives Considered" section would be empty because there genuinely were no alternatives, omit it rather than leaving a blank heading. The goal is useful notes, not checkbox compliance.

## Common Frontmatter

All note types share these fields:

| Field | Type | Description |
|-------|------|-------------|
| `title` | string | Human-readable title (not the filename slug) |
| `date_created` | ISO 8601 | When the note was created |
| `type` | enum | `decision`, `pattern`, `gotcha`, `context`, or `progress` |
| `tags` | list | Must include `status/unreviewed`, `type/<type>`, and at least one `topic/` or `project/` tag |
| `session_id` | string | Session identifier, if available |
| `source_project` | string | Project directory name |
| `confidence` | float | 0.0–1.0, use the type default |
| `related` | list | Wikilinks to related notes |

---

## Decision

Default confidence: **0.9**

```markdown
---
title: ""
date_created: YYYY-MM-DDTHH:MM:SS
type: decision
tags:
  - status/unreviewed
  - type/decision
  - project/<project>
  - topic/<topic>
session_id: ""
source_project: ""
confidence: 0.9
related: []
---

## Context
<!-- What situation prompted this decision? -->

## Decision
<!-- What was decided? -->

## Alternatives Considered
<!-- What else was evaluated, with pros and cons? -->

## Consequences
- **Positive**:
- **Negative**:
```

---

## Pattern

Default confidence: **0.85**

```markdown
---
title: ""
date_created: YYYY-MM-DDTHH:MM:SS
type: pattern
tags:
  - status/unreviewed
  - type/pattern
  - project/<project>
  - topic/<topic>
session_id: ""
source_project: ""
confidence: 0.85
related: []
---

## Pattern
<!-- What is the reusable approach? -->

## When to Use
<!-- What conditions make this applicable? -->

## Example
<!-- Concrete usage example -->

## Trade-offs
<!-- What are the limitations? -->
```

---

## Gotcha

Default confidence: **0.9**

```markdown
---
title: ""
date_created: YYYY-MM-DDTHH:MM:SS
type: gotcha
tags:
  - status/unreviewed
  - type/gotcha
  - project/<project>
  - topic/<topic>
session_id: ""
source_project: ""
confidence: 0.9
related: []
---

## Problem
<!-- What went wrong or was surprising? -->

## Root Cause
<!-- Why does this happen? -->

## Solution
<!-- How to fix or avoid it -->
```

---

## Context

Default confidence: **0.7**

```markdown
---
title: ""
date_created: YYYY-MM-DDTHH:MM:SS
type: context
tags:
  - status/unreviewed
  - type/context
  - project/<project>
  - topic/<topic>
session_id: ""
source_project: ""
confidence: 0.7
related: []
---

## Background
<!-- What domain/project knowledge was established? -->

## Key Facts
<!-- Important details worth remembering -->

## Implications
<!-- How does this affect future work? -->
```

---

## Progress

Default confidence: **0.6**

```markdown
---
title: ""
date_created: YYYY-MM-DDTHH:MM:SS
type: progress
tags:
  - status/unreviewed
  - type/progress
  - project/<project>
  - topic/<topic>
session_id: ""
source_project: ""
confidence: 0.6
related: []
---

## Accomplished
<!-- What was done in this session? -->

## Next Steps
<!-- What remains to be done? -->
```
