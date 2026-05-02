# Troubleshooting

## "No AI provider configured"

Run `masonex provider setup` once. It writes `~/.masonex/providers.yaml`.

## "Configured AI provider \"claude\" is unavailable"

`claude` (or whatever binary is in `cmd[0]`) is not on `PATH`. Install
the CLI or edit the path:

```sh
masonex provider edit
```

## "AI provider \"claude\" not authenticated"

Log in with the provider's own CLI (e.g., `claude /login`). masonex does
not handle credentials.

## "AI envelope for tag … is too large"

The brick + current file + extras exceed the model's context window.
Mitigations:

- Add `ai.context.exclude` entries in `brick.yaml`.
- Split the brick into smaller bricks.
- Use `include:` / `exclude:` per tag to scope context.

## Render produced an unexpected value

```sh
masonex ai-trace --last 5
masonex ai-cache stats
```

The cache + trace let you inspect exactly what was sent and what came
back. Use `--refresh-ai` to bypass cache reads.

## Tests fail with "MockAiProvider: missing fixture"

Add the missing entry to `brick_test/ai_fixtures.yaml`. Use either an
exact `tag_id:` or a `match:` substring of the prompt.

## "AI filter is not allowed in paths"

`{{ "..." | ai }}` cannot be used in filenames or directory names. Move
the filter into a file's contents.

## `MASONEX_ERROR:` in output

The model returned the sentinel — it could not satisfy the request. The
text after the colon is its reason. Either tweak the prompt or add a
`description:` clarifying intent.
