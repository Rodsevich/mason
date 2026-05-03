# Recipes

Patterns that keep showing up when authoring bricks with `| ai`.

## 1. One-line docstring

```mustache
/// {{ "Write a one-line dartdoc for class {{className}} that handles {{domain}}." | ai(expect: line, max_chars: 120) }}
```

Tight constraints (`expect: line`, `max_chars: 120`) keep the model
short and focused.

## 2. Kebab-case fixture id

```mustache
static const fixtureId =
    '{{ "Generate a unique kebab-case id for {{className}}" | ai(expect: identifier, case: kebab, max_chars: 40) }}';
```

`expect: identifier` accepts `_`, `-`, `.` separators; `case: kebab`
normalises whatever the model returned to the target casing.

## 3. Multi-line marketing blurb

```mustache
{{ "Write 2-3 sentence marketing copy for the {{domain}} {{className}}, in active voice." | ai(expect: paragraph, lines: 1..3, max_chars: 400) }}
```

`lines: 1..3` tells the validator (and the model) to stay between one
and three lines of output.

## 4. JSON config block

```mustache
const fixtures = {{ "List 5 colors of the rainbow as a JSON object {hex: name}" | ai(expect: json, retries: 3) }};
```

`expect: json` validates the model's output against `JSON.parse`; on
failure masonex re-prompts with the validation error attached.

## 5. Style-consistent identifier

```mustache
class {{className}} {
  /// {{ "1-line description of {{className}}" | ai(expect: line) }}
  /// SLA: {{ "service level acronym for {{className}}, in 4 letters max" | ai(expect: identifier, case: const, max_chars: 8) }}
}
```

Combining `case: const` with `max_chars` gives you upper-snake-case
constants without trusting the model to format on its own.

## 6. Localised string

```mustache
String greet() => '{{ "Translate to Spanish: \\"hello, world\\"" | ai(expect: line, language: es, max_chars: 80) }}';
```

`language: es` adds the natural-language hint to the envelope. Use it
together with `expect: line` to keep the result drop-in for a string
literal.

## 7. Restricted enumeration

```mustache
final theme = '{{ "Pick one theme: light, dark, hi-contrast" | ai(expect: enum, oneOf: [light, dark, hi-contrast]) }}';
```

`oneOf` enforces the result; the validator retries if the model returns
anything else.

## 8. Recurring prompt with shared cache key

```mustache
class A {
  static const tag = '{{ "tagline for FooKit" | ai(id: foo_tag, cache: always) }}';
}
class B {
  static const tag = '{{ "tagline for FooKit" | ai(id: foo_tag, cache: always) }}';
}
```

Same `id` plus `cache: always` makes both tags share the same cache
entry, so the model is invoked once even if the brick has the prompt
duplicated.

## 9. Brick-author note

```mustache
{{ "Generate the constructor body for {{className}}" | ai(expect: code:dart, description: "Match the style in lib/base_repository.dart; never call dart:io.") }}
```

`description` ends up in `<author_note>` of the envelope — context the
model uses without the brick author having to bloat the prompt itself.

## 10. Audit before render

Always run, especially after editing prompts:

```sh
masonex audit-ai
masonex ai-budget --budget 8000
masonex ai-context-preview --tag <tag-id-substring>
```

`audit-ai` lists every prompt; `ai-budget` flags oversized envelopes;
`ai-context-preview` prints the exact XML masonex would send so you
can review surrounding context, vars, and constraints.
