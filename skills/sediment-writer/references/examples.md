# Example Notes

Three fully-worked examples showing correct frontmatter, file naming, tags, and body structure.

---

## Example 1: Decision

**Filename:** `202603041022-chose-postgresql-over-mongodb.md`

```markdown
---
title: "Chose PostgreSQL over MongoDB for user data"
date_created: 2026-03-04T10:22:00
type: decision
tags:
  - status/unreviewed
  - type/decision
  - project/user-service
  - topic/database
session_id: "abc123"
source_project: "user-service"
confidence: 0.9
related:
  - "[[202603031415-user-data-model-requirements]]"
---

## Context

The user service needs a primary data store for user profiles, preferences, and authentication records. The data has a well-defined schema with relational aspects (users → roles → permissions) but also includes a flexible `preferences` field that varies per user.

## Decision

Use PostgreSQL with JSONB columns for semi-structured fields like preferences. The relational core handles users, roles, and permissions with proper foreign keys, while JSONB provides flexibility where needed.

## Alternatives Considered

- **MongoDB**: More natural for the flexible preferences field, but the relational aspects (role assignments, permission checks) would require denormalization or application-level joins. The team has stronger PostgreSQL experience.
- **PostgreSQL without JSONB**: Would require a separate key-value table for preferences, adding complexity to queries without clear benefit.

## Consequences
- **Positive**: Strong consistency guarantees, familiar tooling, JSONB handles the flexible parts, single database to operate
- **Negative**: JSONB queries are less ergonomic than native document queries, need to manage column types carefully with [[202603041030-prisma-json-field-typing]]
```

---

## Example 2: Pattern

**Filename:** `202603041045-retry-with-exponential-backoff.md`

```markdown
---
title: "Retry with exponential backoff for external API calls"
date_created: 2026-03-04T10:45:00
type: pattern
tags:
  - status/unreviewed
  - type/pattern
  - project/api-gateway
  - topic/error-handling
  - topic/api-design
session_id: "def456"
source_project: "api-gateway"
confidence: 0.85
related: []
---

## Pattern

Wrap external API calls in a retry loop with exponential backoff and jitter. Start at 100ms delay, double each retry, add random jitter of ±25%, cap at 5 retries and 10 second max delay.

## When to Use

- Calling third-party APIs that occasionally return 429 or 503
- Network operations that may fail due to transient issues
- Any idempotent external call where a brief delay is acceptable

Do NOT use for non-idempotent operations (POST creating resources) unless the API supports idempotency keys.

## Example

```typescript
async function withRetry<T>(fn: () => Promise<T>, maxRetries = 5): Promise<T> {
  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      return await fn();
    } catch (err) {
      if (attempt === maxRetries) throw err;
      const base = Math.min(100 * 2 ** attempt, 10000);
      const jitter = base * (0.75 + Math.random() * 0.5);
      await new Promise((r) => setTimeout(r, jitter));
    }
  }
  throw new Error("unreachable");
}
```

## Trade-offs

- Adds latency on failure paths — 5 retries can take ~30 seconds worst case
- Must ensure operations are idempotent or guard with idempotency keys
- Jitter prevents thundering herd but makes timing less predictable for debugging
```

---

## Example 3: Gotcha

**Filename:** `202603041030-prisma-json-field-typing.md`

```markdown
---
title: "Prisma requires explicit JsonValue cast for JSONB columns"
date_created: 2026-03-04T10:30:00
type: gotcha
tags:
  - status/unreviewed
  - type/gotcha
  - project/user-service
  - topic/database
  - topic/typescript
session_id: "abc123"
source_project: "user-service"
confidence: 0.9
related:
  - "[[202603041022-chose-postgresql-over-mongodb]]"
---

## Problem

TypeScript compilation fails when assigning a plain object to a Prisma model's `Json` field. The error says the type is not assignable to `Prisma.InputJsonValue`, even though the object is valid JSON.

## Root Cause

Prisma's generated types use `Prisma.InputJsonValue` for JSON columns, which is a union of `string | number | boolean | JsonObject | JsonArray | null`. Plain TypeScript objects with optional fields or union types don't satisfy this — TypeScript can't prove every possible shape fits the union.

## Solution

Cast the object explicitly before passing it to Prisma:

```typescript
import { Prisma } from "@prisma/client";

await prisma.user.update({
  where: { id },
  data: {
    preferences: userPrefs as unknown as Prisma.InputJsonValue,
  },
});
```

Alternatively, use `JSON.parse(JSON.stringify(obj))` to guarantee a plain JSON-compatible object, though this is slower and loses type safety.
```
