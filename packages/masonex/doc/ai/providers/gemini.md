# Provider: `gemini` (Google Gemini CLI)

## Requirements

- Gemini CLI installed and on `PATH` (`gemini --version`).
- Authenticated against your Google account.

## Default invocation

```yaml
gemini:
  cmd: ["gemini", "--non-interactive"]
  pass_prompt: tmpfile
  pass_system: ["--system-instruction", "{system}"]
  timeout: 120s
```

masonex writes the user envelope to a temporary file and passes it as
the last positional argument; the system prompt is supplied via
`--system-instruction`.

## Verifying

```sh
masonex provider test
```

## Common errors

| Symptom | Likely cause |
|---|---|
| `command not found: gemini` | Not installed or not on PATH. |
| `Unauthorized` | Run `gcloud auth login` (or the Gemini CLI's own auth flow). |
| Long latency on first call | Cold start; tune `timeout` upward. |
