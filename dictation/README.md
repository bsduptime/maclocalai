# Dictation stack

Push-to-talk system-wide voice input on Mac. Hold **Fn**, speak, release — your transcribed text appears in the focused field. Same UX as Wispr Flow, fully local.

## Stack

| Layer | Tool | Why | Required? |
|---|---|---|---|
| Dictation app | [VoiceInk](https://github.com/Beingpax/VoiceInk) | Open source, Wispr-Flow-style hold-to-talk, works in every Mac app, supports both Whisper and Parakeet | yes |
| ASR (speech → text) | NVIDIA **Parakeet TDT 0.6B v3** (downloaded inside VoiceInk) | Multilingual (English + German + 23 EU langs), ~10× faster than Whisper-large-v3-turbo on Apple Silicon, doesn't hallucinate during silence. ~200ms latency on M3+ via CoreML / Neural Engine. | yes |
| LLM cleanup | **Qwen 3 8B** via [Ollama](https://ollama.com) | Powers VoiceInk's built-in **Default** enhancement preset. Adds punctuation to long-form speech, removes fillers. ~5 GB at Q4. | **optional** |

Total disk: ~600 MB for Parakeet alone, ~5 GB extra for the cleanup model.

> **AI cleanup is optional.** Parakeet's raw output is already excellent for short utterances (terminal commands, chat messages). The cleanup layer's main practical benefit is **inserting punctuation in long-form speech** (a 5-minute brainstorm becomes proper sentences instead of a wall of words). For short messages it's pure overhead. Try without it first; add it if you do enough long-form to feel the difference.

## Why these picks

The full reasoning lives in [`research-notes.md`](research-notes.md) — short version:

- **Parakeet over Whisper** for English dictation — 2026 consensus has shifted; Parakeet is faster and doesn't hallucinate during silence (critical for always-on push-to-talk).
- **VoiceInk over SuperWhisper / MacWhisper** — open source, free, Fn-key-hold UX matches Wispr Flow exactly, and supports Parakeet via the Neural Engine path.
- **Qwen 3 over Llama / Mistral / Gemma** — Qwen 3 7B/8B class leads HumanEval and instruction-following benchmarks under 8B in 2026. Fast on Apple Silicon via Ollama Metal.

## Install

```bash
bash install.sh
```

After install, see [`voiceink-setup.md`](voiceink-setup.md) for the GUI configuration steps (hotkey, Parakeet model, optional AI cleanup).

## Hardware

- M1 or later (M2/M3/M4 strongly recommended)
- 16 GB RAM minimum
- ~6 GB free disk (Parakeet + qwen3:8b)
