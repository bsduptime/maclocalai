#!/usr/bin/env python3
"""Claude Code Stop hook: speak the last assistant message.

Receives the Stop event JSON on stdin, finds the last assistant message in
the session transcript, strips markdown, and speaks it via one of two
backends:

  - "say"        : macOS built-in `say` command (Tier 1 — zero install, mediocre voice)
  - "chatterbox" : POST text to a videngine TTS server (Tier 2 — natural,
                   voice-cloned via Chatterbox on a CUDA host like the
                   Jetson, over Tailscale or LAN)

Backend is picked via the VOICE_REPLY_BACKEND env var (default: "say").
If "chatterbox" is configured but unreachable, falls back to "say" so the
user still hears something. Designed to never block Claude: any error
exits 0 silently. Audio playback is detached, so the hook returns
immediately and the user can start the next turn without waiting.

Env vars:
  VOICE_REPLY_BACKEND       "say" (default) or "chatterbox"
  VOICE_REPLY_VOICE         voice name for `say` backend (default: Samantha)
  CHATTERBOX_URL            e.g. http://192.168.1.200:18080
  CHATTERBOX_VOICE          voice name from /voices (e.g. "devnen-austin")
  CHATTERBOX_TOKEN          optional bearer token if the server requires auth
  CHATTERBOX_EXAGGERATION   optional float 0.25-2.0 (server default 0.5)
  CHATTERBOX_CFG_WEIGHT     optional float 0.0-1.0  (server default 0.5)
  CHATTERBOX_TEMPERATURE    optional float 0.05-1.5 (server default 0.8)
  CHATTERBOX_SEED           optional int for reproducibility
"""

from __future__ import annotations

import json
import os
import re
import subprocess
import sys
import tempfile
import urllib.error
import urllib.request

MAX_CHARS = 2000  # cap so unusually long responses don't read for minutes
DEFAULT_SAY_VOICE = "Samantha"
DEFAULT_CHATTERBOX_VOICE = "devnen-austin"  # vetted male calm, not David's voice
CHATTERBOX_TIMEOUT_SEC = 60  # POST timeout to the TTS server (model gen can take a few seconds)


def strip_markdown(text: str) -> str:
    """Make markdown read naturally when spoken aloud."""
    text = re.sub(r"```[\s\S]*?```", " (code block) ", text)
    text = re.sub(r"`([^`]+)`", r"\1", text)
    text = re.sub(r"\[([^\]]+)\]\([^)]+\)", r"\1", text)
    text = re.sub(r"!\[[^\]]*\]\([^)]+\)", "", text)
    text = re.sub(r"^#{1,6}\s+", "", text, flags=re.MULTILINE)
    text = re.sub(r"\*\*([^*]+)\*\*", r"\1", text)
    text = re.sub(r"\*([^*]+)\*", r"\1", text)
    text = re.sub(r"__([^_]+)__", r"\1", text)
    text = re.sub(r"_([^_]+)_", r"\1", text)
    text = re.sub(r"^\s*[-*+]\s+", "", text, flags=re.MULTILINE)
    text = re.sub(r"^\s*\d+\.\s+", "", text, flags=re.MULTILINE)
    text = re.sub(r"^\|.*\|\s*$", "", text, flags=re.MULTILINE)
    text = re.sub(r"^[-:|\s]+$", "", text, flags=re.MULTILINE)
    text = re.sub(r"\n+sources?:.*$", "", text, flags=re.DOTALL | re.IGNORECASE)
    text = re.sub(
        r"[\U0001F300-\U0001FAFF\U0001F900-\U0001F9FF☀-➿]", "", text
    )
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()


def get_last_assistant_text(transcript_path: str) -> str | None:
    """Read the JSONL transcript and return the most recent assistant text."""
    try:
        with open(transcript_path, encoding="utf-8") as f:
            lines = f.readlines()
    except OSError:
        return None

    for line in reversed(lines):
        line = line.strip()
        if not line:
            continue
        try:
            entry = json.loads(line)
        except json.JSONDecodeError:
            continue
        if entry.get("type") != "assistant":
            continue
        message = entry.get("message", {}) or {}
        content = message.get("content")
        if isinstance(content, str):
            return content
        if isinstance(content, list):
            parts: list[str] = []
            for block in content:
                if isinstance(block, dict) and block.get("type") == "text":
                    parts.append(block.get("text", ""))
            if parts:
                return "\n\n".join(parts)
    return None


