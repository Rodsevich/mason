# RFC: masonex placeholder mode for Dart bricks

| Field        | Value                                                        |
|--------------|--------------------------------------------------------------|
| Status       | Draft                                                        |
| Version      | 0.6.0                                                        |
| Targets      | masonex 0.4.0                                                |
| Companion    | `vscode-masonex` extension (separate repo, drives the UX)    |
| Last edited  | 2026-05-03                                                   |

> Goal: a brick author edits `__brick__/lib/foo.dart` as if it were
> ordinary Dart — analyzer-clean, autocompletes, formats, refactors,
> runs tests directly — while masonex still recognises the
> substitutions and iterations it must apply at render time.

## 1. The whole idea in one paragraph

Two ways to write a brick `.dart` file as **valid Dart**, both
compatible and mixable:

- **Inline form** — wrap Mustache tags in block comments next to a
  dummy token: `class /*{{className}}*/ Foo { … }`. masonex unwraps
  the comment and consumes the dummy token at render time.
- **Pragma form** — attach `@pragma('masonex:replace', {...})` (or
  `'masonex:header'` on a `library;` directive for file-level scope)
  to any declaration. The map's `'token' -> '{{tag}}'` entries
  rewrite that exact token (keyword, type name, or identifier) within
  the scope of the annotation.

A file can use either, or both (pragma for repeated placeholders and
keyword/type substitutions, inline for one-offs and for sections /
iterations). No DSL, no loop IDs, no YAML — replacements are
expressed as Map literals, sections are plain Mustache wrapped in
block comments.

```dart
class /*{{className.pascalCase()}}*/ Foo {
  /*{{#fields}}*/
  final /*{{type.pascalCase()}}*/ String /*{{name.camelCase()}}*/ field;
  /*{{/fields}}*/
}
```

After pre-processing, masonex sees:

```mustache
class {{className.pascalCase()}} {
  {{#fields}}
  final {{type.pascalCase()}} {{name.camelCase()}};
  {{/fields}}
}
```

The reverse direction is what matters: the source on disk is **valid
Dart**. `Foo`, `String`, `field` are real identifiers; the analyzer is
happy; you can run a smoke test against the file.

## 2. Why this works

Two facts make the design fall out naturally:

1. **Block comments are first-class in Dart** and can appear adjacent
   to almost any token (`class /*x*/ Foo`, `final /*x*/ T name`,
   `void /*x*/ method()`). The analyzer ignores their content.
2. **Mustache syntax already covers everything we need**: `{{var}}`,
   `{{var.recase()}}`, `{{#section}}…{{/section}}`,
   `{{^inverse}}…{{/inverse}}`, partial `{{>name}}`, comment `{{!txt}}`
   and the new v2 filters (`{{ x | filter(args) }}`, `{{ "lit" | ai }}`).

So the only thing masonex needs to do is *unwrap* the comments. No new
templating concepts, no new tooling vocabulary.

## 3. Pre-processor rules

Three independent rewrites run in this order:

### 3.1. Pragma rewrite (token-level substitution map)

Any declaration in the file MAY carry an `@pragma('masonex:replace',
{...})` annotation whose options is a `Map<String, String>` from
**source-token text** to **Mustache tag**. The pre-processor walks
every token within the annotated declaration's source range; if a
token's lexeme matches a key, it's rewritten to the value.

The shorthand `@pragma('masonex:header', {...})` attached to a
`library;` directive is just `masonex:replace` with file-wide scope.

```dart
@pragma('masonex:header', {
  'ClassName':  '{{className.pascalCase()}}',
  'methodName': '{{methodName.camelCase()}}',
})
library;

class ClassName {
  void methodName() {}
}
```

→

```mustache
class {{className.pascalCase()}} {
  void {{methodName.camelCase()}}() {}
}
```

Local scope on a single declaration:

```dart
@pragma('masonex:replace', {
  'final':   '{{modifier}}',
  'int':     '{{type}}',
  'varName': '{{name}}',
})
final int varName;
```

→

```mustache
{{modifier}} {{type}} {{name}};
```

Why pragmas:

