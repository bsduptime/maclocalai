#!/usr/bin/env bash
# Install voice-replies: macOS `say` Tier 1 or Chatterbox Tier 2.
#
# Copies voice-reply.py to ~/.claude/hooks/ and registers it as a Stop
# hook in ~/.claude/settings.json with backend-appropriate env vars.

set -euo pipefail

step() { printf "\n\033[1;34m==>\033[0m %s\n" "$*"; }
warn() { printf "\n\033[1;33m!!\033[0m %s\n" "$*" >&2; }

if [[ "$(uname)" != "Darwin" ]]; then
  warn "macOS only (uses the built-in \`say\` command and \`afplay\`)."
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  warn "python3 not found. Install Xcode command-line tools: xcode-select --install"
  exit 1
fi

THIS_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="${HOME}/.claude"
HOOKS_DIR="${CLAUDE_DIR}/hooks"
SETTINGS="${CLAUDE_DIR}/settings.json"
SCRIPT_DEST="${HOOKS_DIR}/voice-reply.py"

mkdir -p "${HOOKS_DIR}"

step "Copying voice-reply.py to ${SCRIPT_DEST}"
cp "${THIS_DIR}/voice-reply.py" "${SCRIPT_DEST}"
chmod +x "${SCRIPT_DEST}"

# Always install the voice-say wrapper too — it's the recommended pattern
# for deliberate, in-flight narration (vs. the auto-on-every-turn Stop hook).
# Costs nothing if unused.
VOICE_SAY_DEST="${HOOKS_DIR}/voice-say"
step "Copying voice-say wrapper to ${VOICE_SAY_DEST}"
cp "${THIS_DIR}/voice-say" "${VOICE_SAY_DEST}"
chmod +x "${VOICE_SAY_DEST}"

# ----------------------------- Backend pick ---------------------------------

step "Pick a backend."
cat <<EOF
  1. say        (Tier 1 — macOS built-in, zero install, mediocre voice)
  2. chatterbox (Tier 2 — natural voice via a remote Chatterbox TTS server,
                  e.g. running on a Jetson over Tailscale or LAN)

EOF
read -r -p "Pick (1-2, default 1): " backend_choice
case "${backend_choice:-1}" in
  1|"") BACKEND="say" ;;
  2)    BACKEND="chatterbox" ;;
  *)    BACKEND="say" ;;
esac

# ----------------------------- Per-backend config ---------------------------

ENV_LINE=""

if [ "$BACKEND" = "say" ]; then
  step "Pick a voice for \`say\`."
  cat <<EOF
  1. Samantha   (US English, default)
  2. Daniel     (UK English — many find this more pleasant than Samantha)
  3. Karen      (Australian English)
  4. Moira      (Irish English)
  5. Tessa      (South African English)
  6. Other      (type any voice name installed on your Mac)

  List installed voices: say -v ?
  For Siri-quality voices: System Settings → Accessibility → Spoken
  Content → System Voice → click a voice → Download.

EOF
  read -r -p "Pick (1-6, default 1): " choice
  case "${choice:-1}" in
    1|"") VOICE="Samantha" ;;
    2) VOICE="Daniel" ;;
    3) VOICE="Karen" ;;
    4) VOICE="Moira" ;;
    5) VOICE="Tessa" ;;
    6) read -r -p "Voice name: " VOICE ;;
    *) VOICE="$choice" ;;
  esac

  step "Testing voice: ${VOICE}"
  if ! say -v "${VOICE}" "Hello from voice replies." 2>/dev/null; then
    warn "That voice isn't installed. Falling back to Samantha."
    VOICE="Samantha"
    say -v "${VOICE}" "Falling back to Samantha."
  fi

  ENV_LINE="VOICE_REPLY_BACKEND=say VOICE_REPLY_VOICE=__VOICE__"
  ENV_VOICE="${VOICE}"

else
  # chatterbox (videngine TTS)
  step "Configure videngine TTS (Chatterbox) server."
  read -r -p "Server URL (default http://192.168.1.200:18080): " CB_URL
  CB_URL="${CB_URL:-http://192.168.1.200:18080}"

  step "Probing ${CB_URL}/health"
  if curl -sf -m 5 "${CB_URL}/health" >/dev/null 2>&1; then
    echo "  reachable ✓"
    VOICES_JSON=$(curl -sf -m 5 "${CB_URL}/voices" 2>/dev/null || echo "")
  else
    warn "  not reachable right now. Saving config anyway — the hook will"
    warn "  fall back to \`say\` automatically until the server is up."
    VOICES_JSON=""
  fi

  if [ -n "$VOICES_JSON" ]; then
    step "Available voices (⭐ = vetted)"
    echo "  Preview any voice in your browser: ${CB_URL}/previews/"
    echo ""
    python3 - "$VOICES_JSON" <<'PYEOF' || true
import json, sys
data = json.loads(sys.argv[1])
voices = data.get("voices", [])
# Show vetted first, then the rest grouped by source
vetted = [v for v in voices if v.get("vetted")]
other = [v for v in voices if not v.get("vetted")]
print("  Vetted:")
for v in vetted:
    print(f"    ⭐ {v['name']}")
