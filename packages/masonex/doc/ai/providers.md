# AI providers

masonex talks to AI **CLIs** only — never to HTTP APIs directly. That
keeps secrets, billing and authentication in tools the user already
controls.

## Configuration file

`~/.masonex/providers.yaml` is the single source of truth. Example:

```yaml
default: claude

providers:
  claude:
    cmd: ["claude", "-p", "--output-format", "text"]
    pass_prompt: stdin
    pass_system: ["--append-system-prompt"]
    timeout: 120s
    notes: "Anthropic Claude Code CLI"

  my_local:
    cmd: ["ollama", "run", "llama3.1"]
    pass_prompt: stdin
    pass_system: null   # masonex prepends a marker to the user prompt
    timeout: 120s
    notes: "Local Ollama fallback"
```

Each provider entry:

| Field          | Required | Notes |
|----------------|----------|-------|
| `cmd`          | yes      | List of strings; first is the binary. |
| `pass_prompt`  | yes      | `stdin` / `tmpfile` / `arg`. |
| `pass_system`  | no       | List of flags or `null` (then prepended to user prompt). The token `{system}` is replaced by the system prompt body. |
| `timeout`      | yes      | `<n>s|m|h`. |
| `notes`        | no       | Free text shown by `masonex provider show`. |

## First-time setup

```sh
masonex provider setup
```

Walks the user through detection of CLIs on PATH and persists the file.

## Day-to-day commands

```sh
masonex provider show          # current config (no secrets)
masonex provider edit          # opens $EDITOR
masonex provider test          # sends a trivial prompt and prints reply
masonex provider reset         # delete after confirmation
masonex provider set-default <id>
```

## Built-in providers

| ID            | Status |
|---------------|--------|
| `claude`      | Full adapter ([details](providers/claude.md)). |
| `gemini`      | Stub descriptor; works today through `custom`. F4 will add the dedicated adapter. |
| `codex`       | Stub descriptor; F4. |
| `cursor-agent`| Stub descriptor; F4. |
| `aider`       | Stub descriptor; F4. |
| `ollama`      | Stub descriptor; F4. |

Anything not built in works via the `CustomProviderAdapter` — point `cmd`
at the binary and pick a `pass_prompt` mode.

## Failure recovery

When a provider invocation fails (auth, exit≠0, timeout) masonex shows:

```
AI provider failed: <stderr preview>

Choose:
  e) edit ~/.masonex/providers.yaml and retry
  a) abort the render
```

Choosing `e` opens `$EDITOR`, then re-tries the failing tag. Choosing `a`
aborts the render with no files modified.

In non-interactive mode (`MASONEX_NONINTERACTIVE=1` or stdin not a TTY)
masonex aborts directly with a clear error.
