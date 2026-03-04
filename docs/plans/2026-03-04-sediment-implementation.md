# Sediment Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a shell-script installer that sets up a passive second brain across Claude Code and Pi, using hooks, extensions, and skills to distill coding sessions into an Obsidian vault.

**Architecture:** Three layers — capture (hooks/extensions trigger agent distillation), structure (sediment-writer skill defines vault conventions), retrieval (session-start scripts inject past notes as context). The install script detects harnesses, installs dependencies, copies files, and seeds the vault.

**Tech Stack:** Bash (install script, hook scripts), TypeScript (Pi extension), Markdown/YAML (skills, templates, .base MOCs), jq (JSON manipulation)

**Design doc:** `docs/plans/2026-03-04-sediment-design.md`

---

### Task 1: Repo Scaffolding

**Files:**

- Create: `README.md`
- Create: `.gitignore`
- Create: `LICENSE`

**Step 1: Create .gitignore**

```gitignore
node_modules/
.DS_Store
*.bak
tmp/
```

**Step 2: Create LICENSE**

AGPL-3.0-or-later license with current year and author.

**Step 3: Create README.md**

Minimal placeholder — will be fleshed out in the final task.

````markdown
# Sediment

A passive second brain for coding sessions. Automatically distills decisions, patterns, gotchas, context, and progress from Claude Code and Pi sessions into an Obsidian vault.

## Quick Start

```bash
git clone https://github.com/user/sediment.git
cd sediment
./install.sh
```
````

## Documentation

See `docs/plans/2026-03-04-sediment-design.md` for the full architecture.

````

**Step 4: Commit**

```bash
git add .gitignore LICENSE README.md
git commit -m "feat: repo scaffolding with README, LICENSE, gitignore"
````

---

### Task 2: Vault Seed — Folder Structure and Templates

**Files:**

- Create: `vault-seed/00-Inbox/.gitkeep`
- Create: `vault-seed/01-Decisions/.gitkeep`
- Create: `vault-seed/02-Patterns/.gitkeep`
- Create: `vault-seed/03-Reference/.gitkeep`
- Create: `vault-seed/04-Archive/.gitkeep`
- Create: `vault-seed/05-MOCs/.gitkeep` (placeholder, bases added in Task 3)
- Create: `vault-seed/_attachments/.gitkeep`
- Create: `vault-seed/_templates/decision.md`
- Create: `vault-seed/_templates/pattern.md`
- Create: `vault-seed/_templates/gotcha.md`
- Create: `vault-seed/_templates/context.md`
- Create: `vault-seed/_templates/progress.md`

**Step 1: Create folder structure with .gitkeep files**

```bash
mkdir -p vault-seed/{00-Inbox,01-Decisions,02-Patterns,03-Reference,04-Archive,05-MOCs,_attachments}
touch vault-seed/{00-Inbox,01-Decisions,02-Patterns,03-Reference,04-Archive,05-MOCs,_attachments}/.gitkeep
mkdir -p vault-seed/_templates
```

**Step 2: Create decision template**

`vault-seed/_templates/decision.md`:

```markdown
---
title: ""
date_created:
type: decision
tags:
  - status/unreviewed
  - type/decision
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

**Step 3: Create pattern template**

`vault-seed/_templates/pattern.md`:

```markdown
---
title: ""
date_created:
type: pattern
tags:
  - status/unreviewed
  - type/pattern
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

**Step 4: Create gotcha template**

`vault-seed/_templates/gotcha.md`:

```markdown
---
title: ""
date_created:
type: gotcha
tags:
  - status/unreviewed
  - type/gotcha
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

**Step 5: Create context template**

`vault-seed/_templates/context.md`:

```markdown
---
title: ""
date_created:
type: context
tags:
  - status/unreviewed
  - type/context
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

**Step 6: Create progress template**

`vault-seed/_templates/progress.md`:

```markdown
---
title: ""
date_created:
type: progress
tags:
  - status/unreviewed
  - type/progress
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

**Step 7: Commit**

```bash
git add vault-seed/
git commit -m "feat: vault seed with folder structure and note templates"
```

---

### Task 3: Vault Seed — Obsidian Bases MOCs