print(f"  Other: {len(other)} more (see {data.get('count', len(voices))} total at /voices)")
PYEOF
    echo ""
    read -r -p "Voice name (default 'devnen-elena' — vetted female): " CB_VOICE
  else
    echo ""
    echo "  Common picks for a Claude voice (non-David, vetted by upstream):"
    echo "    - devnen-elena    (female, dramatic — assistant default)"
    echo "    - devnen-austin   (male, calm)"
    echo ""
    read -r -p "Voice name (default 'devnen-elena'): " CB_VOICE
  fi
  CB_VOICE="${CB_VOICE:-devnen-elena}"
  read -r -p "Fallback URL when primary is unreachable (default http://100.99.130.79:18080 — Jetson Tailscale IP, blank to skip): " CB_URL_FALLBACK
  if [ -z "$CB_URL_FALLBACK" ]; then
    CB_URL_FALLBACK="http://100.99.130.79:18080"
  fi
  read -r -p "Bearer token (optional, press enter to skip): " CB_TOKEN

  ENV_LINE="VOICE_REPLY_BACKEND=chatterbox CHATTERBOX_URL=__URL__ CHATTERBOX_VOICE=__VOICE__"
  [ -n "$CB_URL_FALLBACK" ] && ENV_LINE="$ENV_LINE CHATTERBOX_URL_FALLBACK=__URL_FALLBACK__"
  [ -n "$CB_TOKEN" ] && ENV_LINE="$ENV_LINE CHATTERBOX_TOKEN=__TOKEN__"
  # Also configure the say fallback voice (used if chatterbox is unreachable)
  ENV_LINE="$ENV_LINE VOICE_REPLY_VOICE=Samantha"
fi

# ----------------------------- Register hook --------------------------------

step "Registering Stop hook in ${SETTINGS}"
if [ -f "${SETTINGS}" ]; then
  cp "${SETTINGS}" "${SETTINGS}.bak.$(date +%s)"
  echo "(backup saved alongside)"
else
  echo "{}" > "${SETTINGS}"
fi

PYTHON_BIN="$(command -v python3)"

# Pass the per-backend values into the patcher via env so we don't have to
# build a single long string with shell-tricky substitution.
export _VR_BACKEND="$BACKEND"
export _VR_SCRIPT="$SCRIPT_DEST"
export _VR_PYTHON="$PYTHON_BIN"
export _VR_SAY_VOICE="${ENV_VOICE:-Samantha}"
export _VR_CB_URL="${CB_URL:-}"
export _VR_CB_URL_FALLBACK="${CB_URL_FALLBACK:-}"
export _VR_CB_VOICE="${CB_VOICE:-}"
export _VR_CB_TOKEN="${CB_TOKEN:-}"

python3 - "${SETTINGS}" <<'PYEOF'
import json
import os
import shlex
import sys

settings_path = sys.argv[1]
backend = os.environ["_VR_BACKEND"]
script_path = os.environ["_VR_SCRIPT"]
python_bin = os.environ["_VR_PYTHON"]

parts: list[str] = []
parts.append(f"VOICE_REPLY_BACKEND={shlex.quote(backend)}")
parts.append(f"VOICE_REPLY_VOICE={shlex.quote(os.environ['_VR_SAY_VOICE'])}")
if backend == "chatterbox":
    parts.append(f"CHATTERBOX_URL={shlex.quote(os.environ['_VR_CB_URL'])}")
    parts.append(f"CHATTERBOX_VOICE={shlex.quote(os.environ['_VR_CB_VOICE'])}")
    if os.environ.get("_VR_CB_URL_FALLBACK"):
        parts.append(f"CHATTERBOX_URL_FALLBACK={shlex.quote(os.environ['_VR_CB_URL_FALLBACK'])}")
    if os.environ.get("_VR_CB_TOKEN"):
        parts.append(f"CHATTERBOX_TOKEN={shlex.quote(os.environ['_VR_CB_TOKEN'])}")

cmd = " ".join(parts) + f" {shlex.quote(python_bin)} {shlex.quote(script_path)}"

with open(settings_path) as f:
    cfg = json.load(f)

hooks_root = cfg.setdefault("hooks", {})
stop_hooks = hooks_root.setdefault("Stop", [])

updated = False
for entry in stop_hooks:
    if not isinstance(entry, dict):
        continue
    for h in entry.get("hooks", []):
        if isinstance(h, dict) and "voice-reply.py" in h.get("command", ""):
            h["command"] = cmd
            updated = True
            break
    if updated:
        break

if not updated:
    stop_hooks.append(
        {"matcher": "", "hooks": [{"type": "command", "command": cmd}]}
    )

with open(settings_path, "w") as f:
    json.dump(cfg, f, indent=2)
    f.write("\n")

print(f"  Backend: {backend}")
print(f"  Hook command: {cmd}")
PYEOF

cat <<EOF

$(printf "\033[1;32mDone.\033[0m")

Files:
  Script:    ${SCRIPT_DEST}
  Settings:  ${SETTINGS}

Backend: ${BACKEND}

EOF

if [ "$BACKEND" = "chatterbox" ]; then
  cat <<EOF
Behavior:
  The hook POSTs each Claude response to ${CB_URL:-the server} and plays
  the returned WAV via afplay. If the server is unreachable for any
  reason, falls back to the macOS \`say\` voice (Samantha) automatically,
  so you always hear something.

EOF
fi

cat <<EOF
To take effect:
  Start a new Claude Code session (existing sessions don't pick up
  newly-registered hooks).

To change config later:
  Re-run this install.sh, or edit ~/.claude/settings.json directly.

To uninstall:
  Edit ~/.claude/settings.json and remove the Stop hook entry that
  references voice-reply.py.

EOF
