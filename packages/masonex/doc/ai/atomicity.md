# Atomicity guarantees

masonex performs AI rendering in **two passes** so the project under
generation never observes a half-rendered state.

## Pass 1 — Pre-resolution (in memory)

1. Scan every template in `__brick__/` for `| ai` and `.ai(...)` tags.
2. Parse the pipeline AST.
3. Resolve the head (literal vs variable, with Mustache pre-render).
4. Build the envelope.
5. Hash and look up the cache.
6. On miss, invoke the provider with bounded concurrency (default 4).
7. Validate the output (regex/lines/json/etc.) with retries-with-feedback.
8. If any tag ends in error after retries, **throw** — nothing has been
   written to the destination yet.

## Pass 2 — Mustache rendering

1. Take the rewritten template source where each `| ai` tag has been
   replaced by a synthetic `{{{__masonex_ai_<n>}}}` reference.
2. Inject the resolved values into the Mustache vars map.
3. Run the existing masonex transpiler + mustachex pipeline.

## Guarantees

- **No-write-on-failure.** Pass 1 has no side-effects on the destination
  project. Pass 2 starts only if Pass 1 succeeded for every tag.
- **Idempotency with cache caliente.** Two consecutive runs return
  byte-identical bytes assuming the cache is intact.
- **Replayability.** `masonex audit-ai`, `masonex validate` and
  `--dry-run-ai` are pure pass-1 operations — safe to run anywhere.

## What fails the render

| Cause                           | Behaviour                                |
|---------------------------------|------------------------------------------|
| `AiSyntaxError` (bad pipeline)  | abort                                     |
| `AiInPathError` (tag in a path) | abort                                     |
| Provider not configured / auth  | interactive recovery → abort              |
| Validation exhausted retries    | abort                                     |
| Provider timeout                | abort                                     |
| All in-flight tags succeed      | proceed to pass 2                         |
