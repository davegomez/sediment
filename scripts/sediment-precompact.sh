#!/bin/bash
# Claude Code PreCompact hook — drops a marker file before compaction.
#
# When Claude Code compacts a conversation, early messages are compressed
# into a summary. If the Stop hook later fires for distillation, it
# checks for this marker and tells the agent to pay extra attention to
# the compaction summary. Without this, knowledge from the compressed
# portion risks being overlooked during note extraction.
#
# Input: JSON on stdin (Claude Code hook payload with session_id)

set -euo pipefail

SESSIONS_DIR="$HOME/.sediment/sessions"
mkdir -p "$SESSIONS_DIR"

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id')

# The Stop hook (sediment-capture.sh) checks for this file and cleans
# it up after incorporating the compaction note into its instructions
touch "$SESSIONS_DIR/$SESSION_ID.compacted"
