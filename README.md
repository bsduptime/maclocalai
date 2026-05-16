# maclocalai

Reproducible setup scripts for running AI workloads locally on Apple Silicon Macs. No subscriptions, no cloud round-trips, no data leaving your machine.

Each subfolder is a self-contained stack with its own `install.sh` and notes.

## Available stacks

| Stack | What you get |
|---|---|
| [`dictation/`](dictation/) | Push-to-talk system-wide voice input (hold Fn → speak → release → text appears). Wispr-Flow-style UX, fully local: VoiceInk + Parakeet for ASR, optional Ollama + Qwen 3 for cleanup. |
| [`voice-replies/`](voice-replies/) | Claude speaks responses aloud after each turn (Stop hook → markdown-stripped → macOS `say`). Tier 1 (MVP) shipped; Tier 2 routes through Chatterbox on the Jetson for premium quality (see [jetsonlocalai](https://github.com/bsduptime/jetsonlocalai)). |

Together, `dictation/` + `voice-replies/` close the voice loop with Claude Code — you talk, Claude responds aloud, you talk again. More stacks coming as I add them.

## Requirements

- Apple Silicon Mac (M1 or later)
- macOS 14+
- [Homebrew](https://brew.sh)
- ~20 GB free disk space per stack (models are big)

## Quick start

```bash
git clone https://github.com/bsduptime/maclocalai.git
cd maclocalai
bash install.sh
```

`install.sh` is a menu — pick which stacks to install.

Or jump straight to a stack:

```bash
bash dictation/install.sh
```

## License

MIT — see [LICENSE](LICENSE).

---

*Mac is a trademark of Apple Inc. This project is not affiliated with Apple.*
