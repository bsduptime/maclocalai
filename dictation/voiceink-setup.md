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

## 4. Wire AI cleanup to Ollama

VoiceInk → Settings → **AI Enhancement** (or "Post-processing" / "AI cleanup")

- Provider: **Ollama** (or "Custom OpenAI-compatible endpoint")
- Endpoint: `http://localhost:11434`
- Model: `qwen3:8b`
- System prompt: paste the contents of [`prompts/cleanup.md`](prompts/cleanup.md)
- Enable: ✅

Test: dictate "um so like I was thinking maybe we could uh push this to next week" — you should get back something like *"I was thinking we could push this to next week."*

## 5. (Optional) Add a "polished rewrite" preset

If VoiceInk supports multiple AI presets / hotkey-bound modes, add a second one:

- Model: `qwen3:14b`
- Prompt: see [`prompts/rewrite.md`](prompts/rewrite.md)
- Bind to a different hotkey (e.g. Fn+Shift)

Use `qwen3:8b` for normal dictation (fast). Use `qwen3:14b` when you want it to actually restructure rambling thoughts into a polished message.

## Troubleshooting

**Fn doesn't trigger recording.** macOS may swallow Fn for emoji picker or dictation. System Settings → Keyboard → Press 🌐 key to: **Do Nothing** (or **Change Input Source**). Disable Apple's built-in dictation if it conflicts.

**"Connection refused" to Ollama.** Check it's running: `brew services list | grep ollama`. Restart with `brew services restart ollama`.

**Cleanup is slow.** Switch to `qwen3:8b` (faster than `qwen3:14b`), or disable AI cleanup entirely for ASR-only mode.

**Cleanup over-edits / changes meaning.** Tighten the system prompt — see notes in [`prompts/cleanup.md`](prompts/cleanup.md).