**Files:**

- Create: `vault-seed/05-MOCs/Inbox.base`
- Create: `vault-seed/05-MOCs/Decisions.base`
- Create: `vault-seed/05-MOCs/Patterns.base`
- Create: `vault-seed/05-MOCs/Gotchas.base`
- Create: `vault-seed/05-MOCs/Context.base`
- Create: `vault-seed/05-MOCs/Progress.base`
- Create: `vault-seed/05-MOCs/By-Project.base`
- Create: `vault-seed/05-MOCs/Recent-Activity.base`

Refer to the obsidian-bases skill at `~/.pi/agent/skills/obsidian-bases/SKILL.md` for syntax. Key rules: use single quotes for formulas containing double quotes, guard nullable properties with `if()`, access `.days` on duration before calling `.round()`.

**Step 1: Create Inbox.base**

```yaml
filters:
  and:
    - file.inFolder("00-Inbox")
    - file.hasTag("status/unreviewed")

formulas:
  age_days: "(now() - file.ctime).days.round(0)"

properties:
  formula.age_days:
    displayName: "Age (days)"

views:
  - type: table
    name: "Unreviewed Notes"
    order:
      - file.name
      - type
      - source_project
      - confidence
      - formula.age_days
    groupBy:
      property: type
      direction: ASC
```

**Step 2: Create Decisions.base**

```yaml
filters:
  and:
    - file.hasTag("type/decision")
    - 'file.ext == "md"'

formulas:
  age_days: "(now() - file.ctime).days.round(0)"

properties:
  formula.age_days:
    displayName: "Age (days)"

views:
  - type: table
    name: "All Decisions"
    order:
      - file.name
      - source_project
      - confidence
      - date_created
      - formula.age_days
    groupBy:
      property: source_project
      direction: ASC
```

**Step 3: Create Patterns.base**

```yaml
filters:
  and:
    - file.hasTag("type/pattern")
    - 'file.ext == "md"'

formulas:
  age_days: "(now() - file.ctime).days.round(0)"

properties:
  formula.age_days:
    displayName: "Age (days)"

views:
  - type: table
    name: "All Patterns"
    order:
      - file.name
      - source_project
      - confidence
      - date_created
      - formula.age_days
```

**Step 4: Create Gotchas.base**

```yaml
filters:
  and:
    - file.hasTag("type/gotcha")
    - 'file.ext == "md"'

formulas:
  age_days: "(now() - file.ctime).days.round(0)"

properties:
  formula.age_days:
    displayName: "Age (days)"

views:
  - type: table
    name: "All Gotchas"
    order:
      - file.name
      - source_project
      - confidence
      - date_created
      - formula.age_days
```

**Step 5: Create Context.base**

```yaml
filters:
  and:
    - file.hasTag("type/context")
    - 'file.ext == "md"'

formulas:
  age_days: "(now() - file.ctime).days.round(0)"
  decay_status: 'if(file.hasTag("status/decayed"), "⚠️ Decayed", "✓ Active")'

properties:
  formula.age_days:
    displayName: "Age (days)"
  formula.decay_status:
    displayName: "Status"

views:
  - type: table
    name: "All Context"
    order:
      - file.name
      - source_project
      - confidence
      - formula.decay_status
      - formula.age_days
```

**Step 6: Create Progress.base**

```yaml
filters:
  and:
    - file.hasTag("type/progress")
    - 'file.ext == "md"'

formulas:
  age_days: "(now() - file.ctime).days.round(0)"
  decay_status: 'if(file.hasTag("status/decayed"), "⚠️ Decayed", "✓ Active")'

properties:
  formula.age_days:
    displayName: "Age (days)"
  formula.decay_status:
    displayName: "Status"

views:
  - type: table
    name: "All Progress"
    order:
      - file.name
      - source_project
      - formula.decay_status
      - date_created
      - formula.age_days
```

**Step 7: Create By-Project.base**

