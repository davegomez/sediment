#!/bin/bash
# Sediment Installer
# Sets up a passive second brain across Claude Code and Pi.
# Usage: /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/davegomez/sediment/main/install.sh)"
# See docs/plans/2026-03-04-sediment-design.md for architecture.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SEDIMENT_DIR="$HOME/.sediment"
VERSION="1.0.0"

# Terminal colors — used by info/ok/warn/fail helpers below
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# Populated by interactive prompts (fresh install) or config loading (update).
# Every install step reads from these rather than re-detecting, so the two
# modes share identical install logic after configuration is resolved.
INSTALL_SCOPE=""
VAULT_PATH=""
HARNESSES=()
INSTALL_MODE="fresh"
PREVIOUS_VERSION=""

# ─── Self-Bootstrap ───────────────────────────────────────────────────────────

maybe_bootstrap() {
  # When run via curl, this script lands in a shell with no repo checkout.
  # We detect that by checking for vault-seed/ — a directory that only
  # exists inside the repo. If missing, we clone the repo to a temp dir
  # and re-exec so all install steps can find their source files.
  [ -d "$SCRIPT_DIR/vault-seed" ] && return 0

  info "Downloading Sediment v${VERSION}..."

  local tmp_dir
  tmp_dir=$(mktemp -d)
  trap 'rm -rf "$tmp_dir"' EXIT

  git clone --depth 1 --quiet https://github.com/davegomez/sediment.git "$tmp_dir/sediment" \
    || fail "Failed to download Sediment. Check your network connection."

  # exec replaces this process — the cloned install.sh takes over entirely
  exec "$tmp_dir/sediment/install.sh"
}

# ─── Mode Detection ───────────────────────────────────────────────────────────

