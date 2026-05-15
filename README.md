# maclocalai

Reproducible setup scripts for running AI workloads locally on Apple Silicon Macs. No subscriptions, no cloud round-trips, no data leaving your machine.

Each subfolder is a self-contained stack with its own `install.sh` and notes.

## Available stacks

| Stack | What you get |
|---|---|
| [`dictation/`](dictation/) | Push-to-talk system-wide voice input (hold Fn → speak → release → text appears). Wispr-Flow-style UX, fully local: VoiceInk + Parakeet for ASR, Ollama + Qwen 3 for cleanup. |

More stacks coming as I add them.

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