```yaml
filters:
  not:
    - file.hasTag("status/archived")
    - file.hasTag("status/decayed")

formulas:
  age_days: "(now() - file.ctime).days.round(0)"

properties:
  formula.age_days:
    displayName: "Age (days)"

views:
  - type: table
    name: "Notes by Project"
    order:
      - file.name
      - type
      - confidence
      - formula.age_days
    groupBy:
      property: source_project
      direction: ASC
```

**Step 8: Create Recent-Activity.base**

```yaml
filters:
  and:
    - 'file.ext == "md"'
  not:
    - file.hasTag("status/archived")

formulas:
  age_days: "(now() - file.ctime).days.round(0)"

properties:
  formula.age_days:
    displayName: "Age (days)"

views:
  - type: table
    name: "Recent Activity"
    limit: 30
    order:
      - file.name
      - type
      - source_project
      - confidence
      - formula.age_days
```

**Step 9: Remove the .gitkeep from 05-MOCs since it now has real files**

```bash
rm vault-seed/05-MOCs/.gitkeep
```

**Step 10: Commit**

```bash
git add vault-seed/05-MOCs/
git commit -m "feat: Obsidian Bases MOCs for inbox, types, project, and activity views"
```

---

### Task 4: Sediment-Writer Skill

**Files:**

- Create: `skills/sediment-writer/SKILL.md`
- Create: `skills/sediment-writer/references/templates.md`
- Create: `skills/sediment-writer/references/tag-taxonomy.md`
- Create: `skills/sediment-writer/references/examples.md`

**Step 1: Create SKILL.md**

`skills/sediment-writer/SKILL.md`:

The main skill file with frontmatter and instructions. Contains:

- `name: sediment-writer`
- `description` matching distillation/capture triggers
- Process: evaluate → extract → deduplicate → write → link
- Capture vs. skip guidance table
- File naming convention (`YYYYMMDDHHmm-slugified-title.md`)
- Uses `VAULT_PATH_PLACEHOLDER` (replaced by install script)
- References `templates.md`, `tag-taxonomy.md`, `examples.md`

Full content as specified in the design doc's Section 5.

**Step 2: Create references/templates.md**

`skills/sediment-writer/references/templates.md`:

Contains all five note templates (decision, pattern, gotcha, context, progress) with complete frontmatter and section structure. This is the reference the agent consults when writing notes. Copy the template content from the vault-seed templates but formatted as reference documentation with explanations of each field.

**Step 3: Create references/tag-taxonomy.md**

`skills/sediment-writer/references/tag-taxonomy.md`:

Contains the full tag taxonomy:

- Status tags (unreviewed, reviewed, archived, decayed)
- Type tags (decision, pattern, gotcha, context, progress)
- Topic tags (freeform convention)
- Project tags (freeform, derived from source_project)
- Guidelines: always include `status/unreviewed` on new notes, always include `type/<type>`, add at least one `topic/` or `project/` tag.

**Step 4: Create references/examples.md**

`skills/sediment-writer/references/examples.md`:

Three fully-worked example notes:

1. A **decision** ADR — e.g., "Chose PostgreSQL over MongoDB for user data" with context, alternatives, and consequences.
2. A **pattern** note — e.g., "Retry with exponential backoff for external APIs" with when-to-use and trade-offs.
3. A **gotcha** note — e.g., "Prisma requires explicit JsonValue cast for JSONB columns" with root cause and fix.

Each example shows complete frontmatter with realistic tags, wikilinks in the body, and proper file naming.

**Step 5: Commit**

```bash
git add skills/
git commit -m "feat: sediment-writer skill with templates, taxonomy, and examples"
```

---

### Task 5: Shared Scripts — Confidence Decay

**Files:**

- Create: `scripts/sediment-decay.sh`

**Step 1: Write the decay script**

`scripts/sediment-decay.sh`:

