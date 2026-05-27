#!/usr/bin/env bash
# Install obsidian-sync: Syncthing daemon (+ optional Obsidian app) on macOS.
#
# After this script finishes, follow the "Pair with a peer" section in README.md
# to connect this Mac to another device.

set -euo pipefail

step() { printf "\n\033[1;34m==>\033[0m %s\n" "$*"; }
warn() { printf "\n\033[1;33m!!\033[0m %s\n" "$*" >&2; }
confirm() {
  read -r -p "$1 [y/N] " ans
  [[ "$ans" =~ ^[Yy]$ ]]
}

# ----- preflight -----
if [[ "$(uname)" != "Darwin" ]]; then
  warn "macOS only."; exit 1
fi
if ! command -v brew >/dev/null 2>&1; then
  warn "Homebrew not found. Install it first: https://brew.sh"
  exit 1
fi

# ----- Syncthing -----
step "Installing Syncthing…"
if brew list syncthing >/dev/null 2>&1; then
  echo "Syncthing already installed — skipping."
else
  brew install syncthing
fi

step "Starting Syncthing service (autostart on login)…"
if brew services list | grep -q "^syncthing.*started"; then
  echo "Already running."
else
  brew services start syncthing
fi

# ----- Wait for config to generate -----
CFG="$HOME/Library/Application Support/Syncthing/config.xml"
step "Waiting for Syncthing to initialize config…"
for i in $(seq 1 30); do
  if [ -f "$CFG" ]; then break; fi
  sleep 1
done
if [ ! -f "$CFG" ]; then
  warn "Syncthing config didn't appear at $CFG. Check 'brew services list'."
  exit 1
fi

# ----- Pull device ID via REST -----
API_KEY=$(grep -oE '<apikey>[^<]+' "$CFG" | sed 's/<apikey>//')
DEVICE_ID=""
for i in $(seq 1 15); do
  DEVICE_ID=$(curl -s -H "X-API-Key: $API_KEY" http://localhost:8384/rest/system/status 2>/dev/null \
    | python3 -c 'import json,sys
try:
  print(json.load(sys.stdin).get("myID",""))
except: pass' 2>/dev/null)
  [ -n "$DEVICE_ID" ] && break
  sleep 1
done

# ----- Obsidian (optional) -----
step "Obsidian desktop app"
if [ -d "/Applications/Obsidian.app" ] || brew list --cask obsidian >/dev/null 2>&1; then
  echo "Obsidian already installed — skipping."
else
  if confirm "Install Obsidian via brew (--cask)?"; then
    brew install --cask obsidian
  else
    echo "Skipped. Install later with: brew install --cask obsidian"
  fi
fi

# ----- Summary -----
cat <<EOF

$(printf "\033[1;32mDone.\033[0m")

Syncthing:
  Service:    $(brew services list | awk '$1=="syncthing"{print $2,$3}')
  GUI:        http://localhost:8384
  Config:     ${CFG}
  Device ID:  ${DEVICE_ID:-<not yet available — open the GUI to copy it>}

Next steps:
  1. Send this Mac's device ID to your peer (Jetson, other Mac, etc.).
  2. On the peer, add this Mac as a remote device and share the vault folder.
  3. On this Mac, either accept the folder offer in the GUI, or use the
     REST recipe in README.md to accept it at ~/obsidian-vault.
  4. Open Obsidian → "Open folder as vault" → pick ~/obsidian-vault.

See README.md for the full pairing flow (GUI or REST).

EOF
