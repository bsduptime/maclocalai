#!/usr/bin/env bash
# Install the dictation stack: VoiceInk + Ollama + Qwen 3 models.
# After this script finishes, follow voiceink-setup.md for GUI config.

set -euo pipefail

# ---------- helpers ----------
say() { printf "\n\033[1;34m==>\033[0m %s\n" "$*"; }
warn() { printf "\n\033[1;33m!!\033[0m %s\n" "$*" >&2; }
confirm() {
  read -r -p "$1 [y/N] " ans
  [[ "$ans" =~ ^[Yy]$ ]]
}

# ---------- preflight ----------
if [[ "$(uname)" != "Darwin" ]]; then
  warn "This script is for macOS only."; exit 1
fi
if [[ "$(uname -m)" != "arm64" ]]; then
  warn "This script targets Apple Silicon (arm64). You're on $(uname -m)."
  confirm "Continue anyway?" || exit 1
fi

if ! command -v brew >/dev/null 2>&1; then
  warn "Homebrew not found. Install it first: https://brew.sh"
  exit 1
fi

# ---------- VoiceInk ----------
say "Installing VoiceInk (dictation app)…"
if brew list --cask voiceink >/dev/null 2>&1; then
  echo "VoiceInk already installed — skipping."
else
  brew install --cask voiceink
fi

# ---------- Ollama ----------
say "Installing Ollama (local LLM runtime)…"
if command -v ollama >/dev/null 2>&1; then
  echo "Ollama already installed — skipping."
else
  brew install ollama
fi

say "Starting Ollama service…"
if brew services list | grep -q "^ollama.*started"; then
  echo "Ollama service already running."
else
  brew services start ollama
  sleep 2
fi

# Wait until Ollama responds
for i in {1..15}; do
  if curl -sf http://localhost:11434/api/tags >/dev/null 2>&1; then
    break
  fi
  sleep 1
done
if ! curl -sf http://localhost:11434/api/tags >/dev/null 2>&1; then
  warn "Ollama didn't come up on localhost:11434. Check 'brew services list'."
  exit 1
fi

# ---------- Models ----------
say "Pulling Qwen 3 8B (~5 GB) — fast hot-path cleanup model."
if ollama list | awk '{print $1}' | grep -qx "qwen3:8b"; then
  echo "qwen3:8b already pulled — skipping."
else
  if confirm "Pull qwen3:8b now? (~5 GB download)"; then
    ollama pull qwen3:8b
  else
    echo "Skipped. Pull later with: ollama pull qwen3:8b"
  fi
fi

say "Pulling Qwen 3 14B (~9 GB) — higher-quality rewrite model. Optional."
if ollama list | awk '{print $1}' | grep -qx "qwen3:14b"; then
  echo "qwen3:14b already pulled — skipping."
else
  if confirm "Pull qwen3:14b now? (~9 GB download, optional but recommended)"; then
    ollama pull qwen3:14b
  else
    echo "Skipped. Pull later with: ollama pull qwen3:14b"
  fi
fi

# ---------- Done ----------
say "Install complete."
cat <<EOF

Next steps (manual GUI config — takes ~2 minutes):

  1. Launch VoiceInk:           open -a VoiceInk
  2. Grant Accessibility + Microphone permissions when prompted.
  3. Follow the steps in:       dictation/voiceink-setup.md

That guide walks you through:
  - Setting Fn as the push-to-talk hotkey
  - Downloading the Parakeet ASR model from VoiceInk's Models tab
  - Pointing AI cleanup at Ollama (http://localhost:11434, qwen3:8b)
  - Pasting the cleanup prompt from prompts/cleanup.md

Test it: hold Fn anywhere with a text field, speak a sentence, release.

EOF