```bash
#!/bin/bash
# Scan 00-Inbox/ for notes past their decay threshold.
# Progress notes decay after 7 days, context after 30 days.
# Decisions, patterns, and gotchas never decay.
# Decay = replace status/unreviewed with status/decayed.
# Only operates on 00-Inbox/ — promoted notes are permanent.
#
# Usage: sediment-decay.sh
# Reads vault_path from ~/.sediment/config.json

set -euo pipefail

CONFIG="$HOME/.sediment/config.json"
[ -f "$CONFIG" ] || exit 0

VAULT_PATH=$(jq -r '.vault_path' "$CONFIG")
INBOX="$VAULT_PATH/00-Inbox"
[ -d "$INBOX" ] || exit 0

NOW=$(date +%s)

for note in "$INBOX"/*.md; do
  [ -f "$note" ] || continue

  # Skip already decayed
  grep -q "status/decayed" "$note" && continue

  # Extract type and date_created from frontmatter (predictable format)
  TYPE=$(grep "^type:" "$note" | head -1 | sed 's/^type:[[:space:]]*//')
  DATE_RAW=$(grep "^date_created:" "$note" | head -1 | sed 's/^date_created:[[:space:]]*//')

  [ -z "$TYPE" ] || [ -z "$DATE_RAW" ] && continue

  # Extract just the date portion (handle both YYYY-MM-DD and ISO 8601)
  DATE=$(echo "$DATE_RAW" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | head -1)
  [ -z "$DATE" ] && continue

  # Calculate age in days (macOS and GNU date)
  if date -j -f "%Y-%m-%d" "$DATE" +%s >/dev/null 2>&1; then
    NOTE_TS=$(date -j -f "%Y-%m-%d" "$DATE" +%s)
  elif date -d "$DATE" +%s >/dev/null 2>&1; then
    NOTE_TS=$(date -d "$DATE" +%s)
  else
    continue
  fi

  AGE_DAYS=$(( (NOW - NOTE_TS) / 86400 ))

  # Apply decay rules
  DECAY=false
  [ "$TYPE" = "progress" ] && [ "$AGE_DAYS" -gt 7 ] && DECAY=true
  [ "$TYPE" = "context" ] && [ "$AGE_DAYS" -gt 30 ] && DECAY=true

  if [ "$DECAY" = "true" ]; then
    sed -i.bak 's|status/unreviewed|status/decayed|' "$note"
    rm -f "${note}.bak"
  fi
done
```

**Step 2: Make executable and commit**

```bash
chmod +x scripts/sediment-decay.sh
git add scripts/sediment-decay.sh
git commit -m "feat: confidence decay script for inbox notes"
```

---

### Task 6: Shared Scripts — Context Injection

**Files:**

- Create: `scripts/sediment-context.sh`

**Step 1: Write the context injection script**

`scripts/sediment-context.sh`:

```bash
#!/bin/bash
# Read vault notes relevant to the current project and output
# a compact summary for agent context injection.
#
# Usage: sediment-context.sh [cwd]
# Reads vault_path from ~/.sediment/config.json
# Outputs formatted text to stdout (consumed by hooks/extensions)

set -euo pipefail

CONFIG="$HOME/.sediment/config.json"
[ -f "$CONFIG" ] || exit 0

VAULT_PATH=$(jq -r '.vault_path' "$CONFIG")
CWD="${1:-$(pwd)}"
MAX_NOTES=15

# Derive project name from cwd (last path component)
PROJECT_NAME=$(basename "$CWD")

# Collect matching notes from non-archived folders
FOLDERS=("$VAULT_PATH/00-Inbox" "$VAULT_PATH/01-Decisions" "$VAULT_PATH/02-Patterns" "$VAULT_PATH/03-Reference")

# Arrays for each type
declare -a DECISIONS=()
declare -a PATTERNS=()
declare -a GOTCHAS=()
declare -a CONTEXT=()
declare -a PROGRESS=()

count=0

for folder in "${FOLDERS[@]}"; do
  [ -d "$folder" ] || continue
  for note in "$folder"/*.md; do
    [ -f "$note" ] || continue
    [ "$count" -ge "$MAX_NOTES" ] && break 2

    # Skip decayed and archived
    grep -q "status/decayed" "$note" && continue
    grep -q "status/archived" "$note" && continue

    # Check if note matches current project (by source_project or project/ tag)
    SOURCE_PROJ=$(grep "^source_project:" "$note" 2>/dev/null | head -1 | sed 's/^source_project:[[:space:]]*//' | tr -d '"')
    HAS_PROJECT_TAG=$(grep -c "project/$PROJECT_NAME" "$note" 2>/dev/null || true)

    # Include if project matches OR note is recent (last 7 days) with high confidence
    MATCHES_PROJECT=false
    if [ -n "$SOURCE_PROJ" ] && echo "$SOURCE_PROJ" | grep -qi "$PROJECT_NAME"; then
      MATCHES_PROJECT=true
    fi
    if [ "$HAS_PROJECT_TAG" -gt 0 ]; then
      MATCHES_PROJECT=true
    fi

    # For non-matching projects, only include if recent and high confidence
    if [ "$MATCHES_PROJECT" = "false" ]; then
      CONF=$(grep "^confidence:" "$note" 2>/dev/null | head -1 | sed 's/^confidence:[[:space:]]*//')
      DATE_RAW=$(grep "^date_created:" "$note" 2>/dev/null | head -1 | sed 's/^date_created:[[:space:]]*//')
      DATE=$(echo "$DATE_RAW" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | head -1)

      [ -z "$CONF" ] || [ -z "$DATE" ] && continue

      # Check if confidence >= 0.85 and age <= 7 days
      CONF_INT=$(echo "$CONF" | awk '{printf "%d", $1 * 100}')
      [ "$CONF_INT" -lt 85 ] && continue

      NOW=$(date +%s)
      if date -j -f "%Y-%m-%d" "$DATE" +%s >/dev/null 2>&1; then
        NOTE_TS=$(date -j -f "%Y-%m-%d" "$DATE" +%s)
      elif date -d "$DATE" +%s >/dev/null 2>&1; then
        NOTE_TS=$(date -d "$DATE" +%s)
      else
        continue
      fi
      AGE_DAYS=$(( (NOW - NOTE_TS) / 86400 ))
      [ "$AGE_DAYS" -gt 7 ] && continue
    fi

    # Extract title and type
    TITLE=$(grep "^title:" "$note" 2>/dev/null | head -1 | sed 's/^title:[[:space:]]*//' | tr -d '"')
    TYPE=$(grep "^type:" "$note" 2>/dev/null | head -1 | sed 's/^type:[[:space:]]*//')
    BASENAME=$(basename "$note" .md)

    [ -z "$TITLE" ] && TITLE="$BASENAME"
    [ -z "$TYPE" ] && continue

    # Calculate age for display
    DATE_RAW=$(grep "^date_created:" "$note" 2>/dev/null | head -1 | sed 's/^date_created:[[:space:]]*//')
    DATE=$(echo "$DATE_RAW" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | head -1)
    AGE_LABEL=""
    if [ -n "$DATE" ]; then
      NOW=$(date +%s)
      if date -j -f "%Y-%m-%d" "$DATE" +%s >/dev/null 2>&1; then
        NOTE_TS=$(date -j -f "%Y-%m-%d" "$DATE" +%s)
      elif date -d "$DATE" +%s >/dev/null 2>&1; then
        NOTE_TS=$(date -d "$DATE" +%s)
      else
        NOTE_TS=$NOW
      fi
      AGE_DAYS=$(( (NOW - NOTE_TS) / 86400 ))
      if [ "$AGE_DAYS" -eq 0 ]; then
        AGE_LABEL="today"
      elif [ "$AGE_DAYS" -eq 1 ]; then
        AGE_LABEL="1 day ago"
      else
        AGE_LABEL="${AGE_DAYS} days ago"
      fi
    fi

    ENTRY="- [[${BASENAME}]]: ${TITLE} (${AGE_LABEL})"

    case "$TYPE" in
      decision) DECISIONS+=("$ENTRY") ;;
      pattern)  PATTERNS+=("$ENTRY") ;;
      gotcha)   GOTCHAS+=("$ENTRY") ;;
      context)  CONTEXT+=("$ENTRY") ;;
      progress) PROGRESS+=("$ENTRY") ;;
    esac

    count=$((count + 1))
  done
done

# Output nothing if no notes found
[ "$count" -eq 0 ] && exit 0

echo "[Sediment] Relevant notes from your vault:"
echo ""

for TYPE_NAME in DECISIONS PATTERNS GOTCHAS CONTEXT PROGRESS; do
  declare -n arr="$TYPE_NAME"
  if [ "${#arr[@]}" -gt 0 ]; then
    echo "${TYPE_NAME}:"
    for entry in "${arr[@]}"; do
      echo "$entry"
    done
    echo ""
  fi
done
```

