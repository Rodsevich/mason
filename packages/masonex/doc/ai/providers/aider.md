# Provider: `aider`

## Requirements

- `aider` installed and on `PATH`.
- A model configured (via `aider`'s own env vars or `~/.aider.conf.yml`).

## Default invocation

```yaml
aider:
  cmd: ["aider", "--no-stream", "--yes-always", "--message-file"]
  pass_prompt: arg
  timeout: 180s
```

The user envelope is passed as the path argument to `--message-file`
(masonex writes it to a temp file). System instructions are prepended
to the envelope.

## Notes

- `--yes-always` is required so aider does not prompt for git commits.
- aider is opinionated about working directories; if it picks up a
  `.git` you don't want it to touch, set `MASONEX_AI_PROVIDER=...` to
  another provider for that run.

## Verifying

```sh
masonex provider test
```
