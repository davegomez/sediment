# Install/Update Mode Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make `install.sh` auto-detect fresh install vs update, self-bootstrap via curl, and remove `bootstrap.sh`.

**Architecture:** The script checks for `$SCRIPT_DIR/vault-seed` to decide if it's running from the repo or via curl. If via curl, it clones the repo to a temp dir and re-execs. Then it checks `~/.sediment/config.json` — if present, it loads saved config and runs in update mode (no prompts); if absent, it runs the current interactive flow.

**Tech Stack:** Bash, jq, git

---

### Task 1: Add self-bootstrap logic

**Files:**
- Modify: `install.sh` (top of file, after variables, before helpers)

**Step 1: Add bootstrap function after the State section**

Insert a `maybe_bootstrap()` function that checks whether `$SCRIPT_DIR/vault-seed` exists. If it doesn't, the script was invoked via curl — clone the repo to a temp dir and re-exec. The function goes right after the `HARNESSES=()` line and before the `# ─── Helpers` section.

```bash
# ─── Self-Bootstrap ───────────────────────────────────────────────────────────

maybe_bootstrap() {
  # If vault-seed exists, we're running from the repo — nothing to do
  [ -d "$SCRIPT_DIR/vault-seed" ] && return 0

  info "Downloading Sediment v${VERSION}..."

  local tmp_dir
  tmp_dir=$(mktemp -d)
  trap 'rm -rf "$tmp_dir"' EXIT

  git clone --depth 1 --quiet https://github.com/davegomez/sediment.git "$tmp_dir/sediment" \
    || fail "Failed to download Sediment. Check your network connection."

  exec "$tmp_dir/sediment/install.sh"
}
```

**Step 2: Verify the script still parses**

Run: `bash -n install.sh`
Expected: no output (clean parse)

---

### Task 2: Add update mode detection and config loading

**Files:**
- Modify: `install.sh` (add new state variable and function)

**Step 1: Add `INSTALL_MODE` and `PREVIOUS_VERSION` state variables**

After the `HARNESSES=()` line, add:

```bash
INSTALL_MODE="fresh"
PREVIOUS_VERSION=""
```

**Step 2: Add `detect_install_mode()` function**

Place this after the `maybe_bootstrap()` function:

```bash
# ─── Mode Detection ───────────────────────────────────────────────────────────

detect_install_mode() {
  local config="$SEDIMENT_DIR/config.json"

  if [ -f "$config" ]; then
    INSTALL_MODE="update"
    PREVIOUS_VERSION=$(jq -r '.version // "unknown"' "$config")
    VAULT_PATH=$(jq -r '.vault_path' "$config")
    INSTALL_SCOPE=$(jq -r '.install_scope' "$config")

    while IFS= read -r h; do
      HARNESSES+=("$h")
    done < <(jq -r '.harnesses[]' "$config")

    # Validate loaded config
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
```

**Step 3: Verify the script still parses**

Run: `bash -n install.sh`
Expected: no output (clean parse)

---

### Task 3: Add update-mode banner and summary

**Files:**
- Modify: `install.sh` (modify `print_banner`, add `print_update_summary`)

**Step 1: Modify `print_banner()` to show update context**

Replace the existing `print_banner()`:

```bash
print_banner() {
  echo ""
  echo -e "${BOLD}╔═══════════════════════════════════════╗${NC}"
  echo -e "${BOLD}║          ${BLUE}Sediment${NC} ${BOLD}v${VERSION}              ║${NC}"
  echo -e "${BOLD}║   Passive Second Brain for Coding     ║${NC}"
  echo -e "${BOLD}╚═══════════════════════════════════════╝${NC}"
  echo ""

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
```

**Step 2: Add `print_update_summary()` after `print_summary()`**

```bash
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
```

**Step 3: Verify the script still parses**

Run: `bash -n install.sh`
Expected: no output (clean parse)

---

### Task 4: Wire up `main()` to branch on install mode

**Files:**
- Modify: `install.sh` (`main()` function)

**Step 1: Replace the `main()` function**

```bash
main() {
  maybe_bootstrap
  print_banner
  check_prerequisites
  detect_install_mode

  if [ "$INSTALL_MODE" = "fresh" ]; then
    detect_harnesses
    choose_install_scope
    detect_and_choose_vault
    verify_obsidian
  fi

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
```

Note: `print_banner` must come before `detect_install_mode` because `detect_install_mode` sets the state that `print_banner` reads. Since `print_banner` now checks `INSTALL_MODE`, and the default is `"fresh"`, it displays the plain banner on first call. But that means on update, the banner won't show the update info because `detect_install_mode` hasn't run yet.

Fix: move `detect_install_mode` before `print_banner`:

```bash
main() {
  maybe_bootstrap
  detect_install_mode
  print_banner
  check_prerequisites

  if [ "$INSTALL_MODE" = "fresh" ]; then
    detect_harnesses
    choose_install_scope
    detect_and_choose_vault
    verify_obsidian
  fi

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
```

**Step 2: Verify the script still parses**

Run: `bash -n install.sh`
Expected: no output (clean parse)

---

### Task 5: Delete `bootstrap.sh`

**Files:**
- Delete: `bootstrap.sh`

**Step 1: Remove the file**

```bash
git rm bootstrap.sh
```

**Step 2: Update the comment at the top of install.sh**

Change line 3 from:
```bash
# Sets up a passive second brain across Claude Code and Pi.
```
to:
```bash
# Sets up a passive second brain across Claude Code and Pi.
# Usage: /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/davegomez/sediment/main/install.sh)"
```

---

### Task 6: End-to-end verification

**Step 1: Verify syntax**

Run: `bash -n install.sh`
Expected: no output

**Step 2: Verify update mode detects existing config**

Run: `jq . ~/.sediment/config.json`
Confirm `vault_path`, `install_scope`, `harnesses`, and `version` are present.

**Step 3: Dry read through the main flow**

Trace through `main()` mentally:
- `maybe_bootstrap` — `vault-seed` exists locally, returns immediately
- `detect_install_mode` — config exists, sets `INSTALL_MODE="update"`, loads config values
- `print_banner` — shows update banner with version transition
- `check_prerequisites` — unchanged
- Skips interactive prompts (harnesses, scope, vault, obsidian check)
- Runs all install steps with loaded config
- `print_update_summary` — shows version transition and summary

**Step 4: Commit**

```bash
git add -A
git commit -m "Add update mode and self-bootstrap to install.sh

The installer now auto-detects whether Sediment is already installed
by checking ~/.sediment/config.json. On update, it loads the saved
vault path, scope, and harnesses — skipping all interactive prompts —
then re-copies skills, hooks, scripts, and extensions from the latest
source. The summary reports the version transition.

The script also self-bootstraps when run via curl: if vault-seed is
missing (not inside the repo), it clones to a temp dir and re-execs.
This replaces the separate bootstrap.sh."
```
