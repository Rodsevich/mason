# Provider: `claude` (Anthropic Claude Code CLI)

## Requirements

- Anthropic Claude Code CLI installed and on `PATH` (`claude --version`).
- Logged in (`claude /login` interactively once).

## Default invocation

```yaml
claude:
  cmd: ["claude", "-p", "--output-format", "text"]
  pass_prompt: stdin
  pass_system: ["--append-system-prompt"]
  timeout: 120s
```

masonex passes the user envelope on `stdin` and the system prompt as the
single argument that follows `--append-system-prompt`.

## Verifying the wiring

```sh
masonex provider test
```

Expected output:

```
Testing provider "claude" ...
  reply: ok
  duration: 1234ms
```

## Common errors

| Symptom                                | Likely cause |
|----------------------------------------|--------------|
| `command not found: claude`            | CLI not installed or not on PATH. |
| `Unauthorized` / `Please log in`       | `claude /login` was not run, or the session expired. |
| Long latency on first invocation       | model warmup; tune `timeout` upward. |

## Notes

- The exact model used is whatever the user has configured in their
  Claude Code settings. masonex only tells the model what to do; it does
  not pick a model unless the brick's tag uses `model:`.
- Output format is forced to `text` so masonex receives the raw reply
  without any wrapping.
