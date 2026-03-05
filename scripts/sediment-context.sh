#!/bin/bash
# Build a compact summary of vault notes relevant to the current project
# and output it to stdout. Hooks and extensions inject this into the
# agent's system prompt at session start so it has prior knowledge.
#
# Relevance strategy:
#   1. Notes whose source_project or project/ tag matches the cwd → always
#   2. Notes from other projects → only if high confidence (≥0.85) and
#      recent (≤7 days), for cross-project pollination
#
# Usage: sediment-context.sh [cwd]

set -euo pipefail

CONFIG="$HOME/.sediment/config.json"
[ -f "$CONFIG" ] || exit 0

VAULT_PATH=$(jq -r '.vault_path' "$CONFIG")
CWD="${1:-$(pwd)}"

# Cap output size — too many notes dilute agent attention
MAX_NOTES=15

# Match notes by project directory name (e.g., "sediment" from /Users/.../sediment)
PROJECT_NAME=$(basename "$CWD")

# Only scan active folders — 04-Archive is excluded on purpose
FOLDERS=("$VAULT_PATH/00-Inbox" "$VAULT_PATH/01-Decisions" "$VAULT_PATH/02-Patterns" "$VAULT_PATH/03-Reference")

# Collect entries per type into temp files. We avoid associative arrays
# because macOS ships bash 3.2 which doesn't support them reliably.
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT
for t in decisions patterns gotchas context progress; do
  : > "$TMP_DIR/$t"
done

count=0

for folder in "${FOLDERS[@]}"; do
  [ -d "$folder" ] || continue
  for note in "$folder"/*.md; do
    [ -f "$note" ] || continue
    [ "$count" -ge "$MAX_NOTES" ] && break 2

    # Decayed and archived notes are no longer useful for context
    grep -q "status/decayed" "$note" && continue
    grep -q "status/archived" "$note" && continue

    # Two ways a note can match the current project: the source_project
    # frontmatter field, or a project/ tag anywhere in the file
    SOURCE_PROJ=$(grep "^source_project:" "$note" 2>/dev/null | head -1 | sed 's/^source_project:[[:space:]]*//' | tr -d '"')
    HAS_PROJECT_TAG=$(grep -c "project/$PROJECT_NAME" "$note" 2>/dev/null || true)

    MATCHES_PROJECT=false
    if [ -n "$SOURCE_PROJ" ] && echo "$SOURCE_PROJ" | grep -qi "$PROJECT_NAME"; then
      MATCHES_PROJECT=true
    fi
    if [ "$HAS_PROJECT_TAG" -gt 0 ]; then
      MATCHES_PROJECT=true
    fi

    # Cross-project notes only qualify if they're recent and high-value.
    # This prevents stale notes from unrelated projects from cluttering
    # context, while still surfacing fresh insights that might apply.
    if [ "$MATCHES_PROJECT" = "false" ]; then
      CONF=$(grep "^confidence:" "$note" 2>/dev/null | head -1 | sed 's/^confidence:[[:space:]]*//')
      DATE_RAW=$(grep "^date_created:" "$note" 2>/dev/null | head -1 | sed 's/^date_created:[[:space:]]*//')
      DATE=$(echo "$DATE_RAW" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | head -1)

      [ -z "$CONF" ] || [ -z "$DATE" ] && continue

      CONF_INT=$(echo "$CONF" | awk '{printf "%d", $1 * 100}')
      [ "$CONF_INT" -lt 85 ] && continue

      NOW=$(date +%s)
      # macOS uses -j -f, GNU/Linux uses -d — try both
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

    TITLE=$(grep "^title:" "$note" 2>/dev/null | head -1 | sed 's/^title:[[:space:]]*//' | tr -d '"')
    TYPE=$(grep "^type:" "$note" 2>/dev/null | head -1 | sed 's/^type:[[:space:]]*//')
    BASENAME=$(basename "$note" .md)

    [ -z "$TITLE" ] && TITLE="$BASENAME"
    [ -z "$TYPE" ] && continue

    # Human-readable age gives the agent a sense of how fresh each note is
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

    # Wikilink format so agents can reference the note later
    ENTRY="- [[${BASENAME}]]: ${TITLE} (${AGE_LABEL})"

    case "$TYPE" in
      decision) echo "$ENTRY" >> "$TMP_DIR/decisions" ;;
      pattern)  echo "$ENTRY" >> "$TMP_DIR/patterns" ;;
      gotcha)   echo "$ENTRY" >> "$TMP_DIR/gotchas" ;;
      context)  echo "$ENTRY" >> "$TMP_DIR/context" ;;
      progress) echo "$ENTRY" >> "$TMP_DIR/progress" ;;
    esac

    count=$((count + 1))
  done
done

# No notes = no output. Hooks treat empty stdout as "nothing to inject".
[ "$count" -eq 0 ] && exit 0

echo "[Sediment] Relevant notes from your vault:"
echo ""

for TYPE_NAME in DECISIONS PATTERNS GOTCHAS CONTEXT PROGRESS; do
  TYPE_FILE=$(echo "$TYPE_NAME" | tr '[:upper:]' '[:lower:]')
  if [ -s "$TMP_DIR/$TYPE_FILE" ]; then
    echo "${TYPE_NAME}:"
    cat "$TMP_DIR/$TYPE_FILE"
    echo ""
  fi
done
