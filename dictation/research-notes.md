# Why these picks (research notes, May 2026)

Snapshot of the reasoning behind the dictation stack choices. The landscape changes — re-verify before recommending to others in 12+ months.

## ASR: Parakeet over Whisper

In 2024–2025, `whisper-large-v3-turbo` was the default local-ASR choice. By early 2026 NVIDIA's **Parakeet TDT 0.6B** displaced it for English-only dictation:

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

## LLM: Qwen 3 over Llama / Mistral / Gemma

Verified May 2026 against ollama.com/library:

| Model | Tag | Notes |
|---|---|---|
| Qwen 3 8B | `qwen3:8b` | Best instruction-following + reasoning under 8B; HumanEval 76.0 leads class |
| Qwen 3 14B | `qwen3:14b` | Same family, more capacity for structural rewrites; ~9 GB at Q4, fits 16 GB Macs |
| Llama 3.3 8B | not on Ollama at time of writing (only `llama3.3:70b`) | Skip |
| Mistral Small 3.2 | `mistral-small3.2:24b` | 24B is too large for 18 GB Macs at decent quant |
| Gemma 3 12B | not verified on Ollama at writing | Reasonable alternative if you prefer Google models |

For our two use cases — fast hot-path cleanup and on-demand polished rewrites — Qwen 3 8B and 14B cover the spectrum cleanly without leaving the same model family (consistent prompt behavior).

## Hardware sanity check

Stack memory footprint at Q4:

- Parakeet 0.6B: ~600 MB
- qwen3:8b: ~5 GB
- qwen3:14b: ~9 GB

You won't run all three at peak simultaneously — Parakeet runs during recording, then unloads; one LLM runs after release. ~9 GB resident peak is a comfortable fit on 16 GB and trivial on 18 GB+.

## Sources

- [Parakeet V3 vs Whisper — Whisper Notes](https://whispernotes.app/blog/parakeet-v3-default-mac-model)
- [Whisper to Parakeet on Apple Neural Engine — MacParakeet](https://macparakeet.com/blog/whisper-to-parakeet-neural-engine/)
- [mac-whisper-speedtest benchmarks — anvanvan/GitHub](https://github.com/anvanvan/mac-whisper-speedtest)
- [Best Open-Source LLM May 2026 — Codersera](https://codersera.com/blog/best-open-source-llm-2026-llama-4-qwen-3-5-deepseek-v4-gemma-4-mistral/)
- [Best Local LLMs May 2026 — PromptQuorum](https://www.promptquorum.com/local-llms)
- [VoiceInk on GitHub — Beingpax/VoiceInk](https://github.com/Beingpax/VoiceInk)
- [VoiceInk vs Wispr Flow](https://tryvoiceink.com/wispr-flow-alternative/)
