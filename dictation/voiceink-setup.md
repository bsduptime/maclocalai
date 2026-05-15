# VoiceInk post-install setup

After `install.sh` finishes, do these one-time steps in the VoiceInk GUI.

> Menu paths reflect VoiceInk 1.76 (May 2026). Names may shift slightly between versions — look for the equivalent option if you see a renamed setting.

## 1. Launch and grant permissions

```bash
open -a VoiceInk
```

When prompted, grant:

- **Microphone** — to capture your voice
- **Accessibility** — to insert the transcribed text into the focused field

System Settings → Privacy & Security → Accessibility/Microphone → enable VoiceInk.

## 2. Set the push-to-talk hotkey to Fn

VoiceInk → Settings → **Recorder / Hotkey**

- Mode: **Push to talk** (hold to record, release to transcribe)
- Hotkey: press **Fn**

Test: hold Fn anywhere — VoiceInk's recording indicator should appear; release and the transcript should paste.

## 3. Download the Parakeet ASR model

VoiceInk → Settings → **Models**

- Find **Parakeet TDT 0.6B** (NVIDIA / FluidAudio CoreML build) and click Download (~600 MB)
- Set it as the **active model**

Why Parakeet over Whisper for dictation:

- ~10× faster than `whisper-large-v3-turbo` on Apple Silicon
- Runs on the Neural Engine via CoreML (~200 ms latency on M3+)
- Doesn't hallucinate during silence — important for always-on PTT

If Parakeet isn't listed in your VoiceInk version, fall back to **whisper-large-v3-turbo** (still excellent — what most local setups used through 2025).

## 4. (Optional) Wire AI cleanup to Ollama

Skip this if you're happy with raw Parakeet output. The cleanup step's main practical benefit is **inserting punctuation in long-form speech** — Parakeet adds basic periods but won't structure a 5-minute brainstorm into proper sentences. For short utterances (terminal commands, chat messages) it's usually overkill.

VoiceInk → Settings → **Enhancement**

- Provider: **Ollama** (or "Custom OpenAI-compatible endpoint")
- Endpoint: `http://localhost:11434`
- Model: `qwen3:8b`
- Active preset: **Default** (built-in — handles filler removal + punctuation correctly without a custom prompt)

Test: dictate *"um so like I was thinking maybe we could uh push this to next week"* → should come back as something like *"I was thinking we could push this to next week."*

### About the other built-in preset

**Assistant** is a different feature entirely — triggered by saying "Hey!" at the start of recording, it treats your speech as a question and returns the LLM's *answer* instead of a cleaned transcript (like a voice ChatGPT). For people who already have Claude or another frontier model open, it's redundant. Leave Default selected.

### Hotkey to switch presets mid-recording

`Cmd+1`, `Cmd+2`, etc. (or `Opt+number`) cycles between presets while you're recording. Useful if you want to flip between cleanup and Assistant on the fly.

### Multilingual note

Default cleanup with `qwen3:8b` works correctly when each utterance is single-language. The only failure mode is mid-sentence English↔German switching (the model may settle on one language for the whole output). In normal speech, you don't usually code-switch mid-sentence, so this rarely bites.

## Troubleshooting

**Fn doesn't trigger recording.** macOS may swallow Fn for emoji picker or dictation. System Settings → Keyboard → Press 🌐 key to: **Do Nothing** (or **Change Input Source**). Disable Apple's built-in dictation if it conflicts.

**"Connection refused" to Ollama.** Check it's running: `brew services list | grep ollama`. Restart with `brew services restart ollama`.

**Cleanup is slow or you want pure ASR.** Disable AI Enhancement — Parakeet alone is fast and accurate; cleanup is purely a formatting layer.

**Cleanup translates between languages.** The Default preset only does this on mid-sentence code-switching. If you hit it often, disable enhancement for short utterances and re-enable only for long-form work.
