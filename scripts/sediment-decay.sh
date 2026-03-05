#!/bin/bash
# Decay stale inbox notes so they stop appearing in agent context.
#
# Not every note stays relevant. Progress notes ("what I did today")
# lose value in about a week. Context notes ("how the auth system works")
# go stale in about a month. Decisions, patterns, and gotchas tend to
# hold indefinitely, so they never auto-decay.
#
# Only 00-Inbox/ is scanned — notes promoted to 01-03 are considered
# human-verified and permanent. Decay is non-destructive: it flips the
# status tag from unreviewed to decayed, and the context script filters
# decayed notes out. No files are moved or deleted.
#
# Runs at session start (before context injection) so the agent never
# sees stale notes.

set -euo pipefail

CONFIG="$HOME/.sediment/config.json"
[ -f "$CONFIG" ] || exit 0

VAULT_PATH=$(jq -r '.vault_path' "$CONFIG")
INBOX="$VAULT_PATH/00-Inbox"
[ -d "$INBOX" ] || exit 0

NOW=$(date +%s)

for note in "$INBOX"/*.md; do
  [ -f "$note" ] || continue

  grep -q "status/decayed" "$note" && continue

  TYPE=$(grep "^type:" "$note" | head -1 | sed 's/^type:[[:space:]]*//')
  DATE_RAW=$(grep "^date_created:" "$note" | head -1 | sed 's/^date_created:[[:space:]]*//')

  [ -z "$TYPE" ] || [ -z "$DATE_RAW" ] && continue

  # Handle both bare dates (YYYY-MM-DD) and full ISO 8601 timestamps
  DATE=$(echo "$DATE_RAW" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | head -1)
  [ -z "$DATE" ] && continue

  # macOS uses -j -f, GNU/Linux uses -d — try both
  if date -j -f "%Y-%m-%d" "$DATE" +%s >/dev/null 2>&1; then
    NOTE_TS=$(date -j -f "%Y-%m-%d" "$DATE" +%s)
  elif date -d "$DATE" +%s >/dev/null 2>&1; then
    NOTE_TS=$(date -d "$DATE" +%s)
  else
    continue
  fi

  AGE_DAYS=$(( (NOW - NOTE_TS) / 86400 ))

  # Decay thresholds tuned to each type's typical useful lifespan
  DECAY=false
  [ "$TYPE" = "progress" ] && [ "$AGE_DAYS" -gt 7 ] && DECAY=true
  [ "$TYPE" = "context" ] && [ "$AGE_DAYS" -gt 30 ] && DECAY=true

  if [ "$DECAY" = "true" ]; then
    # In-place edit with .bak for portability (macOS sed requires it)
    sed -i.bak 's|status/unreviewed|status/decayed|' "$note"
    rm -f "${note}.bak"
  fi
done
