# voice-replies

Closes the voice loop with [`dictation/`](../dictation/): Claude speaks responses back through your default audio output after each turn. Combined with dictation, the whole interaction becomes voice.

## Tiers (deliberate two-step design)

| Tier | Status | Backend | Setup | Quality | Latency |
|---|---|---|---|---|---|
| 1 — MVP | **shipped** | **macOS `say`** | zero (built into macOS) | mediocre (decent with Siri voices) | instant |
| 2 — Premium | planned | **Chatterbox on Jetson (CUDA), Tailscale to Mac** | see [`jetsonlocalai/chatterbox-tts-server/`](https://github.com/bsduptime/jetsonlocalai/tree/main/chatterbox-tts-server) | best — beats ElevenLabs in blind tests (63.75%) | sub-200ms first sound |

**No middle tier (Kokoro)** by design. Two clear choices keep the mental model simple.

## Tier 1: install (shipped)

```bash
bash install.sh
```

The installer:

1. Copies `voice-reply.py` to `~/.claude/hooks/`
2. Lets you pick a voice (and falls back to Samantha if the chosen voice isn't installed)
3. Tests the voice ("Hello from voice replies.")
4. Registers a Stop hook in `~/.claude/settings.json` (backs up the existing file first)

**Take-effect:** start a new Claude Code session. Existing sessions don't pick up newly-registered hooks.

## How Tier 1 works

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
  7. Backgrounds `say -v <voice>` so it doesn't block the next turn
    │
    ▼
audio out (speakers / AirPods)
```

If a new Claude turn starts before previous speech finishes, the script kills the in-flight `say` and starts the new one — no overlapping voices.

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

## Tier 2 (planned)

When you graduate from `say` to wanting better voice quality:

1. Stand up [`chatterbox-tts-server`](https://github.com/bsduptime/jetsonlocalai/tree/main/chatterbox-tts-server) on the Jetson.
2. Replace the `say` call in `voice-reply.py` with an HTTP POST to the Jetson server.
3. Pick a non-you Chatterbox voice reference for Claude (most people find AI-in-their-own-voice uncanny long-term).

This stack will ship a Tier 2 variant once that server exists.

## See also

- [`dictation/`](../dictation/) — voice input (the other half of the loop)
- [`jetsonlocalai/chatterbox-tts-server/`](https://github.com/bsduptime/jetsonlocalai/tree/main/chatterbox-tts-server) — the future CUDA-side server this stack will talk to in Tier 2
