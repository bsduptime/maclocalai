# Why these picks (research notes, May 2026)

Snapshot of the reasoning behind the dictation stack choices. The landscape changes — re-verify before recommending to others in 12+ months.

## ASR: Parakeet over Whisper

In 2024–2025, `whisper-large-v3-turbo` was the default local-ASR choice. By early 2026 NVIDIA's **Parakeet TDT 0.6B** displaced it for live dictation. The v3 variant adds multilingual support (English + German + 23 other European languages) at a tiny English-accuracy cost (6.32% vs 6.05% WER) over the v2 English-only variant:

- ~10× faster than whisper-large-v3-turbo (Whisper Notes benchmark)
- FluidAudio's CoreML build runs on the Apple Neural Engine — ~193 ms average latency on M3+, faster than any MLX-based Whisper
- Trained on 36k hours of non-speech audio mapped to empty strings, so it stays silent during silence — no Whisper-style "thanks for watching" hallucinations

Whisper-large-v3-turbo is still the right call for: multilingual transcription, batch video processing (better punctuation on long-form), or any case where you can't get a Parakeet build for your tooling.

## Dictation app: VoiceInk

Top-tier local Mac dictation apps in May 2026: **VoiceInk** (open source, free), **SuperWhisper** ($, polished), **Spokenly** (free), **MacWhisper** ($, batch-first), **Voibe** ($).

Picked VoiceInk because:

- Open source (forkable, scriptable, no vendor risk)
- One-time-install, no subscription
- Hold-Fn-to-record matches Wispr Flow's UX exactly
- Supports Parakeet via the CoreML/ANE path
- Maintained (Beingpax/VoiceInk on GitHub)

## LLM cleanup model: Qwen 3 8B

Verified May 2026 against ollama.com/library:

| Model | Tag | Notes |
|---|---|---|
| Qwen 3 8B | `qwen3:8b` | Best instruction-following + reasoning under 8B; HumanEval 76.0 leads class. ~5 GB at Q4. |
| Llama 3.3 8B | not on Ollama at time of writing (only `llama3.3:70b`) | Skip |
| Mistral Small 3.2 | `mistral-small3.2:24b` | 24B is too large for 18 GB Macs at decent quant |
| Gemma 3 12B | not verified on Ollama at writing | Reasonable alternative if you prefer Google models |

We deliberately did **not** wire a heavier "rewrite" model into VoiceInk. For occasional polished rewrites, paste into Claude or another frontier model — that's more flexible than burning a local LLM round-trip on every utterance, and frontier models do that job materially better than anything local in the 14B–24B class.

## Hardware sanity check

Stack memory footprint at Q4:

- Parakeet 0.6B: ~600 MB
- qwen3:8b: ~5 GB

Parakeet runs during recording then unloads; qwen3:8b runs after release. Total resident peak well under 6 GB, trivial on 16 GB+.

## Sources

- [Parakeet V3 vs Whisper — Whisper Notes](https://whispernotes.app/blog/parakeet-v3-default-mac-model)
- [Whisper to Parakeet on Apple Neural Engine — MacParakeet](https://macparakeet.com/blog/whisper-to-parakeet-neural-engine/)
- [mac-whisper-speedtest benchmarks — anvanvan/GitHub](https://github.com/anvanvan/mac-whisper-speedtest)
- [Best Open-Source LLM May 2026 — Codersera](https://codersera.com/blog/best-open-source-llm-2026-llama-4-qwen-3-5-deepseek-v4-gemma-4-mistral/)
- [Best Local LLMs May 2026 — PromptQuorum](https://www.promptquorum.com/local-llms)
- [VoiceInk on GitHub — Beingpax/VoiceInk](https://github.com/Beingpax/VoiceInk)
- [VoiceInk vs Wispr Flow](https://tryvoiceink.com/wispr-flow-alternative/)
