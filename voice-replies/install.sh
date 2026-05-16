#!/usr/bin/env bash
# Stage 1 of voice-replies: macOS `say` MVP.
#
# Installs voice-reply.py to ~/.claude/hooks/ and registers it as a Stop
# hook in ~/.claude/settings.json. After install, Claude speaks responses
# aloud through your default audio output.

set -euo pipefail

step() { printf "\n\033[1;34m==>\033[0m %s\n" "$*"; }
warn() { printf "\n\033[1;33m!!\033[0m %s\n" "$*" >&2; }

if [[ "$(uname)" != "Darwin" ]]; then
  warn "macOS only (uses the built-in \`say\` command)."
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

step "Pick a voice for Claude's spoken replies."
cat <<EOF
  1. Samantha   (US English, default)
  2. Daniel     (UK English — many find this more pleasant than Samantha)
  3. Karen      (Australian English)
  4. Moira      (Irish English)
  5. Tessa      (South African English)
  6. Other      (type any voice name installed on your Mac)

  List all installed voices any time with: say -v ?
  For Siri-quality voices, download in: System Settings → Accessibility
    → Spoken Content → System Voice → click a voice → Download

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
  warn "That voice doesn't seem to be installed. Continuing with default Samantha."
  VOICE="Samantha"
  say -v "${VOICE}" "Falling back to Samantha."
fi

step "Registering Stop hook in ${SETTINGS}"
if [ -f "${SETTINGS}" ]; then
  cp "${SETTINGS}" "${SETTINGS}.bak.$(date +%s)"
  echo "(backup saved alongside)"
else
  echo "{}" > "${SETTINGS}"
fi

PYTHON_BIN="$(command -v python3)"

python3 - "${SETTINGS}" "${VOICE}" "${SCRIPT_DEST}" "${PYTHON_BIN}" <<'PYEOF'
import json
import shlex
import sys

settings_path, voice, script_path, python_bin = sys.argv[1:5]

with open(settings_path) as f:
    cfg = json.load(f)

cmd = (
    f"VOICE_REPLY_VOICE={shlex.quote(voice)} "
    f"{shlex.quote(python_bin)} {shlex.quote(script_path)}"
)

hooks_root = cfg.setdefault("hooks", {})
stop_hooks = hooks_root.setdefault("Stop", [])

# Update existing voice-reply entry if present; otherwise append a new one
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

print(f"  Voice: {voice}")
print(f"  Hook command: {cmd}")
PYEOF

cat <<EOF

$(printf "\033[1;32mDone.\033[0m")

Files:
  Script:    ${SCRIPT_DEST}
  Settings:  ${SETTINGS}

How it works:
  After Claude finishes any response, the Stop hook fires and the
  response is read aloud (markdown stripped, Sources section dropped,
  capped at 2000 characters). Speech is backgrounded so it doesn't
  block your next turn — if you start a new turn, the previous speech
  is killed and the new one starts.

To take effect:
  Start a new Claude Code session (existing sessions don't pick up
  newly-registered hooks). Try a short prompt and listen.

To change voice later:
  Re-run this install.sh, or edit ~/.claude/settings.json and update
  the VOICE_REPLY_VOICE value in the Stop hook command.

To uninstall:
  Edit ~/.claude/settings.json and remove the Stop hook entry that
  references voice-reply.py.

EOF
