#!/bin/bash
# Sediment Uninstaller
# Reverses install.sh: removes hooks, extensions, skills, and ~/.sediment/.
# Does NOT touch the vault or uninstall CLI tools.

set -euo pipefail

SEDIMENT_DIR="$HOME/.sediment"
CONFIG="$SEDIMENT_DIR/config.json"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

info()  { echo -e "${BLUE}→${NC} $1"; }
ok()    { echo -e "${GREEN}✓${NC} $1"; }
warn()  { echo -e "${YELLOW}⚠${NC} $1"; }

# ─── Read Config ──────────────────────────────────────────────────────────────

if [ ! -f "$CONFIG" ]; then
  echo -e "${RED}✗${NC} Sediment is not installed ($CONFIG not found)."
  exit 1
fi

INSTALL_SCOPE=$(jq -r '.install_scope' "$CONFIG")
VAULT_PATH=$(jq -r '.vault_path' "$CONFIG")
HARNESSES=()
while IFS= read -r h; do
  HARNESSES+=("$h")
done < <(jq -r '.harnesses[]' "$CONFIG")

echo ""
echo -e "${BOLD}Uninstalling Sediment${NC}"
echo ""
echo "  Scope:     $INSTALL_SCOPE"
echo "  Harnesses: ${HARNESSES[*]}"
echo "  Vault:     $VAULT_PATH (will NOT be deleted)"
echo ""

# ─── Helpers ──────────────────────────────────────────────────────────────────

get_skills_dir() {
  local harness="$1"
  if [ "$harness" = "claude-code" ]; then
    if [ "$INSTALL_SCOPE" = "global" ]; then
      echo "$HOME/.claude/skills"
    else
      echo ".claude/skills"
    fi
  elif [ "$harness" = "pi" ]; then
    if [ "$INSTALL_SCOPE" = "global" ]; then
      echo "$HOME/.pi/agent/skills"
    else
      echo ".pi/skills"
    fi
  fi
}

# ─── Remove Claude Code Hooks ────────────────────────────────────────────────

remove_claude_code_hooks() {
  [[ " ${HARNESSES[*]} " == *" claude-code "* ]] || return 0

  info "Removing Claude Code hooks..."

  local settings_file
  if [ "$INSTALL_SCOPE" = "global" ]; then
    settings_file="$HOME/.claude/settings.json"
  else
    settings_file=".claude/settings.json"
  fi

  if [ -f "$settings_file" ]; then
    # Remove hook entries whose command contains "sediment"
    local updated
    updated=$(jq '
      if .hooks then
        .hooks |= with_entries(
          .value |= map(
            select(
              .hooks | all(
                .command | test("sediment") | not
              )
            )
          )
        ) |
        .hooks |= with_entries(select(.value | length > 0))
      else . end |
      if .hooks == {} then del(.hooks) else . end
    ' "$settings_file")
    echo "$updated" > "$settings_file"
    ok "Claude Code hooks removed"
  else
    warn "Settings file not found: $settings_file"
  fi
}

# ─── Remove Pi Extension ─────────────────────────────────────────────────────

remove_pi_extension() {
  [[ " ${HARNESSES[*]} " == *" pi "* ]] || return 0

  info "Removing Pi extension..."

  local ext_dir
  if [ "$INSTALL_SCOPE" = "global" ]; then
    ext_dir="$HOME/.pi/agent/extensions/sediment"
  else
    ext_dir=".pi/extensions/sediment"
  fi

  if [ -d "$ext_dir" ]; then
    rm -rf "$ext_dir"
    ok "Pi extension removed"
  else
    warn "Extension not found: $ext_dir"
  fi
}

# ─── Remove Skills ───────────────────────────────────────────────────────────

remove_skills() {
  info "Removing skills..."

  local skill_names=("sediment-writer" "obsidian-markdown" "obsidian-bases" "json-canvas" "obsidian-cli" "defuddle")

  for harness in "${HARNESSES[@]}"; do
    local skills_dir
    skills_dir="$(get_skills_dir "$harness")"

    for skill in "${skill_names[@]}"; do
      if [ -d "$skills_dir/$skill" ]; then
        rm -rf "$skills_dir/$skill"
      fi
    done
  done

  ok "Skills removed"
}

# ─── Remove Sediment Directory ────────────────────────────────────────────────

remove_sediment_dir() {
  info "Removing $SEDIMENT_DIR..."
  rm -rf "$SEDIMENT_DIR"
  ok "Sediment directory removed"
}

# ─── Summary ──────────────────────────────────────────────────────────────────

print_summary() {
  echo ""
  echo -e "${GREEN}${BOLD}  Sediment uninstalled.${NC}"
  echo ""
  echo "  Your vault at $VAULT_PATH was left intact."
  echo "  CLI tool (defuddle-cli) was left installed."
  echo ""
  echo "  To remove it manually:"
  echo "    npm uninstall -g defuddle-cli"
  echo ""
}

# ─── Main ─────────────────────────────────────────────────────────────────────

remove_claude_code_hooks
remove_pi_extension
remove_skills
remove_sediment_dir
print_summary
