#!/bin/bash
# Claude Code PreCompact hook: marks that compaction is about to happen
# so the Stop hook can reference it during distillation. The Stop hook
# uses this marker to tell Claude to pay attention to the compaction
# summary, improving note quality for the compacted portion.
#
# Reads JSON from stdin (Claude Code hook input).

set -euo pipefail

SESSIONS_DIR="$HOME/.sediment/sessions"
mkdir -p "$SESSIONS_DIR"

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id')

touch "$SESSIONS_DIR/$SESSION_ID.compacted"
