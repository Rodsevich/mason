# Tutorial: your first brick with `| ai`

A step-by-step walkthrough of building, testing, and shipping a brick
that uses masonex's AI filter. Total time: ~15 minutes.

By the end you will have:

- A new brick with two `| ai` tags.
- Local fixtures so the brick renders deterministically without network.
- A working `mason make <brick>` invocation against a real provider.

## Prerequisites

```sh
dart pub global activate masonex
masonex --version           # 0.3.0-dev.1+
```

You'll also want one AI CLI installed and authenticated. Pick the path
that matches what's already on your machine:

| You have… | Run |
|---|---|
| Claude Code CLI | `claude --version` |
| Gemini CLI | `gemini --version` |
| Ollama (local) | `ollama --version && ollama pull llama3.1` |

## Step 1 — Configure the AI provider (once)

```sh
masonex provider setup
```

Follow the wizard. masonex writes `~/.masonex/providers.yaml` and
verifies the wiring with a tiny prompt. If it fails, edit the file and
re-run `masonex provider test`.

## Step 2 — Create the brick

```sh
masonex new my_repo
cd my_repo
```

Edit `__brick__/lib/{{className.snakeCase()}}.dart`:

```dart
/// {{ "Write a one-line dartdoc for class {{className}} in plain English." | ai(expect: line, max_chars: 120) }}
class {{className}} {
  /// Generated id for fixtures.
  static const fixtureId =
      '{{ "Generate a kebab-case id for {{className}}" | ai(expect: identifier, case: kebab, max_chars: 40) }}';
}
```

The first tag asks for a one-line dartdoc; the second for a kebab-case
identifier. Both are constrained: `expect:`, `max_chars:`, and `case:`
guide both the prompt and the post-processing.

## Step 3 — Validate offline

```sh
masonex validate
masonex audit-ai
```

`validate` confirms there are no syntax errors or `| ai` in paths.
`audit-ai` lists every prompt the brick will send to the AI — review
this before shipping a brick to teammates so there are no surprises.

## Step 4 — Render with mock fixtures

Create `brick_test/ai_fixtures.yaml`:

```yaml
fixtures:
  - match: "Write a one-line dartdoc"
    output: "Repository for managing FooThings end-to-end."
  - match: "Generate a kebab-case id"
    output: "foo-repository"
```

Render with the mock provider:

```sh
masonex make my_repo --use-mock-ai -o /tmp/my_repo_out -- --className FooRepository
```

Inspect `/tmp/my_repo_out/lib/foo_repository.dart`. Both `| ai` tags
should be replaced with the canned values.

## Step 5 — Render with the real provider

```sh
masonex make my_repo -o /tmp/my_repo_real -- --className UserRepository
```

The first run hits the cache (miss → invokes the provider). The second
run is instant (cache hit). Drop `--no-cache-ai` to disable, or
`--refresh-ai` to bypass cache reads.

## Step 6 — Inspect what happened

```sh
masonex ai-trace --last 5
masonex ai-cache stats
```

`ai-trace` prints the recent invocations with their hashes, durations
and provider. `ai-cache stats` shows how many entries are stored and
their total size.

## Step 7 — Estimate cost before scaling

```sh
masonex ai-budget --budget 8000
```

Heuristic estimate of input tokens per tag. Useful when adding tags or
expanding context to spot tags that risk blowing the model's window.

## Where to go next

- [`syntax.md`](syntax.md) — every supported pipeline form.
- [`parameters.md`](parameters.md) — full reference of `ai(...)` args.
- [`recipes.md`](recipes.md) — common patterns (docstrings, fixtures,
  translations, naming).
- [`providers.md`](providers.md) — how to swap providers, configure a
  custom one, or run on local hardware.