**Step 2: Make executable and commit**

```bash
chmod +x scripts/sediment-context.sh
git add scripts/sediment-context.sh
git commit -m "feat: context injection script for session-start retrieval"
```

---

### Task 7: Shared Scripts — Capture Hook (Claude Code)

**Files:**

- Create: `scripts/sediment-capture.sh`

**Step 1: Write the capture script**

`scripts/sediment-capture.sh`:

```bash
#!/bin/bash
# Claude Code Stop hook: blocks the agent from stopping and instructs
# it to distill the session. Uses stop_hook_active to prevent loops.
#
# Reads JSON from stdin (Claude Code hook input).
# Outputs JSON decision to stdout.

set -euo pipefail

SESSIONS_DIR="$HOME/.sediment/sessions"
mkdir -p "$SESSIONS_DIR"

INPUT=$(cat)
STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active')
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id')

# Already continuing from a stop hook — allow stop, mark distilled
if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
  touch "$SESSIONS_DIR/$SESSION_ID.distilled"
  exit 0
fi

# Already distilled this session — allow stop
if [ -f "$SESSIONS_DIR/$SESSION_ID.distilled" ]; then
  exit 0
fi

# Read vault path from config
CONFIG="$HOME/.sediment/config.json"
if [ ! -f "$CONFIG" ]; then
  exit 0
fi
VAULT_PATH=$(jq -r '.vault_path' "$CONFIG")

# Block stop and instruct distillation
jq -n --arg vault "$VAULT_PATH" '{
  decision: "block",
  reason: ("Before ending, follow the sediment-writer skill to distill this session into your Obsidian vault. Evaluate whether any decisions, patterns, gotchas, context, or progress are worth capturing. If nothing meaningful occurred in this session, just say so and stop. Write any notes to " + $vault + "/00-Inbox/.")
}'
```

**Step 2: Make executable and commit**

```bash
chmod +x scripts/sediment-capture.sh
git add scripts/sediment-capture.sh
git commit -m "feat: capture hook script for Claude Code Stop event"
```

---

### Task 8: Pi Extension

**Files:**

- Create: `extensions/sediment/index.ts`

**Step 1: Write the Pi extension**

`extensions/sediment/index.ts`:

```typescript
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import * as fs from "node:fs";
import * as path from "node:path";

export default function (pi: ExtensionAPI) {
  const home = process.env.HOME!;
  const configPath = path.join(home, ".sediment/config.json");
  const sessionsDir = path.join(home, ".sediment/sessions");
  const scriptsDir = path.join(home, ".sediment/scripts");

  function readConfig(): { vault_path: string } | null {
    try {
      return JSON.parse(fs.readFileSync(configPath, "utf-8"));
    } catch {
      return null;
    }
  }

  // --- Confidence decay + context injection at session start ---
  pi.on("session_start", async (_event, ctx) => {
    // Run decay script
    const decayScript = path.join(scriptsDir, "sediment-decay.sh");
    if (fs.existsSync(decayScript)) {
      await pi.exec("bash", [decayScript], { timeout: 10000 });
    }

    // Check for pending distillation from previous session
    const pendingPath = path.join(sessionsDir, "pending.json");
    if (fs.existsSync(pendingPath)) {
      try {
        const pending = JSON.parse(fs.readFileSync(pendingPath, "utf-8"));
        fs.unlinkSync(pendingPath);

        const config = readConfig();
        if (config) {
          pi.sendUserMessage(
            `A previous coding session ended without distillation. ` +
              `Follow the sediment-writer skill to distill it. ` +
              `Evaluate whether any decisions, patterns, gotchas, context, or progress are worth capturing. ` +
              `If nothing meaningful, say so and move on. ` +
              `Write any notes to ${config.vault_path}/00-Inbox/.`,
          );
        }
      } catch {
        // If pending file is corrupt, just remove it
        try {
          fs.unlinkSync(pendingPath);
        } catch {}
      }
    }
  });

  // --- Context injection before each agent turn ---
  pi.on("before_agent_start", async (event, ctx) => {
    const contextScript = path.join(scriptsDir, "sediment-context.sh");
    if (!fs.existsSync(contextScript)) return;

    const result = await pi.exec("bash", [contextScript, ctx.cwd], {
      timeout: 10000,
    });
    if (result.code === 0 && result.stdout.trim()) {
      return {
        systemPrompt: event.systemPrompt + "\n\n" + result.stdout.trim(),
      };
    }
  });

  // --- Mark session for distillation on shutdown ---
  pi.on("session_shutdown", async (_event, ctx) => {
    const config = readConfig();
    if (!config) return;

    // Only mark if session had meaningful work (3+ assistant messages)
    const entries = ctx.sessionManager.getEntries();
    const assistantCount = entries.filter(
      (e) => e.type === "message" && e.message.role === "assistant",
    ).length;
    if (assistantCount < 3) return;

    const sessionFile = ctx.sessionManager.getSessionFile();
    if (!sessionFile) return;

    fs.mkdirSync(sessionsDir, { recursive: true });
    fs.writeFileSync(
      path.join(sessionsDir, "pending.json"),
      JSON.stringify({
        sessionFile,
        timestamp: Date.now(),
      }),
    );
  });
}
```

