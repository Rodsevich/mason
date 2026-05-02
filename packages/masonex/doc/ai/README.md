# masonex AI subsystem

masonex's `| ai` filter delegates the *contents* of a Mustache tag to an
AI provider configured by the user, while keeping the *paths* of generated
files fully deterministic.

## Index

|Doc|What it covers|
|---|---|
|[`rfc.md`](rfc.md)|Source-of-truth RFC. Read this first if you're contributing.|
|[`syntax.md`](syntax.md)|Filter syntax reference (literal vs var, pipes, dot-method).|
|[`parameters.md`](parameters.md)|Every supported `ai(...)` parameter, with effect on prompt and post-processing.|
|[`envelope.md`](envelope.md)|The XML envelope masonex sends as the user prompt.|
|[`system-prompt.md`](system-prompt.md)|The fixed system prompt that explains masonex to the model.|
|[`providers.md`](providers.md)|Provider configuration and `~/.masonex/providers.yaml`.|
|[`cache-and-trace.md`](cache-and-trace.md)|Cache layout, trace format, debug commands.|
|[`atomicity.md`](atomicity.md)|Two-pass render guarantee: no files written if AI fails.|
|[`security.md`](security.md)|What's sent to the AI; privacy controls.|
|[`testing.md`](testing.md)|Mock provider + `brick_test/ai_fixtures.yaml`.|
|[`cli.md`](cli.md)|New flags and subcommands.|
|[`troubleshooting.md`](troubleshooting.md)|Common errors and fixes.|
|[`f4-f7-backlog.md`](f4-f7-backlog.md)|Phases not yet shipped (UX polish, more provider adapters, recipes).|
|[`v2-rfc.md`](v2-rfc.md)|v2 design: move the filter pipeline into mustachex itself; masonex registers `AiFilter` against it.|

## 30-second quickstart

```mustache
Champion: {{ "dime el último ganador del mundial de la FIFA" | ai(expect: word) | uppercase }}.
```

After `mason make`, that line renders to:

```text
Champion: ARGENTINA.
```

masonex resolves the AI tag in a separate pass *before* writing any file.
If anything goes wrong, the project is left untouched.

See [`rfc.md`](rfc.md) for the full spec.
