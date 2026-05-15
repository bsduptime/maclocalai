# Dictation stack

Push-to-talk system-wide voice input on Mac. Hold **Fn**, speak, release — your transcribed text appears in the focused field. Same UX as Wispr Flow, fully local.

## Stack

| Layer | Tool | Why |
|---|---|---|
| Dictation app | [VoiceInk](https://github.com/Beingpax/VoiceInk) | Open source, Wispr-Flow-style hold-to-talk, works in every Mac app, supports both Whisper and Parakeet |
| ASR (speech → text) | NVIDIA **Parakeet TDT 0.6B** (downloaded inside VoiceInk) | ~10× faster than Whisper-large-v3-turbo on Apple Silicon, English-only, doesn't hallucinate during silence. ~200ms latency on M3+ via CoreML / Neural Engine. |
| LLM cleanup (hot path) | **Qwen 3 8B** via [Ollama](https://ollama.com) | Filler removal, light formatting, punctuation. ~5 GB at Q4. Best instruction-following under 8B as of 2026. |
| LLM cleanup (heavy rewrite) | **Qwen 3 14B** via Ollama | "Rewrite this as a polished email" / structural rewrites. ~9 GB at Q4. Optional. |

Total disk: ~15 GB for both LLMs + ~600 MB for Parakeet.

## Why these picks

The full reasoning lives in [`research-notes.md`](research-notes.md) — short version:

- **Parakeet over Whisper** for English dictation — 2026 consensus has shifted; Parakeet is faster and doesn't hallucinate during silence (critical for always-on push-to-talk).
- **VoiceInk over SuperWhisper / MacWhisper** — open source, free, Fn-key-hold UX matches Wispr Flow exactly, and supports Parakeet via the Neural Engine path.
- **Qwen 3 over Llama / Mistral / Gemma** — Qwen 3 7B/8B class leads HumanEval and instruction-following benchmarks under 8B in 2026. Fast on Apple Silicon via Ollama Metal.

## Install

```bash
bash install.sh
```

After install, see [`voiceink-setup.md`](voiceink-setup.md) for the GUI configuration steps (hotkey, AI cleanup endpoint, prompt).

## Hardware

- M1 or later (M2/M3/M4 strongly recommended)
- 16 GB RAM minimum (18 GB+ recommended for the 14B model)
- ~15 GB free disk
