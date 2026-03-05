#!/bin/bash
# Claude Code Stop hook — intercepts the agent before it exits and asks
# it to distill the session into the vault.
#
# The trick: Claude Code's Stop hook can return { decision: "block" }
# to prevent the agent from stopping and inject a reason message.
# On the second pass, stop_hook_active is true — we let it through.
# This gives us exactly one distillation per session without loops.
#
# Input:  JSON on stdin (Claude Code hook payload)
# Output: JSON on stdout ({ decision: "block", reason: "..." } or nothing)

set -euo pipefail

SESSIONS_DIR="$HOME/.sediment/sessions"
mkdir -p "$SESSIONS_DIR"

INPUT=$(cat)
STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active')
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id')

# Second pass: the agent just finished distilling. Mark it done and
# let the stop proceed. The .distilled marker prevents re-triggering
# if the hook fires again in the same session.
if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
  touch "$SESSIONS_DIR/$SESSION_ID.distilled"
  rm -f "$SESSIONS_DIR/$SESSION_ID.compacted"
  exit 0
fi

# Already distilled (e.g., user ran /stop twice) — nothing to do
if [ -f "$SESSIONS_DIR/$SESSION_ID.distilled" ]; then
  exit 0
fi

CONFIG="$HOME/.sediment/config.json"
if [ ! -f "$CONFIG" ]; then
  exit 0
fi
VAULT_PATH=$(jq -r '.vault_path' "$CONFIG")

# If compaction happened mid-session, the early conversation is now a
# summary. We tell the agent to pay extra attention to that summary
# so knowledge from the compressed portion isn't lost.
COMPACTION_NOTE=""
if [ -f "$SESSIONS_DIR/$SESSION_ID.compacted" ]; then
  COMPACTION_NOTE=" Note: a compaction occurred during this session, so earlier conversation details have been compressed. Pay extra attention to the compaction summary for knowledge from the compacted portion."
  rm -f "$SESSIONS_DIR/$SESSION_ID.compacted"
fi

# Block the stop and hand control back to the agent with distillation
# instructions. The agent follows the sediment-writer skill, writes
# any notes, then stops — which triggers this hook again with
# stop_hook_active=true, letting it exit cleanly.
jq -n --arg vault "$VAULT_PATH" --arg note "$COMPACTION_NOTE" '{
  decision: "block",
  reason: ("Before ending, follow the sediment-writer skill to distill this session into your Obsidian vault." + $note + " Evaluate whether any decisions, patterns, gotchas, context, or progress are worth capturing. If nothing meaningful occurred in this session, just say so and stop. Write any notes to " + $vault + "/00-Inbox/.")
}'
