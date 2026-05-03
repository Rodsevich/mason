# Provider: `codex` (OpenAI Codex CLI)

## Requirements

- `codex` CLI installed and on `PATH`.
- Authenticated.

## Default invocation

```yaml
codex:
  cmd: ["codex", "-p"]
  pass_prompt: stdin
  timeout: 120s
```

The CLI does not currently expose a system-prompt flag, so masonex
prepends the system instructions to the user envelope with a
`<<MASONEX_SYSTEM>>...<<MASONEX_END_SYSTEM>>` marker.

## Verifying

```sh
masonex provider test
```

## Notes

The `codex` CLI is in flux. If invocation breaks, edit the `cmd` list
in `~/.masonex/providers.yaml` to match the version you have installed.
