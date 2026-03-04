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
