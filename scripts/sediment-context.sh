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

# Temp files for each type (avoids bash 4.3+ declare -n requirement)
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
      decision) echo "$ENTRY" >> "$TMP_DIR/decisions" ;;
      pattern)  echo "$ENTRY" >> "$TMP_DIR/patterns" ;;
      gotcha)   echo "$ENTRY" >> "$TMP_DIR/gotchas" ;;
      context)  echo "$ENTRY" >> "$TMP_DIR/context" ;;
      progress) echo "$ENTRY" >> "$TMP_DIR/progress" ;;
    esac

    count=$((count + 1))
  done
done

# Output nothing if no notes found
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
