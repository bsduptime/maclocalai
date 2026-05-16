# voice-replies (planned, not yet built)

Closes the voice loop with [`dictation/`](../dictation/): Claude speaks responses back through your speakers / AirPods after each turn. Combined with dictation, the whole interaction becomes voice.

## Architecture

```
Claude finishes a turn
   ↓ Claude Code Stop hook fires
[script]
   1. Read the last assistant message from the session transcript
   2. Strip markdown (#, **, code blocks, links, etc. — TTS reads them literally)
   3. POST text to a TTS backend
[TTS backend]
   ↓ audio
[speakers / AirPods]
```

## Two backends (deliberate two-tier design)

| Tier | Backend | When | Setup | Quality | Latency |
|---|---|---|---|---|---|
| 1 — MVP | **macOS `say`** | proof-of-concept; throwaway sessions | zero (built into macOS) | mediocre (Sequoia+ Siri voices are decent) | instant |
| 2 — Premium | **Chatterbox on Jetson (CUDA), Tailscale to Mac** | daily-driver | see [`jetsonlocalai/chatterbox-tts-server/`](https://github.com/bsduptime/jetsonlocalai) | best — natural, expressive, beats ElevenLabs in blind tests (63.75%) | sub-200ms first sound |

**No middle tier (Kokoro)** by design. Two clear choices — instant-but-meh and premium-but-routed-via-Jetson — keeps the mental model simple.

## Why Chatterbox on Jetson, not on Mac?

Chatterbox's MPS (Apple GPU) support is currently broken — it falls back to CPU on Mac, giving 1-2s per utterance. The Jetson's CUDA path gets sub-200ms first sound. With Tailscale already in place, the Mac POSTs text to the Jetson TTS server and gets audio back — net latency is comparable to running TTS locally on the Mac, with much better quality.

## Voice profile choice

When configuring Chatterbox, pick a **non-you** voice reference for Claude. Most people find AI-as-themselves uncanny long-term. The existing `founder.m4a` clone in the content pipeline stays for narration use (where it should sound like David); Claude gets a different reference.

## Status

Not built. Next steps when picking this up:

1. Build the Tier 1 path (`say` + Stop hook + markdown stripper) — fastest validation that the loop is worth it at all.
2. Pick a Chatterbox voice reference for Claude.
3. Stand up `chatterbox-tts-server` on the Jetson (sibling stack in `jetsonlocalai`).
4. Swap the Mac client to point at the Jetson server.

## See also

- [`dictation/`](../dictation/) — voice input (the other half of the loop)
- [`jetsonlocalai/chatterbox-tts-server/`](https://github.com/bsduptime/jetsonlocalai) — the CUDA-side server this stack will talk to