detect_install_mode() {
  # If a config exists, the user has already run the installer before.
  # We load their saved preferences so they aren't prompted again —
  # the update path re-copies all files without any interactive steps.
  local config="$SEDIMENT_DIR/config.json"

  if [ -f "$config" ]; then
    INSTALL_MODE="update"
    PREVIOUS_VERSION=$(jq -r '.version // "unknown"' "$config")
    VAULT_PATH=$(jq -r '.vault_path' "$config")
    INSTALL_SCOPE=$(jq -r '.install_scope' "$config")

    while IFS= read -r h; do
      HARNESSES+=("$h")
    done < <(jq -r '.harnesses[]' "$config")

    # Guard against hand-edited or truncated config files — every field
    # is required for the install steps to work correctly
    if [ -z "$VAULT_PATH" ] || [ "$VAULT_PATH" = "null" ]; then
      fail "Corrupt config: missing vault_path. Run uninstall first, then reinstall."
    fi
    if [ -z "$INSTALL_SCOPE" ] || [ "$INSTALL_SCOPE" = "null" ]; then
      fail "Corrupt config: missing install_scope. Run uninstall first, then reinstall."
    fi
    if [ ${#HARNESSES[@]} -eq 0 ]; then
      fail "Corrupt config: no harnesses found. Run uninstall first, then reinstall."
    fi
  fi
}

# ─── Helpers ──────────────────────────────────────────────────────────────────

print_banner() {
  echo ""
  echo -e "${BOLD}╔═══════════════════════════════════════╗${NC}"
  echo -e "${BOLD}║          ${BLUE}Sediment${NC} ${BOLD}v${VERSION}              ║${NC}"
  echo -e "${BOLD}║   Passive Second Brain for Coding     ║${NC}"
  echo -e "${BOLD}╚═══════════════════════════════════════╝${NC}"
  echo ""

  # On update, show the loaded config so the user knows what's about
  # to be refreshed without needing to inspect config.json themselves
  if [ "$INSTALL_MODE" = "update" ]; then
    info "Existing installation detected (v${PREVIOUS_VERSION})"
    echo ""
    echo "  Vault:     $VAULT_PATH"
    echo "  Scope:     $INSTALL_SCOPE"
    echo "  Harnesses: ${HARNESSES[*]}"
    echo ""

    if [ "$PREVIOUS_VERSION" = "$VERSION" ]; then
      info "Reinstalling v${VERSION}..."
    else
      info "Updating v${PREVIOUS_VERSION} → v${VERSION}..."
    fi
  fi
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
  # Each harness has its own integration surface (hooks vs extensions),
  # so we need to know which ones are present before installing anything.
  # We check for both the config directory and the CLI command because
  # either can exist independently depending on how the user installed.
  info "Detecting coding harnesses..."

  local has_claude=false
  local has_pi=false

  if [ -d "$HOME/.claude" ] || command -v claude >/dev/null 2>&1; then
    has_claude=true
  fi

  if [ -d "$HOME/.pi" ] || command -v pi >/dev/null 2>&1; then
    has_pi=true
  fi

  # At least one harness is required — Sediment has nothing to hook into otherwise
  if [ "$has_claude" = "false" ] && [ "$has_pi" = "false" ]; then
    fail "No supported harness detected. Install Claude Code or Pi first."
  fi

  # When both are available, let the user choose in case they only want
  # one — e.g., they use Pi for work and Claude Code for personal projects
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
  # Global installs to ~/.claude/ and ~/.pi/ so every project gets
  # Sediment automatically. Project-scoped installs to .claude/ and
  # .pi/ in the current directory — useful for team repos that want
  # Sediment checked in, but most users want global.
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
  # We read Obsidian's own config to find existing vaults — this lets us
  # offer them as choices so the user can reuse a vault they already browse
  # in Obsidian, rather than creating a disconnected directory.
  info "Looking for Obsidian vaults..."

  local obsidian_json=""
  local vaults=()

  # Obsidian stores its global state in different locations per platform
  if [ "$(uname)" = "Darwin" ]; then
    obsidian_json="$HOME/Library/Application Support/obsidian/obsidian.json"
  else
    obsidian_json="$HOME/.config/obsidian/obsidian.json"
  fi

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
  # Obsidian is recommended but not required — the vault is plain Markdown
  # and works without it. We warn rather than fail so headless/CI setups
  # can still install Sediment.
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
  # defuddle-cli extracts clean Markdown from web pages — agents use it
  # to save web references into the vault without HTML clutter
  info "Installing CLI tools..."

  if ! command -v defuddle >/dev/null 2>&1; then
    npm install -g defuddle-cli 2>/dev/null || warn "Failed to install defuddle-cli (non-fatal)"
  fi

  ok "CLI tools ready"
}

# ─── Step 7: Obsidian Skills (kepano) ────────────────────────────────────────

install_obsidian_skills() {
  # These third-party skills teach agents how to write valid Obsidian
  # Markdown, Bases views, and Canvas files. Without them, the agent
  # would guess at syntax and produce notes that Obsidian can't render.
  info "Installing Obsidian skills..."

  local tmp_dir
  tmp_dir=$(mktemp -d)

  git clone --depth 1 --quiet https://github.com/kepano/obsidian-skills.git "$tmp_dir/obsidian-skills" 2>/dev/null \
    || { rm -rf "$tmp_dir"; fail "Failed to clone obsidian-skills. Check your network connection and try again."; }

  # Skills live under skills/ in the repo, not at the root
  local skill_names=("obsidian-markdown" "obsidian-bases" "json-canvas" "obsidian-cli" "defuddle")

  for harness in "${HARNESSES[@]}"; do
    local skills_dir
    skills_dir="$(get_skills_dir "$harness")"
    mkdir -p "$skills_dir"

    for skill in "${skill_names[@]}"; do
      local src="$tmp_dir/obsidian-skills/skills/$skill"
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
  # The sediment-writer skill teaches agents vault conventions, note
  # templates, tagging taxonomy, and deduplication rules. It contains
  # a placeholder for the vault path that we bake in at install time
  # so the agent always knows where to write notes.
  info "Installing sediment-writer skill..."

  for harness in "${HARNESSES[@]}"; do
    local skills_dir
    skills_dir="$(get_skills_dir "$harness")"
    mkdir -p "$skills_dir"

    cp -r "$SCRIPT_DIR/skills/sediment-writer" "$skills_dir/"

    # Bake the user's vault path into the skill so agents don't need
    # to read config.json at runtime — the path is right in the SKILL.md
    find "$skills_dir/sediment-writer" -name "*.md" -exec \
      sed -i.bak "s|VAULT_PATH_PLACEHOLDER|${VAULT_PATH}|g" {} \;
    find "$skills_dir/sediment-writer" -name "*.bak" -delete
  done

  ok "Sediment-writer skill installed"
}

# ─── Step 9: Claude Code Hooks ───────────────────────────────────────────────

install_claude_code_hooks() {
  # Claude Code uses JSON-configured hooks that run shell commands at
  # lifecycle events. We install three:
  #   Stop        → blocks exit, triggers session distillation
  #   SessionStart → injects relevant vault notes into context
  #   PreCompact   → marks that compaction happened so Stop hook can
  #                  tell the agent to pay attention to the summary
  [[ " ${HARNESSES[*]} " == *" claude-code "* ]] || return 0

  info "Installing Claude Code hooks..."

  # Scripts live in ~/.sediment/scripts/ rather than the repo so they
  # survive after the temp clone is cleaned up (curl installs)
  mkdir -p "$SEDIMENT_DIR/scripts"
  cp "$SCRIPT_DIR/scripts/sediment-capture.sh"    "$SEDIMENT_DIR/scripts/"
  cp "$SCRIPT_DIR/scripts/sediment-context.sh"    "$SEDIMENT_DIR/scripts/"
  cp "$SCRIPT_DIR/scripts/sediment-decay.sh"      "$SEDIMENT_DIR/scripts/"
  cp "$SCRIPT_DIR/scripts/sediment-precompact.sh" "$SEDIMENT_DIR/scripts/"
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
  local precompact_cmd="$SEDIMENT_DIR/scripts/sediment-precompact.sh"

  # Build our hooks object
  local sediment_hooks
  sediment_hooks=$(jq -n \
    --arg capture "$capture_cmd" \
    --arg context "$context_cmd" \
    --arg precompact "$precompact_cmd" \
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
        }],
        PreCompact: [{
          hooks: [{
            type: "command",
            command: $precompact
          }]
        }]
      }
    }')

  if [ -f "$settings_file" ]; then
    # Strip any existing sediment hooks before adding fresh ones —
    # without this, every update/reinstall would duplicate the hooks.
    # We identify sediment hooks by matching "sediment" in the command.
    local cleaned
    cleaned=$(jq '
      if .hooks then
        .hooks |= with_entries(
          .value |= map(
            select(
              .hooks | all(
                .command | test("sediment") | not
              )
            )
          )
        )
      else . end
    ' "$settings_file")

    local merged
    merged=$(echo "$cleaned" | jq --argjson new "$sediment_hooks" '
      .hooks //= {} |
      .hooks.Stop = (.hooks.Stop // []) + $new.hooks.Stop |
      .hooks.SessionStart = (.hooks.SessionStart // []) + $new.hooks.SessionStart |
      .hooks.PreCompact = (.hooks.PreCompact // []) + $new.hooks.PreCompact
    ')
    echo "$merged" > "$settings_file"
  else
    echo "$sediment_hooks" > "$settings_file"
  fi

  ok "Claude Code hooks installed"
}

# ─── Step 10: Pi Extension ───────────────────────────────────────────────────

install_pi_extension() {
  # Pi uses TypeScript extensions rather than JSON hooks. The extension
  # handles deferred distillation (session end → next session start)
  # and inline distillation (compaction → immediate capture).
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

  # Pi's extension shells out to the same context/decay scripts that
  # Claude Code uses — shared logic, different trigger mechanisms
  mkdir -p "$SEDIMENT_DIR/scripts"
  cp "$SCRIPT_DIR/scripts/sediment-context.sh" "$SEDIMENT_DIR/scripts/"
  cp "$SCRIPT_DIR/scripts/sediment-decay.sh"   "$SEDIMENT_DIR/scripts/"
  chmod +x "$SEDIMENT_DIR/scripts/"*.sh

  ok "Pi extension installed"
}

# ─── Step 11: Vault Structure ────────────────────────────────────────────────

create_vault_structure() {
  # Seed the vault with the folder hierarchy, templates, and MOC base
  # views. We skip files that already exist so user customizations
  # (renamed templates, edited MOCs) aren't overwritten on update.
  info "Setting up vault structure..."

  mkdir -p "$VAULT_PATH"

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
    echo -e "  ${BLUE}Claude Code:${NC} At the end of each session, the agent"
    echo "    will automatically distill knowledge into your vault."
    echo ""
  fi

  if [[ " ${HARNESSES[*]} " == *" pi "* ]]; then
    echo -e "  ${BLUE}Pi:${NC} At the start of each session, the agent will"
    echo "    distill the previous session into your vault."
    echo ""
  fi

  echo "  Open your vault in Obsidian to browse captured notes."
  echo "  Notes land in 00-Inbox/ — promote them to 01-03 after review."
  echo ""
  echo "  To uninstall: ~/.sediment/uninstall.sh"
  echo ""
}

print_update_summary() {
  echo ""
  echo -e "${BOLD}════════════════════════════════════════${NC}"
  echo -e "${GREEN}${BOLD}  Sediment updated successfully!${NC}"
  echo -e "${BOLD}════════════════════════════════════════${NC}"
  echo ""

  if [ "$PREVIOUS_VERSION" = "$VERSION" ]; then
    echo "  Version:   v${VERSION} (reinstalled)"
  else
    echo "  Version:   v${PREVIOUS_VERSION} → v${VERSION}"
  fi

  echo "  Vault:     $VAULT_PATH"
  echo "  Scope:     $INSTALL_SCOPE"
  echo "  Harnesses: ${HARNESSES[*]}"
  echo "  Config:    $SEDIMENT_DIR/config.json"
  echo ""
  echo "  All skills, hooks, scripts, and extensions have been"
  echo "  refreshed from the latest source."
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
  # Bootstrap first — if we're running via curl without the repo, this
  # clones and re-execs before anything else happens
  maybe_bootstrap

  # Mode detection must precede the banner so the banner can display
  # the loaded config and version transition on updates
  detect_install_mode
  print_banner
  check_prerequisites

  # Fresh installs need interactive configuration; updates already
  # loaded everything from config.json in detect_install_mode
  if [ "$INSTALL_MODE" = "fresh" ]; then
    detect_harnesses
    choose_install_scope
    detect_and_choose_vault
    verify_obsidian
  fi

  # From here on, both modes run identical install steps — the only
  # difference is where the config values came from
  install_cli_tools
  install_obsidian_skills
  install_sediment_skill
  install_claude_code_hooks
  install_pi_extension
  create_vault_structure
  copy_uninstaller
  write_config

  if [ "$INSTALL_MODE" = "update" ]; then
    print_update_summary
  else
    print_summary
  fi
}

main "$@"
