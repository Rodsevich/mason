# Provider: `ollama` (local)

## Requirements

- Ollama daemon running locally (`ollama serve`).
- A pulled model (e.g., `ollama pull llama3.1`).

## Default invocation

```yaml
ollama:
  cmd: ["ollama", "run", "llama3.1"]
  pass_prompt: stdin
  timeout: 240s
```

The user envelope is piped via stdin. Replace `llama3.1` with any
local model: `qwen2.5-coder:14b`, `mistral`, `gemma3:27b`, etc.

## Customising the model

Edit `~/.masonex/providers.yaml`:

```yaml
ollama:
  cmd: ["ollama", "run", "qwen2.5-coder:14b"]
```

Or run `masonex provider edit` and change the `cmd` line.

## Notes

- The default Ollama CLI does not expose a separate system-prompt flag
  in `run` mode, so masonex prepends the system prompt with a
  `<<MASONEX_SYSTEM>>` marker. If you need stricter system handling,
  switch to a wrapper script or use the OpenAI-compatible HTTP API
  through a `custom` provider.
- Local models are slower than hosted ones; raise `timeout` if your
  hardware needs it (240s is a conservative default).

## Verifying

```sh
masonex provider test
```