**Step 2: Commit**

```bash
git add extensions/
git commit -m "feat: Pi extension for deferred distillation and context injection"
```

---

### Task 9: Install Script

**Files:**

- Create: `install.sh`

This is the largest task. The script is organized as functions called from `main()`.

**Step 1: Write install.sh**

`install.sh` — full implementation with these functions:

- `print_banner` — colored ASCII banner
- `check_prerequisites` — verify node, npm, git, jq; abort with install instructions if missing
- `detect_harnesses` — check for `~/.claude/` + `claude` command and `~/.pi/` + `pi` command; present checkboxes if both found; abort if neither
- `choose_install_scope` — prompt: "Global (all projects)" or "This project only"
- `detect_and_choose_vault` — read `obsidian.json` for platform; list existing vaults; offer "Create new vault"; recommend `~/Documents/Sediment/` if none found; validate path (not nested, not system folder, writable)
- `verify_obsidian` — check if Obsidian.app exists (macOS) or obsidian command (Linux); warn if not found, continue
- `install_cli_tools` — `npm install -g obsidian-cli defuddle-cli`
- `install_obsidian_skills` — clone `kepano/obsidian-skills` to temp dir; copy 5 skill directories (obsidian-markdown, obsidian-bases, json-canvas, obsidian-cli, defuddle) to harness skill locations; clean up temp dir
- `install_sediment_skill` — copy `skills/sediment-writer/` to harness skill locations; replace `VAULT_PATH_PLACEHOLDER` with actual vault path using sed
- `install_claude_code_hooks` — copy scripts to `~/.sediment/scripts/`; merge hook entries into settings.json using jq (create file if absent, merge without clobbering existing hooks)
- `install_pi_extension` — copy `extensions/sediment/` to Pi extension location
- `create_vault_structure` — copy `vault-seed/` contents to vault path (skip existing files to not overwrite user content)
- `write_config` — write `~/.sediment/config.json` with vault_path, scope, harnesses, timestamp, version
- `print_summary` — recap what was installed, where, next steps

Key implementation detail for merging Claude Code hooks into `settings.json`:

```bash
# If settings.json doesn't exist, create it with just our hooks
# If it exists, merge our hooks into existing structure using jq
if [ -f "$SETTINGS_FILE" ]; then
  jq --arg cmd "$HOME/.sediment/scripts/sediment-capture.sh" \
     --arg ctx "$HOME/.sediment/scripts/sediment-decay.sh && $HOME/.sediment/scripts/sediment-context.sh \"\$PWD\"" \
     '.hooks.Stop += [{"hooks":[{"type":"command","command":$cmd,"timeout":120}]}] |
      .hooks.SessionStart += [{"hooks":[{"type":"command","command":$ctx}]}]' \
     "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp" && mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
else
  # Create new settings.json with hooks
fi
```