- **Token-level**, not just identifier-level. Replaces keywords
  (`final`, `late`, `static`, `const`), types (`int`, `String`,
  `Future<X>`) and identifiers under one mechanism.
- **Scope** is whatever declaration the annotation attaches to:
  `library;` for the whole file, a class for that class, a method
  for that method, a field for that field. No special "header" rule.
- **Native Dart syntax**. `pragma` is part of `dart:core`, no import
  needed, the analyzer accepts it. Custom pragma names are the
  standard way third-party tools tag source for processing
  (`@pragma('vm:entry-point')`, `@pragma('dart2js:tryInline')`).
- **Refactor-safe**. The Map literal participates in normal Dart
  syntax: rename refactor on `varName` updates BOTH the field and
  the Map key (if you wired the map key as the new name).
- **Multiple pragmas allowed** on the same declaration; their maps
  merge (later entries win on collision).

Pragma options grammar:

```text
@pragma('masonex:replace', <Map<Object, String>>)
@pragma('masonex:header',  <Map<Object, String>>)
```

The Map MUST be a const Map literal. Each key may be either:

- An **identifier** (unquoted) referring to a class, type alias,
  top-level function, or built-in `dart:core` type. Dart treats it
  as a `Type` literal (or a `Function` reference) — both const-eligible
  and forward-reference-friendly. Use this for class names like
  `BlocXState`, `BlocXEvent`, or built-ins like `String`, `int`.
