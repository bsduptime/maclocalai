# voice-replies

Closes the voice loop with [`dictation/`](../dictation/): Claude speaks responses back through your default audio output after each turn. Combined with dictation, the whole interaction becomes voice.

## Tiers (deliberate two-step design)

| Tier | Status | Backend | Setup | Quality | Latency |
|---|---|---|---|---|---|
| 1 — MVP | **shipped** | **macOS `say`** | zero (built into macOS) | mediocre (decent with Siri voices) | instant |
| 2 — Premium | **shipped** | **videngine TTS** (Chatterbox on Jetson, CUDA) | server lives in the content repo, hosted at `http://192.168.1.200:18080` | best — beats ElevenLabs in blind tests (63.75%); 36 voice profiles, voice cloning | ~7-12s per short line (GPU generation) |

**No middle tier (Kokoro)** by design. Two clear choices keep the mental model simple.

The client **falls back to `say` automatically** if the Chatterbox server is unreachable, so switching backends never leaves you with silence.

## Install

```bash
bash install.sh
```

The installer asks which backend you want:

- **`say`** (Tier 1) — picks a voice, tests it, registers the hook
- **`chatterbox`** (Tier 2) — asks for the server URL (default `http://192.168.1.200:18080`), voice name, optional bearer token; probes `/health`; registers the hook with chatterbox + a `say` fallback config

Either way the installer:

1. Copies `voice-reply.py` to `~/.claude/hooks/`
2. Backs up `~/.claude/settings.json` first
3. Registers / updates the Stop hook (won't duplicate if you re-run)

**Take-effect:** start a new Claude Code session. Existing sessions don't pick up newly-registered hooks.

You can re-run `install.sh` any time to switch backends or change voice.

## How it works

```
Claude finishes a turn
    │ Stop hook fires
    ▼
voice-reply.py:
  1. Reads the Stop event JSON from stdin
  2. Opens the session transcript (JSONL)
  3. Finds the most recent assistant message
  4. Strips markdown (headers, bold, links, code blocks, tables, emoji)
  5. Drops the trailing "Sources:" section
  6. Caps at 2000 characters
  7. Kills any in-flight audio (say / afplay)
  8. Speaks via the configured backend:
       say        → backgrounded `say -v <voice>`
       chatterbox → POST to /v1/audio/speech, afplay the returned WAV
                    (falls back to `say` if the server is unreachable)
    │
    ▼
audio out (speakers / AirPods)
```

If a new Claude turn starts before previous speech finishes, the script kills the in-flight `say` / `afplay` so voices don't overlap.

## Changing voice later

Re-run `install.sh`, or edit `~/.claude/settings.json` and update the `VOICE_REPLY_VOICE` value in the Stop hook command.

List installed voices:

```bash
say -v ?
```

For **Siri-quality** voices (much better than the classic Samantha/Daniel/etc.):

System Settings → Accessibility → Spoken Content → System Voice → click a voice (Ava, Allison, Tom, Joelle, etc.) → Download. Then re-run `install.sh` and type the voice name at the prompt.

## Uninstall

Edit `~/.claude/settings.json` and remove the Stop hook entry that references `voice-reply.py`.

## Tier 2 — videngine TTS

A single TTS service on the Jetson (`http://192.168.1.200:18080`) serves both this client and the videngine content pipeline. One CUDA process per Jetson is the safe pattern — see `feedback_jetson_one_cuda_process` memory.

### Voice catalogue

The server exposes 36 voices via `GET /voices`. Pick yours via `install.sh` (it probes the catalogue) or visit `http://192.168.1.200:18080/previews/` in a browser to listen to all of them.

Categories:

- **davidk-\*** — David's own recordings (8 voices). Good for narration *as* David. **Avoid for Claude** — most people find AI-in-their-own-voice uncanny long-term.
- **devnen-\*** — devnen/Chatterbox-TTS-Server pack, MIT-licensed (28 voices, mix of male/female). Recommended for Claude.

Two vetted picks for Claude:
- `devnen-austin` — male, calm. Assistant tone. **Default.**
- `devnen-elena` — female, dramatic.

### Optional tunables (env vars)

| Var | Range | Server default | What it does |
|---|---|---|---|
| `CHATTERBOX_EXAGGERATION` | 0.25–2.0 | 0.5 | Emotion intensity. ↑ for excited, ↓ for monotone. |
| `CHATTERBOX_CFG_WEIGHT` | 0.0–1.0 | 0.5 | Closest to a speed knob. ↓ = snappier, ↑ = more deliberate. |
| `CHATTERBOX_TEMPERATURE` | 0.05–1.5 | 0.8 | Sampling variety. ↓ = consistent, ↑ = varied. |
| `CHATTERBOX_SEED` | int | random | Set for reproducible output. |

Leave them unset and the server picks sensible defaults.

## Env vars (for reference)

| Var | Used by | Notes |
|---|---|---|
| `VOICE_REPLY_BACKEND` | both | `say` (default) or `chatterbox` |
| `VOICE_REPLY_VOICE` | say / fallback | macOS voice name (default `Samantha`) |
| `CHATTERBOX_URL` | chatterbox | e.g. `http://192.168.1.200:18080` |
| `CHATTERBOX_VOICE` | chatterbox | voice name from `/voices` (default `devnen-austin`) |
| `CHATTERBOX_TOKEN` | chatterbox | optional bearer if the server requires auth |
| `CHATTERBOX_EXAGGERATION` | chatterbox | optional float, see table above |
| `CHATTERBOX_CFG_WEIGHT` | chatterbox | optional float, see table above |
| `CHATTERBOX_TEMPERATURE` | chatterbox | optional float, see table above |
| `CHATTERBOX_SEED` | chatterbox | optional int |

## See also

- [`dictation/`](../dictation/) — voice input (the other half of the loop)
- [`jetsonlocalai/chatterbox-tts-server/`](https://github.com/bsduptime/jetsonlocalai/tree/main/chatterbox-tts-server) — the future CUDA-side server this stack will talk to in Tier 2
