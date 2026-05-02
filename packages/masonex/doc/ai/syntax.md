# Filter syntax

The `| ai` filter is a member of masonex's **filter pipeline**, a small
extension to Mustache parsed by masonex (mustachex itself is unchanged).

## Pipeline grammar (informal)

```text
tag        := head ( filterOp )*
head       := stringLiteral | identifier | bareLiteral
filterOp   := pipeFilter | dotFilter
pipeFilter := '|' identifier ( '(' args ')' )?
dotFilter  := '.' identifier '(' args ')'
args       := arg ( ',' arg )*
arg        := ( identifier ':' )? value
value      := stringLiteral | int | double | bool | identifier
            | duration | list | range | regex
```

## Head resolution

|Form|Treated as|Notes|
|---|---|---|
|`"campeón mundial"`|literal|Quotes are stripped. Escapes: `\n \t \r \" \' \\`.|
|`dime el campeon`|literal|Whitespace forces literal interpretation.|
|`varName`|variable lookup|Falls back to literal if `varName` is missing.|

Variables can carry arbitrary types; their `toString()` is used.

## Equivalent notations

These three forms compile to the **same** AST:

```mustache
{{ varName | ai(expect: word) | uppercase }}
{{ varName.ai(expect: word).uppercase() }}
{{ varName.ai(expect: word) | uppercase }}
```

So is this for literals:

```mustache
{{ "champion" | ai(expect: word) | uppercase }}
```

## Mustache inside literal prompts

Literal prompts are pre-rendered against the user's vars before being sent:

```mustache
{{ "doc para {{className}}" | ai(expect: line) }}
```

If `className == "FooRepository"`, the AI receives `doc para FooRepository`.

## Argument value types

| Type         | Example                  |
|--------------|--------------------------|
| string       | `"single"`, `'simple'`   |
| int          | `2`                      |
| double       | `0.5`                    |
| bool         | `true`, `false`          |
| identifier   | `word`, `pascal`         |
| duration     | `30s`, `2m`, `1h`        |
| list         | `[red, green, blue]`     |
| range        | `1..3`, `>=2`, `<=5`     |
| regex        | `/^[A-Z]+$/i`            |

## Restrictions

- `| ai` is **forbidden in paths and filenames**. `masonex validate` errors on it.
- Plain pipelines without `| ai` (e.g., `{{name | uppercase}}`) keep working
  as in current masonex via the existing transpilation step.
- **Nested string literals inside a literal head are not supported in v1.**
  Concretely:

  ```mustache
  Works:        {{ "doc para {{className}}" | ai }}
  Doesn't work: {{ "doc para {{ "es" | ai }}" | ai }}
  ```

  The inner `"es"` terminates the outer string literal. To compose AI calls,
  use a Mustache section `{{#x}}...{{/x}}` to lift the inner result into a
  variable, or split the work across two tags. Native nested-AI is on the
  v2 backlog ([`v2-rfc.md`](v2-rfc.md)).
- Mustache substitutions inside literal prompts only resolve plain
  variables (`{{varName}}`). Recase shorthand inside a literal
  (`{{varName.snakeCase()}}`) is forwarded verbatim to the AI; if you need
  the recased value in the prompt, expose it as a separate variable.
