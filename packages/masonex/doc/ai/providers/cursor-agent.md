# Provider: `cursor-agent` (Cursor agent CLI)

## Requirements

- `cursor-agent` CLI installed and on `PATH`.

## Default invocation

```yaml
cursor-agent:
  cmd: ["cursor-agent", "--print"]
  pass_prompt: tmpfile
  timeout: 120s
```

masonex writes the user envelope to a temp file and passes its path as
the last positional argument. The system prompt is prepended to the
user envelope with a marker (Cursor's CLI doesn't expose a dedicated
flag for it).

## Verifying

```sh
masonex provider test
```
