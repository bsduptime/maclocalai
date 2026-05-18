#!/usr/bin/env bash
# install-mac.sh — install the voice-listener daemon on this Mac so a remote
# Claude (e.g. running on the Jetson) can ship WAV bytes here for playback.

set -euo pipefail

if [[ "$(uname)" != "Darwin" ]]; then
  echo "macOS only" >&2; exit 1
fi

THIS_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOKS_DIR="$HOME/.claude/hooks"
LISTENER_DEST="$HOOKS_DIR/voice-listener.py"
PLIST_DEST="$HOME/Library/LaunchAgents/com.davidklippel.voice-listener.plist"
LABEL="com.davidklippel.voice-listener"

mkdir -p "$HOOKS_DIR"

echo "==> Installing listener to $LISTENER_DEST"
cp "$THIS_DIR/mac-listener.py" "$LISTENER_DEST"
chmod +x "$LISTENER_DEST"

echo "==> Installing LaunchAgent to $PLIST_DEST"
sed "s|__LISTENER_PATH__|$LISTENER_DEST|" "$THIS_DIR/com.davidklippel.voice-listener.plist" > "$PLIST_DEST"

echo "==> (Re)loading LaunchAgent"
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST_DEST"

echo "==> Verifying"
sleep 1
if curl -sf -m 2 http://localhost:18082/health >/dev/null; then
  echo "  listener up on :18082 ✓"
  TS_IP=$(/Applications/Tailscale.app/Contents/MacOS/Tailscale ip -4 2>/dev/null | head -1)
  if [ -n "$TS_IP" ]; then
    echo ""
    echo "  Jetson should POST WAV bytes to:  http://${TS_IP}:18082/play"
  fi
  echo ""
  echo "  Logs: /tmp/voice-listener.log"
else
  echo "  listener not responding on :18082 — check /tmp/voice-listener.log" >&2
  exit 1
fi
