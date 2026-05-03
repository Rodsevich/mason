# Migration: adopting `| ai` in an existing brick

This guide walks you through adding AI-assisted templating to a brick
that already exists in your codebase. No big-bang rewrite required —
the `| ai` filter slots in alongside legacy lambdas and recase
shorthand.

## Compatibility matrix

| Brick syntax in use | After migration | Required action |
|---|---|---|
| `{{name}}` | unchanged | none |
| `{{name.snakeCase}}` | unchanged | none |
| `{{name | upperCase}}` | unchanged | none |
| `{{#upperCase}}{{x}}{{/upperCase}}` | unchanged | none |
| `{{ "..." | ai(...) }}` (new) | new behaviour | bump masonex to 0.3.0+ |

masonex 0.3.0 ships with mustachex 2.0.0; both are backward-compatible.
Existing bricks render byte-identical bytes.

## Step 1 — Bump dependencies

In your brick's `brick.yaml`:

```yaml
environment:
  mason: ^0.1.2     # masonex compatibility marker
```

If your team consumes the brick via masonex 0.2.x, ask them to upgrade:

```sh
dart pub global activate masonex
```

## Step 2 — Configure a provider once per machine

```sh
masonex provider setup
masonex provider test
```

CI typically uses `--use-mock-ai` instead — see step 4.

## Step 3 — Add your first `| ai` tag

Pick a value that's hard to template by hand (a dartdoc, a fixture
description, a marketing line). Replace the static text with:

```mustache
{{ "Write a one-line dartdoc for {{className}}." | ai(expect: line, max_chars: 120) }}
```

Run `masonex audit-ai` to verify the prompt looks right.

## Step 4 — Make CI deterministic

Add `brick_test/ai_fixtures.yaml`:

```yaml
fixtures:
  - match: "Write a one-line dartdoc"
    output: "Generated description placeholder."
```

Configure CI to run with `--use-mock-ai`:

```sh
masonex make my_brick --use-mock-ai -o build/out
```

The mock provider replays the fixtures; renders are deterministic and
cost zero tokens.

## Step 5 — Audit before publishing

Ship with these in your release checklist:

```sh
masonex validate                # static checks
masonex audit-ai                # list every prompt
masonex ai-budget --budget 8000 # spot oversized envelopes
masonex make my_brick --use-mock-ai --dry-run-ai
```

## Common pitfalls

### `_transpileMasonSyntax` and `| ai` both touch the tag

Resolved automatically: masonex skips the legacy transpile step for
tags that contain `| ai` or `.ai(`, so the entire chain reaches
mustachex unchanged.

### Existing tests break because the AI runs in CI

Either:

- Use `--no-ai` in the test command to short-circuit the pre-resolution
  pass (AI tags survive into the output as raw template text).
- Or set up `brick_test/ai_fixtures.yaml` and `--use-mock-ai`. This is
  the recommended path for any brick test that asserts on specific
  output.

### The brick has variables that change naming

Use `case:` to normalise:

```mustache
{{ "name for the {{domain}} module" | ai(expect: identifier, case: snake) }}
```

Whatever the model returns ("FooBarBaz", "foo bar baz", "foo-bar-baz")
becomes `foo_bar_baz`.

## Coexistence with `ai_agent_configs`

The `bricks/ai_agent_configs/` brick is unrelated and addresses a
different problem (shipping IDE rules to a project). The `| ai` filter
operates inside any brick at render time. They compose freely: an
`ai_agent_configs` install can sit next to a brick that uses `| ai`
internally.
