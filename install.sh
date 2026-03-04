#!/bin/bash
# Sediment Installer
# Sets up a passive second brain across Claude Code and Pi.
# See docs/plans/2026-03-04-sediment-design.md for architecture.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SEDIMENT_DIR="$HOME/.sediment"
VERSION="1.0.0"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# State
INSTALL_SCOPE=""
VAULT_PATH=""
HARNESSES=()

# ─── Helpers ──────────────────────────────────────────────────────────────────

print_banner() {
  echo ""
  echo -e "${BOLD}╔═══════════════════════════════════════╗${NC}"
  echo -e "${BOLD}║          ${BLUE}Sediment${NC} ${BOLD}v${VERSION}              ║${NC}"
  echo -e "${BOLD}║   Passive Second Brain for Coding     ║${NC}"
  echo -e "${BOLD}╚═══════════════════════════════════════╝${NC}"
  echo ""
}

info()  { echo -e "${BLUE}→${NC} $1"; }
ok()    { echo -e "${GREEN}✓${NC} $1"; }
warn()  { echo -e "${YELLOW}⚠${NC} $1"; }
fail()  { echo -e "${RED}✗${NC} $1"; exit 1; }

prompt_yn() {
  local msg="$1" default="${2:-y}"
  if [ "$default" = "y" ]; then
    read -rp "$(echo -e "${BLUE}?${NC} ${msg} [Y/n] ")" answer
    answer="${answer:-y}"
  else
    read -rp "$(echo -e "${BLUE}?${NC} ${msg} [y/N] ")" answer
    answer="${answer:-n}"
  fi
  [[ "$answer" =~ ^[Yy] ]]
}

# ─── Step 1: Prerequisites ───────────────────────────────────────────────────

check_prerequisites() {
  info "Checking prerequisites..."
  local missing=()

  command -v node  >/dev/null 2>&1 || missing+=("node")
  command -v npm   >/dev/null 2>&1 || missing+=("npm")
  command -v git   >/dev/null 2>&1 || missing+=("git")
  command -v jq    >/dev/null 2>&1 || missing+=("jq")

  if [ ${#missing[@]} -gt 0 ]; then
    fail "Missing required tools: ${missing[*]}. Install them and re-run."
  fi

  ok "All prerequisites found (node, npm, git, jq)"
}

# ─── Step 2: Detect Harnesses ────────────────────────────────────────────────

detect_harnesses() {
  info "Detecting coding harnesses..."

  local has_claude=false
  local has_pi=false

  # Claude Code: check for ~/.claude/ or claude command
  if [ -d "$HOME/.claude" ] || command -v claude >/dev/null 2>&1; then
    has_claude=true
  fi

  # Pi: check for ~/.pi/ or pi command
  if [ -d "$HOME/.pi" ] || command -v pi >/dev/null 2>&1; then
    has_pi=true
  fi

  if [ "$has_claude" = "false" ] && [ "$has_pi" = "false" ]; then
    fail "No supported harness detected. Install Claude Code or Pi first."
  fi

  if [ "$has_claude" = "true" ] && [ "$has_pi" = "true" ]; then
    echo ""
    echo "  Found both Claude Code and Pi."
    echo ""
    echo "  1) Both (recommended)"
    echo "  2) Claude Code only"
    echo "  3) Pi only"
    echo ""
    read -rp "$(echo -e "${BLUE}?${NC} Install for: [1] ")" choice
    choice="${choice:-1}"
    case "$choice" in
      1) HARNESSES=("claude-code" "pi") ;;
      2) HARNESSES=("claude-code") ;;
      3) HARNESSES=("pi") ;;
      *) HARNESSES=("claude-code" "pi") ;;
    esac
  elif [ "$has_claude" = "true" ]; then
    HARNESSES=("claude-code")
  else
    HARNESSES=("pi")
  fi

  ok "Installing for: ${HARNESSES[*]}"
}

# ─── Step 3: Install Scope ───────────────────────────────────────────────────

choose_install_scope() {
  echo ""
  echo "  1) Global — all projects (recommended)"
  echo "  2) This project only"
  echo ""
  read -rp "$(echo -e "${BLUE}?${NC} Install scope: [1] ")" choice
  choice="${choice:-1}"
  case "$choice" in
    1) INSTALL_SCOPE="global" ;;
    2) INSTALL_SCOPE="project" ;;
    *) INSTALL_SCOPE="global" ;;
  esac

  ok "Scope: $INSTALL_SCOPE"
}