- A **string literal** (`'final'`, `'methodName'`). Use this for
  Dart keywords (which can't be unquoted) and for instance-member
  names that don't have a top-level homonym.

Mixed-key maps are fine — `Map<Object, String>` covers both since
`Type` and `String` both extend `Object`. Values MUST be string
literals containing a Mustache tag (i.e., matching `^{{.+}}$` or
`^{{{.+}}}$`).

The pragma annotations themselves are **deleted** from the output
along with their `library;` directive (when the only thing left is
the directive).

### 3.2. Inline section / inverse / partial / comment / unescape

For each block comment whose interior is a Mustache tag and whose tag
starts with a sigil (`#`, `^`, `/`, `>`, `!`, `&`) or is triple-mustache
`{{{…}}}`: **passthrough** — delete the `/*` and `*/` delimiters, keep
the tag.

```dart
/*{{#fields}}*/      →   {{#fields}}
/*{{/fields}}*/      →   {{/fields}}
/*{{^empty}}*/       →   {{^empty}}
```

### 3.3. Inline substitution

For each block comment whose interior is a Mustache tag with NO sigil
(plain variable / dotted path / filter pipeline), masonex **consumes
the next adjacent token** — a single identifier (`Foo`, `field`), a
number literal (`42`), or a string literal (`'placeholder'`) — and
replaces both the comment AND the token with the tag.

> **Limitation.** Inline form can only substitute at *whole-token*
> positions. Mid-identifier substitutions like `Bloc{{name}}State`
> are NOT expressible inline — Dart's grammar doesn't allow a
> comment-separated identifier to be treated as one
> (`class Bloc/*{{x}}*/State` parses as two adjacent identifiers, a
> syntax error). For that case, use the **pragma form** (see §3.1
> and the worked example in §4.7).

```dart
class /*{{className}}*/ Foo {     →   class {{className}} {
final /*{{type}}*/ String x;       →   final {{type}} x;
const /*{{n}}*/ 42;                →   const {{n}};
```

If no eligible token follows (next char is punctuation, end of line, or
end of file), the comment falls back to passthrough:

```dart
foo(/*{{argName}}*/, ...);   →   foo({{argName}}, ...);
class /*{{name}}*/ {         →   class {{name}} {
```

### 3.4. Order matters

Rules apply in order: pragma rewrites first (token-level rewrite
within each annotation's scope), then inline-section, then
inline-substitution. The pragma pass runs **before** the inline rules
because an author may declare a placeholder via `@pragma` and then
use the inline `/*{{…}}*/` form elsewhere with the same tag — both
produce identical Mustache output.

### 3.5. Implementation: `package:analyzer`, not regex

The implementation uses `package:analyzer` (already a transitive dep
of masonex) to tokenize and parse the source. **Not** raw regex.
Reasons:

1. **String literals are safe.** A regex rewriter would clobber
   `'final int x'` if a pragma map keyed `'final'`. The analyzer
   gives us a token stream where `STRING` tokens are distinct; the
   rewrite walk explicitly skips them.
2. **Comments inside strings stay literal.** `'/* {{x}} */'` is NOT a
   comment — it's a string. The analyzer's lexer knows; a regex would
   guess.
3. **Token-consume is exact.** "Consume the next adjacent token" is
   well-defined as "the next token in the analyzer's token stream
   that isn't whitespace or a comment". No ambiguity about identifier
   shapes, escape sequences, or fancy literals.
4. **Pragma scope is precise.** `@pragma('masonex:replace', ...)`
   on a `FieldDeclaration` scopes its rewrites to that field's source
   range — known exactly via `node.offset`/`node.end`. No regex can
   approximate "the next declaration" reliably.
5. **Diagnostics with offsets.** When a pragma map references a token
   that doesn't appear in scope, or an inline marker is malformed,
   we can point at `(line, column)` directly via `Token.offset` /
   `LineInfo`.
6. **Dartdoc-aware.** `///` and `/** */` doc comments are recognized
   distinctly. Inline placeholders inside dartdoc are honored;
   placeholders inside ordinary block comments still work the same.

For **non-Dart files** under `__brick__/` (markdown, yaml, json, sh,
…), masonex falls back to a small regex-based implementation since
the analyzer doesn't apply. That fallback handles only the inline
form `/*{{…}}*/` (where the language uses `/* */` comments) or its
language-specific variants (`{{!-- ... --}}` for Mustache HTML, `#`
for shell — left as a v3.x detail).

## 4. Worked examples

### 4.1. Inline only — simple class

```dart
class /*{{className.pascalCase()}}*/ Foo {
  void /*{{methodName.camelCase()}}*/ doStuff() {}
}
```

→

```mustache
class {{className.pascalCase()}} {
  void {{methodName.camelCase()}}() {}
}
```

### 4.1b. Pragma form — same class, declarative

```dart
@pragma('masonex:header', {
  ClassName:    '{{className.pascalCase()}}',  // unquoted Type literal
  'methodName': '{{methodName.camelCase()}}',  // quoted; method, not Type
})
library;

class ClassName {
  void methodName() {}
}
```

→

```mustache
class {{className.pascalCase()}} {
  void {{methodName.camelCase()}}() {}
}
```

Same output as 4.1, different authoring style. The pragma form pays
off when a placeholder is referenced many times (so you don't repeat
the tag); the inline form is great for one-offs and for placing a tag
right where it appears.

### 4.1c. Mixed — pragma for repeated identifiers, inline for sections

```dart
@pragma('masonex:header', {
  ClassName: '{{className.pascalCase()}}',
})
library;

class ClassName {
  /*{{#methods}}*/
  void /*{{name.camelCase()}}*/ method() {}
  /*{{/methods}}*/
}
```

→

```mustache
class {{className.pascalCase()}} {
  {{#methods}}
  void {{name.camelCase()}}() {}
  {{/methods}}
}
```

Pragma takes care of `ClassName` (used once but could be used many
times); inline takes care of the section delimiters and the per-item
substitution `name.camelCase()`.

### 4.1d. Pragma form — keyword and type substitution

A pragma attached to a single declaration scopes its rewrites to that
declaration's source range. The token-aware match handles keywords,
types, and identifiers uniformly. Use unquoted keys when the token
is a Type, quoted keys for keywords or instance-member names:

```dart
class Stats {
  @pragma('masonex:replace', {
    int:          '{{type.pascalCase()}}',     // Type literal, unquoted
    'final':      '{{modifier}}',               // keyword, must be quoted
    'varName':    '{{name.camelCase()}}',       // instance member, quoted
  })
  final int varName;
}
```

→

```mustache
class Stats {
  {{modifier}} {{type.pascalCase()}} {{name.camelCase()}};
}
```

Note: each token is replaced independently — `final`, `int`, and
`varName` are three separate token rewrites within the field
declaration's range. References to `final`, `int`, or `varName` outside
this declaration are untouched.

### 4.2. Iteration with object items

```dart
class /*{{className.pascalCase()}}*/ User {
  /*{{#fields}}*/
  /// /*{{description}}*/ Placeholder description.
  final /*{{type.pascalCase()}}*/ String /*{{name.camelCase()}}*/ field;
  /*{{/fields}}*/
}
```

→

```mustache
class {{className.pascalCase()}} {
  {{#fields}}
  /// {{description}} Placeholder description.
  final {{type.pascalCase()}} {{name.camelCase()}};
  {{/fields}}
}
```

(Note: dartdoc `///` lines are valid Dart; the inline
`/*{{description}}*/` is a block comment that consumes the next
token — here `Placeholder` — and emits the tag.)

### 4.3. Iteration over a list of strings using `{{.}}`

The user's canonical example:

```dart
class Stats {
  /*{{#estadisticos}}*/
  final String /*{{.}}*/ name;
  /*{{/estadisticos}}*/
}
```

→

```mustache
class Stats {
  {{#estadisticos}}
  final String {{.}};
  {{/estadisticos}}
}
```

For `estadisticos = ['poblacion', 'superficie']`:

```dart
class Stats {
  final String poblacion;
  final String superficie;
}
```

### 4.4. Conditional method

```dart
class Repo {
  /*{{#ormEnabled}}*/
  Future<void> save() => DB.write(this);
  /*{{/ormEnabled}}*/

  /*{{^ormEnabled}}*/
  void save() => throw UnimplementedError();
  /*{{/ormEnabled}}*/
}
```

→

```mustache
class Repo {
  {{#ormEnabled}}
  Future<void> save() => DB.write(this);
  {{/ormEnabled}}

  {{^ormEnabled}}
  void save() => throw UnimplementedError();
  {{/ormEnabled}}
}
```

### 4.5. Coexistence with `| ai`

AI tags live inside string literals (already valid Dart, no comment
needed):

```dart
class /*{{className.pascalCase()}}*/ Foo {
  static const description =
      '{{ "describe {{className.pascalCase()}}" | ai(expect: line) }}';
}
```

→

```mustache
class {{className.pascalCase()}} {
  static const description =
      '{{ "describe {{className.pascalCase()}}" | ai(expect: line) }}';
}
```

The render path runs as today: pre-process placeholder mode (just
strips comments) → AI pre-resolution → mustachex.

### 4.7. Substitution embedded in an identifier (pragma-only)

Common bloc / cubit / repository pattern: the variable is wedged
between fixed prefix and suffix text inside a single identifier.

```dart
@pragma('masonex:header', {
  BlocXState:   'Bloc{{name.pascalCase()}}State',
  BlocXLoading: 'Bloc{{name.pascalCase()}}Loading',
  BlocXLoaded:  'Bloc{{name.pascalCase()}}Loaded',
  BlocXEvent:   'Bloc{{name.pascalCase()}}Event',
  BlocX:        'Bloc{{name.pascalCase()}}Bloc',
})
library;

abstract class BlocXState {}

class BlocXLoading extends BlocXState {}
class BlocXLoaded extends BlocXState {}

abstract class BlocXEvent {}

class BlocX extends Bloc<BlocXEvent, BlocXState> {
  BlocX() : super(BlocXLoading());
}
```

→

```mustache
abstract class Bloc{{name.pascalCase()}}State {}

class Bloc{{name.pascalCase()}}Loading extends Bloc{{name.pascalCase()}}State {}
class Bloc{{name.pascalCase()}}Loaded extends Bloc{{name.pascalCase()}}State {}

abstract class Bloc{{name.pascalCase()}}Event {}

class Bloc{{name.pascalCase()}}Bloc
    extends Bloc<Bloc{{name.pascalCase()}}Event, Bloc{{name.pascalCase()}}State> {
  Bloc{{name.pascalCase()}}Bloc() : super(Bloc{{name.pascalCase()}}Loading());
}
```

Why this works:

- `BlocXState`, `BlocXEvent`, `BlocX` are **valid Dart identifiers**.
  The analyzer parses the file fine, autocomplete suggests them,
  refactor → rename works on them.
- The pragma map maps each placeholder identifier to its Mustache
  expansion. The tag value can be any text — including text that
  contains Mustache tags.
- Token-level rewrite (analyzer-aware): every IDENTIFIER token whose
  lexeme matches a key gets replaced. References inside string
  literals and comments are not tokenized as identifiers, so they're
  left alone.

Tip: pick a distinctive, unique stand-in like `X` so the placeholder
identifiers stand out at a glance and `placeholder check` can report
unused declarations.

### 4.6. Filter pipelines on substitutions

```dart
class /*{{name | uppercase}}*/ FOO {
  static const id =
      /*{{name | snakeCase}}*/ 'placeholder';
}
```

→

```mustache
class {{name | uppercase}} {
  static const id =
      {{name | snakeCase}};
}
```

The pre-processor doesn't care what's inside the tag — it just unwraps
the comment. Pipeline parsing happens later in mustachex.

## 5. What is NOT a placeholder

The pre-processor recognises only:

1. **`@pragma` annotations** with names `'masonex:header'` or
   `'masonex:replace'` whose options is a `Map<String, String>` of
   `'token' -> '{{tag}}'` entries.
2. **Inline placeholder comments**: block comments whose trimmed
   content is `{{...}}` or `{{{...}}}`.

Everything else is untouched:

- `/* TODO: rename this */` — ordinary comment, untouched.
- `/* {{ this is not a tag }} */` — untouched (the inner content is
  not a single Mustache tag).
- `// {{name}}` — line comment, untouched. Use block comments for
  inline placeholders. (Rationale: `//` requires its own line, which
  makes token-adjacency rewrites awkward; `/* */` lives inline.)
- `@pragma('vm:entry-point')` and other non-`masonex:` pragmas — left
  alone. The pre-processor matches only the `masonex:` namespace.
- A `Map<String, String>` literal that happens to look like a
  substitution map but is NOT inside a `masonex:` pragma — left alone.

## 6. Implementation walkthrough (analyzer-based)

```dart
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/analysis/utilities.dart' as parsing;
```

Three passes, each producing edits as `(offset, length, replacement)`
tuples that get applied bottom-up at the end so offsets stay stable.

### 6.1. Pass 1: pragma rewrites

```dart
final result = parsing.parseString(content: source, throwIfDiagnostics: false);
final unit = result.unit;

// Walk every Annotation node; collect those whose name is `pragma`
// and whose first arg is the literal 'masonex:header' or
// 'masonex:replace'.
unit.accept(_PragmaCollector(rewrites, edits));
```

`_PragmaCollector` is a `RecursiveAstVisitor<void>`. For each
`Annotation` node it inspects:

1. The annotation name must resolve to `pragma` (i.e., the
   `dart:core` `pragma` class — `name.name == 'pragma'`).
2. The first positional arg must be a `StringLiteral` whose value
   starts with `'masonex:'` (`'masonex:header'` or `'masonex:replace'`).
3. The second positional arg must be a `SetOrMapLiteral` typed as
   a `Map`. Each `MapLiteralEntry`'s key may be a `StringLiteral`
   (quoted form) OR a `SimpleIdentifier` / `PrefixedIdentifier`
   referring to a type or top-level function (unquoted form). Each
   entry's value must be a `StringLiteral` whose content matches a
   Mustache tag shape.

The pre-processor extracts each key's textual token by inspecting
the AST node:

```dart
String _keyTokenName(Expression key) {
  if (key is SimpleStringLiteral) return key.value;
  if (key is SimpleIdentifier)    return key.name;
  if (key is PrefixedIdentifier)  return key.name.name;
  throw _badKeyError(key);
}
```

So `BlocXState` (Type literal) and `'BlocXState'` (string) are
treated identically — both produce the lookup key `'BlocXState'`
for the rewrite walk.

If all three hold, the rewrite is staged with a scope:

- `'masonex:header'` on a `LibraryDirective` → scope = entire
  `CompilationUnit`.
- `'masonex:replace'` anywhere else → scope = the parent declaration's
  source range (`AnnotatedNode.firstTokenAfterCommentAndMetadata` to
  `node.endToken.end`).

Then for each (scope, map), walk the tokens within the scope:

```dart
for (var t = scope.firstToken; t != scope.endToken.next; t = t.next!) {
  if (t.type == TokenType.STRING) continue; // skip string contents
  final tag = map[t.lexeme];
  if (tag != null) {
    edits.add(Edit.replace(t.offset, t.length, tag));
  }
}
```

Token-level match (not AST). That's what enables substituting
keywords (`final` → `KEYWORD` token) alongside identifiers and types
under the same mechanism. String tokens are explicitly skipped so a
key like `'final'` won't replace text inside `'just say final'`.

Finally, the pragma annotation itself is deleted. If the only purpose
of the surrounding `library;` directive was to host
`@pragma('masonex:header', ...)`, the directive is also stripped.

### 6.2. Pass 2 + 3: inline placeholders

Walk the token stream:

```dart
for (var t = unit.beginToken; t != unit.endToken; t = t.next!) {
  final c = t.precedingComments;
  for (var cc = c; cc != null; cc = cc.next) {
    if (cc is! CommentToken || cc.type != TokenType.MULTI_LINE_COMMENT) {
      continue;
    }
    final tag = _matchPlaceholderComment(cc.lexeme);
    if (tag == null) continue; // not a /*{{…}}*/ comment

    if (_hasSigil(tag)) {
      edits.add(Edit.replace(cc.offset, cc.length, tag));
    } else {
      // Substitution: also consume the next non-whitespace, non-comment
      // token if it's an Identifier or literal.
      final consume = _adjacentTokenAfter(cc);
      if (consume != null) {
        edits.add(Edit.replace(
          cc.offset,
          (consume.offset + consume.length) - cc.offset,
          tag,
        ));
      } else {
        edits.add(Edit.replace(cc.offset, cc.length, tag));
      }
    }
  }
}
```

`_adjacentTokenAfter` returns the next `Token` whose type is
`IDENTIFIER`, `INT`, `DOUBLE`, or `STRING` — and only if it sits
immediately after the comment with whitespace-only separation. If the
next token is punctuation (`(`, `)`, `;`, `,`, `{`, `}`, etc.), it's
not a stand-in and the comment becomes passthrough.

### 6.3. Apply edits

Sort edits by offset descending and apply to the source string. The
output is a Mustache template ready for the existing v2 pipeline.

### 6.4. Why this is safe

- Strings are tokens of type `STRING` — explicitly skipped during the
  pragma rewrite walk, so a key like `'final'` won't touch text inside
  `'…final…'`.
- Comments inside strings aren't tokens — they're string content.
- Inline `/*{{…}}*/` comment detection walks `MultiLineComment`
  tokens, not raw source. A `'/* {{x}} */'` string literal is NOT
  matched.
- Pragma scope is bounded by the annotated declaration's source
  range. A `@pragma('masonex:replace', {'final': '…'})` on field
  `Foo` won't affect a `final` keyword on the next field.
- Multiple pragmas on the same declaration merge their maps; later
  entries win on collision (documented behavior, easy to test).

### 6.5. Non-Dart fallback

For `.md`, `.yaml`, `.json`, `.sh` files etc., masonex falls back to a
regex-based pass that recognizes only the inline form (and only
`/* */` style comments where the language supports them). The pragma
form is **Dart-only** in v3.0; other languages can opt in later by
declaring their comment delimiters and a sidecar substitution file in
`brick.yaml`.

## 7. Round-trip and authoring affordances

- **Format on save** keeps working — `dart format` only re-spaces;
  the comments survive.
- **Refactor → rename** on the dummy identifier (`Foo` → `Bar`)
  doesn't affect the Mustache tag. The brick author can rename the
  stand-in to whatever feels natural without breaking templating.
- **Run a brick file as a Dart script**: dummy values produce a real
  but uninteresting class. Useful as a smoke test.
- **Templates inside dartdoc** (`/// {{x}}`) — line comments aren't
  affected by §6's regex, so they pass through to mustachex (which
  treats `///` as ordinary text and substitutes `{{x}}`).

## 8. CLI surface

|Subcommand|Purpose|
|---|---|
|`masonex placeholder render <file>`|Print the Mustache source the pre-processor would emit. Useful for debugging brick authoring.|
|`masonex placeholder check <brick>`|CI: scan every file under `__brick__/`, ensure every `/*{{...}}*/` parses as a valid Mustache tag, and that section openers / closers balance.|

That's the whole new CLI. No `analyze`, no `convert` — the
implementation is so small that a textual lint suffices.

## 9. VS Code extension (companion)

Out of scope to implement here; sketch:

- **Decorations**: highlight `/*{{...}}*/` placeholders with a subtle
  background and a tooltip showing the tag. The dummy identifier
  immediately after gets a "stand-in" badge.
- **Folding**: hide `/*{{...}}*/` to reduce visual noise.
- **Live preview**: side pane shows the Mustache template (output of
  `placeholder render`).
- **Diagnostics**: red squiggle on unbalanced sections, malformed
  Mustache tags inside placeholder comments, or tags whose vars don't
  appear in `brick.yaml`.

The extension calls `masonex placeholder render` (or its JSON variant)
and consumes the result. masonex stays the source of truth.

## 10. Migration

- Existing bricks (Mustache tags inline) keep working unchanged —
  the pre-processor is a no-op when no `/*{{...}}*/` comments are
  present.
- A brick can mix files: classic Mustache for tiny templates,
  placeholder mode for substantial Dart files. Decided per-file by
  presence of placeholder comments.

## 11. Risks & mitigations

|Risk|Mitigation|
|---|---|
|`/*{{...}}*/` matched inside a string literal|Not a risk: the analyzer's lexer classifies string content as `STRING`. The inline detection pass walks `MultiLineComment` tokens only.|
|Token-consume rewrites the wrong thing|Rule is strict (single adjacent token of type `IDENTIFIER` / `INT` / `DOUBLE` / `STRING`). Authors who want passthrough simply omit the dummy.|
|A pragma key shadows a real Dart token the author didn't mean to substitute (e.g., `'final': '…'` rewrites every `final` keyword in the scope)|Pragma scope is bounded by the annotated declaration's source range, so blast radius is at most that declaration. The default scope when attached to a `library;` directive IS the whole file — for that case, `placeholder check` warns when a key matches a Dart keyword or a `dart:core` name and recommends a distinct stand-in or narrower scope.|
|Unquoted key references a non-existent type|If you write `BlocXState` unquoted but never declare a class with that name, the analyzer flags it (`undefined_identifier`) at the pragma annotation. That's an authoring error caught at edit time, not at render. Use the quoted form `'BlocXState'` if you genuinely want a string key without a corresponding declaration.|
|String tokens contain a key (e.g., `'final'` inside `'choose final'`)|Not a risk: the rewrite walk explicitly skips `STRING` tokens. Only `IDENTIFIER` / `KEYWORD` / `INT` / `DOUBLE` token lexemes are matched against the map.|
|`package:analyzer` parse failure on syntactically malformed brick|Placeholder mode requires the brick file to be valid Dart by design. If it isn't, the analyzer produces diagnostics and `masonex placeholder render` emits them at `(line, column)` and aborts the render. This is preferable to silent regex damage.|
|Authors confused about when to use which form|Guidance: pragma for placeholders referenced ≥2 times or for keyword/type substitutions; inline for one-offs and for sections / iterations.|

## 12. Phasing

|Phase|Scope|
|---|---|
|P1|Pre-processor (regex + token-consume), `placeholder render` and `placeholder check` subcommands, golden tests.|
|P2|Reference brick `bricks/ai_codegen_example_placeholder/` mirrors the existing one. Both produce identical bytes.|
|P3|VS Code extension MVP (decorations + folding + live preview).|
|P4|Snippet library: VS Code snippets that emit common patterns (`class /*{{…}}*/ Foo { … }`).|

## 13. Backwards compatibility

Strictly additive. masonex 0.4.0 adds the pre-processor as a step that
runs **before** the existing Mustache pipeline. Bricks without
placeholder comments are byte-identical to today.

## 14. References

- v1 RFC: `doc/ai/rfc.md`
- v2 RFC: `doc/ai/v2-rfc.md`
- Mustache spec: <https://mustache.github.io/mustache.5.html>
