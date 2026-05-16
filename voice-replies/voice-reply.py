#!/usr/bin/env python3
"""Claude Code Stop hook: speak the last assistant message via macOS `say`.

Receives the Stop event JSON on stdin, finds the last assistant message
in the session transcript, strips markdown, and pipes it to `say`.

Designed to never block Claude: any error exits 0 silently.
The `say` process is backgrounded, so the hook returns immediately
and the user can start their next turn without waiting for speech.

Voice is picked from the VOICE_REPLY_VOICE environment variable
(default: Samantha). List available voices: `say -v ?`
"""

from __future__ import annotations

import json
import os
import re
import subprocess
import sys

MAX_CHARS = 2000  # cap so unusually long responses don't read for minutes
DEFAULT_VOICE = "Samantha"


def strip_markdown(text: str) -> str:
    """Make markdown read naturally when spoken aloud."""
    # Drop fenced code blocks (replace with a hint so context is preserved)
    text = re.sub(r"```[\s\S]*?```", " (code block) ", text)
    # Inline code: keep the inner text
    text = re.sub(r"`([^`]+)`", r"\1", text)
    # Markdown links [text](url) -> text
    text = re.sub(r"\[([^\]]+)\]\([^)]+\)", r"\1", text)
    # Images
    text = re.sub(r"!\[[^\]]*\]\([^)]+\)", "", text)
    # Headers
    text = re.sub(r"^#{1,6}\s+", "", text, flags=re.MULTILINE)
    # Bold / italic
    text = re.sub(r"\*\*([^*]+)\*\*", r"\1", text)
    text = re.sub(r"\*([^*]+)\*", r"\1", text)
    text = re.sub(r"__([^_]+)__", r"\1", text)
    text = re.sub(r"_([^_]+)_", r"\1", text)
    # List markers
    text = re.sub(r"^\s*[-*+]\s+", "", text, flags=re.MULTILINE)
    text = re.sub(r"^\s*\d+\.\s+", "", text, flags=re.MULTILINE)
    # Tables: drop rows and divider lines
    text = re.sub(r"^\|.*\|\s*$", "", text, flags=re.MULTILINE)
    text = re.sub(r"^[-:|\s]+$", "", text, flags=re.MULTILINE)
    # Trailing "Sources:" / "Source:" section (with optional preceding blank lines)
    text = re.sub(
        r"\n+sources?:.*$", "", text, flags=re.DOTALL | re.IGNORECASE
    )
    # Emoji (rough — covers most common ranges)
    text = re.sub(
        r"[\U0001F300-\U0001FAFF\U0001F900-\U0001F9FF☀-➿]",
        "",
        text,
    )
    # Collapse excessive whitespace
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


def speak(text: str, voice: str) -> None:
    """Kill any in-flight `say` (so we don't stack), then start new one detached."""
    subprocess.run(
        ["pkill", "-x", "say"],
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    proc = subprocess.Popen(
        ["say", "-v", voice],
        stdin=subprocess.PIPE,
        text=True,
        start_new_session=True,  # detach so it survives our exit
    )
    if proc.stdin:
        proc.stdin.write(text)
        proc.stdin.close()


def main() -> int:
    try:
        event = json.load(sys.stdin)
    except Exception:
        return 0

    # Avoid re-speaking loops if some other hook continued the session
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

    voice = os.environ.get("VOICE_REPLY_VOICE", DEFAULT_VOICE)

    try:
        speak(text, voice)
    except Exception:
        pass

    return 0


if __name__ == "__main__":
    sys.exit(main())
