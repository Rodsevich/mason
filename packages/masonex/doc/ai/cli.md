# CLI surface

## New flags on render commands

| Flag                          | Default | Effect |
|-------------------------------|---------|--------|
| `--no-ai`                     | off     | Skip pass 1. AI tags survive into the final render as visible strings. |
| `--refresh-ai[=<glob>]`       | off     | Bypass cache reads (still write). Optional glob to limit by tag id. |
| `--no-cache-ai`               | off     | Disable both reads and writes. |
| `--max-ai-concurrency <n>`    | 4       | Cap simultaneous AI invocations. |
| `--ai-context-preview[=<id>]` | off     | Print envelope without invoking provider. |
| `--review-ai`                 | off     | (F5) interactive accept/regenerate per tag. |
| `--dry-run-ai`                | off     | (F5) run pass 1 only; report what would be written. |
| `--non-interactive`           | off     | Fail instead of prompting. |
| `--provider <name>`           | —       | Override active provider for this run. |

> Hooking these flags into the `mason make` command surface is part of
> [F2g](f4-f7-backlog.md). Until then, callers using the public
> `String.render(... aiOptions: ...)` extension can wire any of them
> programmatically.

## New subcommands

| Command                                 | Purpose |
|-----------------------------------------|---------|
| `masonex validate [--brick <path>]`     | Static validation: `| ai` in path, syntax errors, etc. |
| `masonex audit-ai [--brick <path>]`     | List every `| ai` tag with prompts and parameters. |
| `masonex ai-cache stats`                | Cache size and entry count. |
| `masonex ai-cache clear`                | Wipe `.masonex/cache/ai/`. |
| `masonex ai-trace [--last N] [--tag X]` | Pretty-print invocations. |
| `masonex provider show`                 | Current providers config. |
| `masonex provider edit`                 | Open `~/.masonex/providers.yaml` in `$EDITOR`. |
| `masonex provider test`                 | Send a trivial prompt to the active provider. |
| `masonex provider reset`                | Remove `providers.yaml` (with confirm). |
| `masonex provider setup`                | Interactive setup wizard. |
| `masonex provider set-default <id>`     | Change default in `providers.yaml`. |