# ─── Step 4: Vault Detection ─────────────────────────────────────────────────

detect_and_choose_vault() {
  info "Looking for Obsidian vaults..."

  local obsidian_json=""
  local vaults=()

  # Platform-specific obsidian.json location
  if [ "$(uname)" = "Darwin" ]; then
    obsidian_json="$HOME/Library/Application Support/obsidian/obsidian.json"
  else
    obsidian_json="$HOME/.config/obsidian/obsidian.json"
  fi

  # Read existing vaults from obsidian.json
  if [ -f "$obsidian_json" ]; then
    while IFS= read -r vault_path; do
      [ -n "$vault_path" ] && [ -d "$vault_path" ] && vaults+=("$vault_path")
    done < <(jq -r '.vaults // {} | to_entries[] | .value.path // empty' "$obsidian_json" 2>/dev/null)
  fi

  if [ ${#vaults[@]} -gt 0 ]; then
    echo ""
    echo "  Found existing Obsidian vaults:"
    echo ""
    for i in "${!vaults[@]}"; do
      echo "  $((i+1))) ${vaults[$i]}"
    done
    echo "  $((${#vaults[@]}+1))) Create new vault"
    echo ""
    read -rp "$(echo -e "${BLUE}?${NC} Choose vault: [$(( ${#vaults[@]}+1 ))] ")" choice
    choice="${choice:-$(( ${#vaults[@]}+1 ))}"

    if [ "$choice" -le "${#vaults[@]}" ] 2>/dev/null; then
      VAULT_PATH="${vaults[$((choice-1))]}"
    fi
  fi

  # New vault path
  if [ -z "$VAULT_PATH" ]; then
    local default_path="$HOME/Documents/Sediment"
    echo ""
    read -rp "$(echo -e "${BLUE}?${NC} Vault path: [$default_path] ")" custom_path
    VAULT_PATH="${custom_path:-$default_path}"
  fi

  # Expand ~ if present
  VAULT_PATH="${VAULT_PATH/#\~/$HOME}"

  # Validate path
  local parent_dir
  parent_dir="$(dirname "$VAULT_PATH")"
  if [ ! -w "$parent_dir" ] && [ ! -w "$(dirname "$parent_dir")" ]; then
    fail "Cannot write to $VAULT_PATH — parent directory is not writable."
  fi

  ok "Vault: $VAULT_PATH"
}

# ─── Step 5: Check Obsidian ──────────────────────────────────────────────────

verify_obsidian() {
  info "Checking for Obsidian..."
  local found=false

  if [ "$(uname)" = "Darwin" ]; then
    [ -d "/Applications/Obsidian.app" ] && found=true
    [ -d "$HOME/Applications/Obsidian.app" ] && found=true
  else
    command -v obsidian >/dev/null 2>&1 && found=true
  fi

  if [ "$found" = "true" ]; then
    ok "Obsidian found"
  else
    warn "Obsidian not detected. Install it from https://obsidian.md to view your vault."
  fi
}

# ─── Step 6: CLI Tools ───────────────────────────────────────────────────────

install_cli_tools() {
  info "Installing CLI tools..."

  if ! command -v obsidian-cli >/dev/null 2>&1; then
    npm install -g obsidian-cli 2>/dev/null || warn "Failed to install obsidian-cli (non-fatal)"
  fi

  if ! command -v defuddle >/dev/null 2>&1; then
    npm install -g defuddle-cli 2>/dev/null || warn "Failed to install defuddle-cli (non-fatal)"
  fi

  ok "CLI tools ready"
}

# ─── Step 7: Obsidian Skills (kepano) ────────────────────────────────────────

install_obsidian_skills() {
  info "Installing Obsidian skills..."

  local tmp_dir
  tmp_dir=$(mktemp -d)

  git clone --depth 1 --quiet https://github.com/kepano/obsidian-skills.git "$tmp_dir/obsidian-skills" 2>/dev/null \
    || { warn "Failed to clone obsidian-skills (non-fatal, skipping)"; rm -rf "$tmp_dir"; return 0; }

  local skill_names=("obsidian-markdown" "obsidian-bases" "json-canvas" "obsidian-cli" "defuddle")

  for harness in "${HARNESSES[@]}"; do
    local skills_dir
    skills_dir="$(get_skills_dir "$harness")"
    mkdir -p "$skills_dir"

    for skill in "${skill_names[@]}"; do
      local src="$tmp_dir/obsidian-skills/$skill"
      if [ -d "$src" ]; then
        cp -r "$src" "$skills_dir/"
      fi
    done
  done

  rm -rf "$tmp_dir"
  ok "Obsidian skills installed"
}

# ─── Step 8: Sediment-Writer Skill ───────────────────────────────────────────

install_sediment_skill() {
  info "Installing sediment-writer skill..."

  for harness in "${HARNESSES[@]}"; do
    local skills_dir
    skills_dir="$(get_skills_dir "$harness")"
    mkdir -p "$skills_dir"

    cp -r "$SCRIPT_DIR/skills/sediment-writer" "$skills_dir/"

    # Replace vault path placeholder
    find "$skills_dir/sediment-writer" -name "*.md" -exec \
      sed -i.bak "s|VAULT_PATH_PLACEHOLDER|${VAULT_PATH}|g" {} \;
    find "$skills_dir/sediment-writer" -name "*.bak" -delete
  done

  ok "Sediment-writer skill installed"
}

# ─── Step 9: Claude Code Hooks ───────────────────────────────────────────────

install_claude_code_hooks() {
  [[ " ${HARNESSES[*]} " == *" claude-code "* ]] || return 0

  info "Installing Claude Code hooks..."

  # Copy scripts
  mkdir -p "$SEDIMENT_DIR/scripts"
  cp "$SCRIPT_DIR/scripts/sediment-capture.sh" "$SEDIMENT_DIR/scripts/"
  cp "$SCRIPT_DIR/scripts/sediment-context.sh" "$SEDIMENT_DIR/scripts/"
  cp "$SCRIPT_DIR/scripts/sediment-decay.sh"   "$SEDIMENT_DIR/scripts/"
  chmod +x "$SEDIMENT_DIR/scripts/"*.sh

  # Determine settings file
  local settings_file
  if [ "$INSTALL_SCOPE" = "global" ]; then
    settings_file="$HOME/.claude/settings.json"
    mkdir -p "$HOME/.claude"
  else
    settings_file=".claude/settings.json"
    mkdir -p ".claude"
  fi

  local capture_cmd="$SEDIMENT_DIR/scripts/sediment-capture.sh"
  local context_cmd="$SEDIMENT_DIR/scripts/sediment-decay.sh && $SEDIMENT_DIR/scripts/sediment-context.sh \"\$PWD\""

  # Build our hooks object
  local sediment_hooks
  sediment_hooks=$(jq -n \
    --arg capture "$capture_cmd" \
    --arg context "$context_cmd" \
    '{
      hooks: {
        Stop: [{
          hooks: [{
            type: "command",
            command: $capture,
            timeout: 120
          }]
        }],
        SessionStart: [{
          hooks: [{
            type: "command",
            command: $context
          }]
        }]
      }
    }')

  if [ -f "$settings_file" ]; then
    # Merge into existing settings
    local merged
    merged=$(jq --argjson new "$sediment_hooks" '
      .hooks //= {} |
      .hooks.Stop = (.hooks.Stop // []) + $new.hooks.Stop |
      .hooks.SessionStart = (.hooks.SessionStart // []) + $new.hooks.SessionStart
    ' "$settings_file")
    echo "$merged" > "$settings_file"
  else
    echo "$sediment_hooks" > "$settings_file"
  fi

  ok "Claude Code hooks installed"
}

# ─── Step 10: Pi Extension ───────────────────────────────────────────────────

install_pi_extension() {
  [[ " ${HARNESSES[*]} " == *" pi "* ]] || return 0

  info "Installing Pi extension..."

  local ext_dir
  if [ "$INSTALL_SCOPE" = "global" ]; then
    ext_dir="$HOME/.pi/agent/extensions/sediment"
  else
    ext_dir=".pi/extensions/sediment"
  fi

  mkdir -p "$ext_dir"
  cp "$SCRIPT_DIR/extensions/sediment/index.ts" "$ext_dir/"

  # Also copy scripts for Pi (shared with Claude Code)
  mkdir -p "$SEDIMENT_DIR/scripts"
  cp "$SCRIPT_DIR/scripts/sediment-context.sh" "$SEDIMENT_DIR/scripts/"
  cp "$SCRIPT_DIR/scripts/sediment-decay.sh"   "$SEDIMENT_DIR/scripts/"
  chmod +x "$SEDIMENT_DIR/scripts/"*.sh

  ok "Pi extension installed"
}

# ─── Step 11: Vault Structure ────────────────────────────────────────────────

create_vault_structure() {
  info "Setting up vault structure..."

  mkdir -p "$VAULT_PATH"

  # Copy vault-seed contents, skip existing files
  local src="$SCRIPT_DIR/vault-seed"
  for item in "$src"/*; do
    local name
    name=$(basename "$item")
    local dest="$VAULT_PATH/$name"

    if [ -d "$item" ]; then
      mkdir -p "$dest"
      # Copy files that don't exist yet
      for file in "$item"/*; do
        [ -f "$file" ] || continue
        local fname
        fname=$(basename "$file")
        [ -f "$dest/$fname" ] || cp "$file" "$dest/$fname"
      done
    fi
  done

  ok "Vault structure created at $VAULT_PATH"
}

# ─── Step 12: Config ─────────────────────────────────────────────────────────

copy_uninstaller() {
  info "Copying uninstaller..."
  cp "$SCRIPT_DIR/uninstall.sh" "$SEDIMENT_DIR/uninstall.sh"
  chmod +x "$SEDIMENT_DIR/uninstall.sh"
  ok "Uninstaller available at $SEDIMENT_DIR/uninstall.sh"
}

write_config() {
  info "Writing config..."

  mkdir -p "$SEDIMENT_DIR/sessions"

  local harness_json
  harness_json=$(printf '%s\n' "${HARNESSES[@]}" | jq -R . | jq -s .)

  jq -n \
    --arg vault "$VAULT_PATH" \
    --arg scope "$INSTALL_SCOPE" \
    --argjson harnesses "$harness_json" \
    --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg ver "$VERSION" \
    '{
      vault_path: $vault,
      install_scope: $scope,
      harnesses: $harnesses,
      installed_at: $ts,
      version: $ver
    }' > "$SEDIMENT_DIR/config.json"

  ok "Config written to $SEDIMENT_DIR/config.json"
}

# ─── Step 13: Summary ────────────────────────────────────────────────────────

print_summary() {
  echo ""
  echo -e "${BOLD}════════════════════════════════════════${NC}"
  echo -e "${GREEN}${BOLD}  Sediment installed successfully!${NC}"
  echo -e "${BOLD}════════════════════════════════════════${NC}"
  echo ""
  echo "  Vault:     $VAULT_PATH"
  echo "  Scope:     $INSTALL_SCOPE"
  echo "  Harnesses: ${HARNESSES[*]}"
  echo "  Config:    $SEDIMENT_DIR/config.json"
  echo ""
  echo -e "${BOLD}  What happens next:${NC}"
  echo ""

  if [[ " ${HARNESSES[*]} " == *" claude-code "* ]]; then
    echo "  ${BLUE}Claude Code:${NC} At the end of each session, the agent"
    echo "  will automatically distill knowledge into your vault."
    echo ""
  fi

  if [[ " ${HARNESSES[*]} " == *" pi "* ]]; then
    echo "  ${BLUE}Pi:${NC} At the start of each session, the agent will"
    echo "  distill the previous session into your vault."
    echo ""
  fi

  echo "  Open your vault in Obsidian to browse captured notes."
  echo "  Notes land in 00-Inbox/ — promote them to 01-03 after review."
  echo ""
  echo "  To uninstall: ~/.sediment/uninstall.sh"
  echo ""
}

# ─── Helpers: Path Resolution ─────────────────────────────────────────────────

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

# ─── Main ─────────────────────────────────────────────────────────────────────

main() {
  print_banner
  check_prerequisites
  detect_harnesses
  choose_install_scope
  detect_and_choose_vault
  verify_obsidian
  install_cli_tools
  install_obsidian_skills
  install_sediment_skill
  install_claude_code_hooks
  install_pi_extension
  create_vault_structure
  copy_uninstaller
  write_config
  print_summary
}

main "$@"
