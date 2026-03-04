#!/bin/bash
# Sediment Bootstrap Installer
# Usage: /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/davegomez/sediment/main/bootstrap.sh)"

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# Preflight: git is required
if ! command -v git >/dev/null 2>&1; then
  echo -e "${RED}✗${NC} git is required. Install it and re-run."
  exit 1
fi

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

echo -e "${GREEN}→${NC} Downloading Sediment..."
git clone --depth 1 --quiet https://github.com/davegomez/sediment.git "$TMP_DIR/sediment"

exec "$TMP_DIR/sediment/install.sh"