def kill_in_flight_audio() -> None:
    """Kill any in-flight say/afplay so a new turn doesn't stack voices."""
    for name in ("say", "afplay"):
        subprocess.run(
            ["pkill", "-x", name],
            check=False,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )


def speak_via_say(text: str, voice: str) -> None:
    proc = subprocess.Popen(
        ["say", "-v", voice],
        stdin=subprocess.PIPE,
        text=True,
        start_new_session=True,
    )
    if proc.stdin:
        proc.stdin.write(text)
        proc.stdin.close()


def _optional_float(name: str) -> float | None:
    raw = os.environ.get(name, "").strip()
    if not raw:
        return None
    try:
        return float(raw)
    except ValueError:
        return None


def _optional_int(name: str) -> int | None:
    raw = os.environ.get(name, "").strip()
    if not raw:
        return None
    try:
        return int(raw)
    except ValueError:
        return None


def speak_via_chatterbox(
    text: str, url: str, voice: str, token: str | None
) -> bool:
    """POST to the videngine TTS server's /synthesize, afplay the WAV.

    Returns True on success, False on any failure (so caller can fall back).
    """
    payload: dict = {"text": text, "voice": voice}
    # Optional tunables — only include if the env var is set; otherwise let
    # the server pick its defaults (exaggeration 0.5, cfg_weight 0.5,
    # temperature 0.8, seed random).
    for env_name, key in (
        ("CHATTERBOX_EXAGGERATION", "exaggeration"),
        ("CHATTERBOX_CFG_WEIGHT", "cfg_weight"),
        ("CHATTERBOX_TEMPERATURE", "temperature"),
    ):
        v = _optional_float(env_name)
        if v is not None:
            payload[key] = v
    seed = _optional_int("CHATTERBOX_SEED")
    if seed is not None:
        payload["seed"] = seed

    body = json.dumps(payload).encode("utf-8")
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"

    req = urllib.request.Request(
        url.rstrip("/") + "/synthesize",
        data=body,
        headers=headers,
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=CHATTERBOX_TIMEOUT_SEC) as resp:
            audio = resp.read()
    except (urllib.error.URLError, urllib.error.HTTPError, TimeoutError, OSError):
        return False
    if not audio or len(audio) < 64:
        return False

    # Write to a temp file and afplay it detached
    fd, path = tempfile.mkstemp(prefix="voice-reply-", suffix=".wav")
    try:
        with os.fdopen(fd, "wb") as f:
            f.write(audio)
    except OSError:
        return False

    try:
        subprocess.Popen(
            ["afplay", path],
            start_new_session=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    except Exception:
        try:
            os.unlink(path)
        except OSError:
            pass
        return False
    return True


def main() -> int:
    try:
        event = json.load(sys.stdin)
    except Exception:
        return 0

    if event.get("stop_hook_active"):
        return 0

    transcript_path = event.get("transcript_path")
    if not transcript_path:
        return 0

    text = get_last_assistant_text(transcript_path)
    if not text:
        return 0

    text = strip_markdown(text)
    if not text:
        return 0

    if len(text) > MAX_CHARS:
        text = text[:MAX_CHARS] + " (truncated)"

    backend = os.environ.get("VOICE_REPLY_BACKEND", "say").lower()

    kill_in_flight_audio()

    if backend == "chatterbox":
        url = os.environ.get("CHATTERBOX_URL", "").strip()
        voice = os.environ.get("CHATTERBOX_VOICE", DEFAULT_CHATTERBOX_VOICE)
        token = os.environ.get("CHATTERBOX_TOKEN", "").strip() or None
        if url and speak_via_chatterbox(text, url, voice, token):
            return 0
        # Fall through to `say` if chatterbox is unreachable / failed

    voice = os.environ.get("VOICE_REPLY_VOICE", DEFAULT_SAY_VOICE)
    try:
        speak_via_say(text, voice)
    except Exception:
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