**Step 2: Make executable and commit**

```bash
chmod +x install.sh
git add install.sh
git commit -m "feat: install script for Sediment setup"
```

---

### Task 10: Uninstall Script

**Files:**

- Create: `uninstall.sh`

**Step 1: Write uninstall.sh**

`uninstall.sh` — reads `~/.sediment/config.json` to determine what was installed, then reverses:

- `remove_claude_code_hooks` — use jq to remove sediment hook entries from settings.json (match by command path containing "sediment")
- `remove_pi_extension` — remove the sediment extension directory
- `remove_skills` — remove sediment-writer and the 5 kepano skills from harness skill locations
- `remove_sediment_dir` — `rm -rf ~/.sediment/`
- Does NOT touch the vault
- Does NOT uninstall CLI tools (obsidian-cli, defuddle-cli)
- Prints summary of what was removed

**Step 2: Make executable and commit**

```bash
chmod +x uninstall.sh
git add uninstall.sh
git commit -m "feat: uninstall script to reverse Sediment setup"
```

---

### Task 11: README

**Files:**

- Modify: `README.md`

**Step 1: Write full README**

Replace the placeholder README with complete documentation:

- **What Sediment is** — one-paragraph description
- **How it works** — brief architecture explanation (capture → structure → retrieval)
- **Prerequisites** — Node.js, npm, git, jq, Obsidian (manual install)
- **Installation** — `git clone` + `./install.sh`
- **What gets installed** — table showing what goes where
- **Vault structure** — folder layout explanation
- **Note types** — decision, pattern, gotcha, context, progress with brief descriptions
- **How capture works** — Claude Code (Stop hook) vs Pi (deferred distillation)
- **How retrieval works** — context injection at session start
- **Confidence decay** — rules for progress and context notes
- **Reviewing notes** — how to promote from inbox, how MOCs work
- **Uninstalling** — `./uninstall.sh`
- **License** — AGPL-3.0-or-later

**Step 2: Commit**

```bash
git add README.md
git commit -m "docs: complete README with architecture, usage, and review guide"
```

---

### Task 12: Verify Complete Repo Structure

**Step 1: Verify file tree matches design**

```bash
find . -not -path './.git/*' -not -name '.DS_Store' | sort
```

Expected:

```
.
./README.md
./LICENSE
./.gitignore
./install.sh
./uninstall.sh
./docs/plans/2026-03-04-sediment-design.md
./docs/plans/2026-03-04-sediment-implementation.md
./scripts/sediment-capture.sh
./scripts/sediment-context.sh
./scripts/sediment-decay.sh
./extensions/sediment/index.ts
./skills/sediment-writer/SKILL.md
./skills/sediment-writer/references/templates.md
./skills/sediment-writer/references/tag-taxonomy.md
./skills/sediment-writer/references/examples.md
./vault-seed/00-Inbox/.gitkeep
./vault-seed/01-Decisions/.gitkeep
./vault-seed/02-Patterns/.gitkeep
./vault-seed/03-Reference/.gitkeep
./vault-seed/04-Archive/.gitkeep
./vault-seed/05-MOCs/Inbox.base
./vault-seed/05-MOCs/Decisions.base
./vault-seed/05-MOCs/Patterns.base
./vault-seed/05-MOCs/Gotchas.base
./vault-seed/05-MOCs/Context.base
./vault-seed/05-MOCs/Progress.base
./vault-seed/05-MOCs/By-Project.base
./vault-seed/05-MOCs/Recent-Activity.base
./vault-seed/_templates/decision.md
./vault-seed/_templates/pattern.md
./vault-seed/_templates/gotcha.md
./vault-seed/_templates/context.md
./vault-seed/_templates/progress.md
./vault-seed/_attachments/.gitkeep
```

**Step 2: Dry-run install script on a test path**

```bash
# Verify script runs without errors in dry-run / test mode
bash -n install.sh   # syntax check
bash -n uninstall.sh # syntax check
```

**Step 3: Final commit if any fixes needed**

```bash
git add -A
git commit -m "chore: final verification and cleanup"
```
