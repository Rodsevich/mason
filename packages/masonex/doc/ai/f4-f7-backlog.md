# F4–F7 backlog

This is the work explicitly deferred during the F0–F3 implementation. The
tracker is the source of truth for what still needs to happen before the
feature is ready for a 1.0 release.

## F2g — CLI flags on `mason make` itself

Already shipped as new subcommands (`audit-ai`, `validate`, `ai-cache`,
`ai-trace`, `provider`). Not yet shipped: parsing the AI flags
(`--no-ai`, `--refresh-ai`, etc.) on the existing `make` command and
plumbing them into `AiRenderOptions`. The orchestrator and integration
layer already understand them; only the wiring at the make-command level
is missing.

Owner-facing impact: today the AI feature is opt-in via the public
`String.render(... aiOptions: ...)` API. End-to-end CLI usage
(`mason make brick`) needs the flag plumbing before the next release.

## F4 — Adapters

Built-in adapters still missing (works today via `custom`):

- `gemini` (Google CLI)
- `codex` (OpenAI CLI)
- `cursor-agent`
- `aider` (`--message` mode)
- `ollama`

For each: a class extending `AiProviderAdapter`, a registry entry, a
`doc/ai/providers/<id>.md` page, and CLI fakes in `test/ai/fakes/`.

## F5 — UX polish

- `--review-ai` (interactive accept/regenerate/edit per tag).
- `--dry-run-ai` (run pass 1 only; report what would be written).
- `--ai-context-preview <id>` (already partially implemented — flag is
  declared but surface needs polish).
- Streaming spinners while many tags are in-flight.
- Diff vs cache on `--refresh-ai`.
- Smart truncation of large envelopes (`<brick_contents>` summary first).
- `masonex ai-budget <brick>` token estimates.

## F6 — Reference brick + tutorial + recipes

Already shipped: `bricks/ai_codegen_example/` with fixtures and a
README. Not yet shipped: a long-form tutorial (`tutorial.md`) and
recipes (`recipes.md`). The brick exercises every documented feature,
so the tutorial is mostly a write-up of what's already in code.

## F7 — Hardening

- Token-budget truncation strategy (currently no truncation; a brick
  larger than the model context will fail with a clear error).
- Internationalisation of interactive prompts (`MASONEX_LANG`).
- Performance benchmark target: pass-1 overhead < 50 ms with a hot cache
  for bricks with ≤ 20 AI tags.
- Public release notes + CHANGELOG entry.

## v2 ideas

- **Native filter registry inside mustachex** — make `| ai` just one of
  many filters consumers can register against the parser. Removes
  masonex's pre-processor (`AiTagRewriter`, `_transpileMasonSyntax`) in
  favour of a first-class `MustachexFilter` API on the engine. Detailed
  design in [`v2-rfc.md`](v2-rfc.md). Targets mustachex 2.0 + masonex
  0.3.0.
- `consider` / `consistent_with` for inter-tag style coherence.
- `examples` (few-shot) parameter.
- HTTP/MCP transport (only if a strong use-case appears).

## Non-goals (do not implement)

- Direct API integration with Anthropic / OpenAI / Google. CLIs only.
- AI-driven path selection. Paths stay deterministic.
- Pending-files / "manual-resume" recovery — replaced by abort-with-edit.
