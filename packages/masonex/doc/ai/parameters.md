# `ai(...)` parameters

Every `| ai(...)` argument with its type, default, and effect on both the
envelope and the post-processing pipeline. Parameters not listed here are
parsed but ignored (kept for forward-compat).

## Output shape

| Param        | Type | Default | Envelope effect | Post-processing |
|--------------|------|---------|-----------------|-----------------|
| `expect`     | `word`/`line`/`sentence`/`paragraph`/`json`/`yaml`/`code:<lang>`/`identifier`/`number`/`boolean`/`enum`/`raw` | `raw` | Sets `<expected_shape>`. | Validator + retry |
| `lines`      | int / range | — | `<lines>` | Validator + retry |
| `max_chars`  | int  | —       | `<max_chars>` | Validator + retry |
| `min_chars`  | int  | —       | `<min_chars>` | Validator + retry |
| `case`       | `camel`/`pascal`/`snake`/`kebab`/`const`/`dot` | — | Sets shape hint when `expect: identifier`. | Forced re-case after AI |
| `language`   | string | —     | `<language>` | — |

## Validation

| Param        | Type | Effect |
|--------------|------|--------|
| `match`      | regex / string | Output must match. Retry with feedback on failure. |
| `oneOf`      | list | Output must equal one of the values. |
| `forbid`     | regex / list / string | Output must not contain. |
| `schema`     | string (JSON Schema) | Used with `expect: json`. |
| `retries`    | int (default `2`) | Cap on retries before abort. |

## Style

| Param      | Type    | Effect |
|------------|---------|--------|
| `style`    | string  | `<style>` line in envelope |
| `tone`     | string  | `<tone>` line |
| `persona`  | string  | "actuá como …" prepended to prompt |

## Provider / model

| Param         | Type | Effect |
|---------------|------|--------|
| `provider`    | string | Override active provider for this tag. |
| `model`       | string | Pass through to CLI when supported. |
| `temperature` | double | Default `0`. |
| `seed`        | int    | Pass-through; mock honours it. |

## Context

| Param           | Type | Effect |
|-----------------|------|--------|
| `include`       | globs | Adds `<extra_files>`. |
| `exclude`       | globs | Strips files from `<brick_contents>`. |
| `extra_context` | string | Inlined as `<extra_context>`. |
| `description`   | string | Author note (`<author_note>`). |

## Cache / identity

| Param        | Type | Default | Effect |
|--------------|------|---------|--------|
| `id`         | string | hash of `(prompt, path, line)` | Stable identifier for cache, fixtures, traces. |
| `cache`      | `auto`/`always`/`never` | `auto` | Per-tag cache policy. |
| `cache_key`  | string | — | Force a cache key (rare; useful to share keys across tags). |

## Mechanics

| Param          | Type | Default | Effect |
|----------------|------|---------|--------|
| `trim`         | bool | `true`  | Strip whitespace from extremes. |
| `strip_fences` | bool | `true`  | Remove ```` ```lang … ``` ```` if present. |
| `inline`       | bool / `auto` | `auto` | Override inline-vs-block detection. |
| `timeout`      | duration | `60s` | Per-invocation timeout. |
