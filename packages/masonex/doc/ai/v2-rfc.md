# RFC v2: Native filter registry in mustachex

| Field         | Value                                                  |
|---------------|--------------------------------------------------------|
| Status        | Draft                                                  |
| Version       | 0.1.0                                                  |
| Targets       | mustachex 2.0, masonex 0.3.0                           |
| Supersedes    | The pre-processor approach in `rfc.md` (v1)            |
| Last edited   | 2026-05-02                                             |

## 1. Motivation

In v1, masonex implements the `| ai` filter as a **pre-processor**: it
scans the template source, parses pipeline syntax in masonex code, rewrites
each AI tag into a synthetic mustache variable, and only then hands a clean
mustache source to mustachex.

That works, but it places filter parsing in the wrong package:

- mustachex stays unable to express `{{ x | filter(args) }}` for any other
  consumer that might want it.
- masonex's `_transpileMasonSyntax` and `AiTagRewriter` together duplicate a
  good chunk of mustachex's tokenizer/parser concerns.
- Bricks that combine sync filters (`uppercase`) and deferred filters
  (`ai`) bounce through two different code paths.

v2 puts the filter pipeline where it belongs — inside mustachex — and
exposes a registration API. masonex (and any future consumer) implements
filters by writing a `MustachexFilter`. The `| ai` feature becomes one
such registration.

## 2. Goals

- mustachex understands `{{ head ( | filter(args) | ... )* }}` and
  `{{ head ( .filter(args) )* }}` natively, with shared semantics.
- A public, stable extension point for **synchronous** and **deferred**
  filters.
- Atomicity preserved: deferred filters are resolved in a separate pass
  before any rendering bytes are produced. If any deferred call fails,
  rendering aborts cleanly.
- Backward compatibility: every brick that compiles against mustachex 1.x
  + masonex 0.2.x continues to render byte-identical output.
- masonex's `lib/src/ai/pipeline/{parser,tag_finder,rewriter}.dart` are
  retired in favour of mustachex's parser; the orchestrator and provider
  layer are kept (their concerns are still masonex's).

## 3. Non-goals (v2.0)

- Replacing `package:mustache_recase` shorthand (`{{var.snakeCase}}`).
  That keeps working untouched as a legacy path.
- Making `Template.renderString` async. The "deferred" model handles
  asynchrony out-of-band so the render hot path stays sync.
- Plugin discovery (loading filter packages by name). Registration is
  imperative: the consumer constructs the `MustachexProcessor` with the
  filter list it wants.

## 4. New mustachex API

### 4.1. `MustachexFilter`

```dart
abstract class MustachexFilter {
  String get name;

  /// When true, mustachex collects calls to this filter during a separate
  /// pass and asks the implementation to fulfill them in bulk before any
  /// rendering bytes are produced. When false, the filter runs inline.
  bool get deferred => false;

  /// Inline path. Receives the head value (already resolved: literal or
  /// variable lookup, with previous filters applied) and returns the
  /// transformed value. Must be pure and synchronous.
  String renderSync(String input, FilterArgs args, FilterContext ctx) => input;

  /// Deferred path. Mustachex passes every observed call in one batch so
  /// the filter can run them with its own concurrency / cache / retry
  /// policy. Implementations should return one entry per call id.
  Future<Map<DeferredCallId, String>> fulfill(
    List<DeferredCall> calls,
  ) async => const {};
}
```

### 4.2. Supporting types

```dart
class FilterArgs {
  const FilterArgs({this.positional = const [], this.named = const {}});
  final List<Object?> positional;
  final Map<String, Object?> named;
}

class FilterContext {
  const FilterContext({
    required this.vars,
    required this.line,
    required this.column,
    required this.inline,
    this.currentFilePath,
    this.surroundingBefore = '',
    this.surroundingAfter = '',
  });
  final Map<String, Object?> vars;
  final int line;
  final int column;
  final bool inline;
  final String? currentFilePath;
  final String surroundingBefore;
  final String surroundingAfter;
}

class DeferredCallId {
  const DeferredCallId(this.value);
  final String value;
}

class DeferredCall {
  const DeferredCall({
    required this.id,
    required this.filterName,
    required this.headValue,
    required this.headKind,   // literal | variable
    required this.args,
    required this.context,
    required this.postFilters, // names of sync filters chained AFTER
  });
  // ...
}

enum HeadKind { literal, variable }

class MustachexFilterException extends MustachexException {
  MustachexFilterException(this.filterName, super.message);
  final String filterName;
}
```

### 4.3. Template / Processor surface

```dart
class MustachexProcessor {
  MustachexProcessor({
    Map? initialVariables,
    PartialResolverFunction? partialsResolver,
    bool lenient = false,
    List<MustachexFilter> filters = const [],   // NEW
  });
}

class Template {
  /// Walks the AST and returns every deferred call observed (in document
  /// order). Pure: no rendering side effects.
  List<DeferredCall> collectDeferredCalls(Map<String, Object?> vars);

  /// Renders the template. If any deferred filter call appears in the AST
  /// and is not present in [resolutions], throws
  /// [MissingDeferredResolutionError].
  String renderString(
    Map<String, Object?> vars, {
    Map<DeferredCallId, String> resolutions = const {},
  });

  /// Same, raw bytes (binary-safe path keeps working).
  List<int> renderBytes(
    Map<String, Object?> vars, {
    Map<DeferredCallId, String> resolutions = const {},
  });
}
```

## 5. Pipeline grammar (no changes from v1)

```
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

The parser already exists in masonex (`lib/src/ai/pipeline/parser.dart`);
v2 moves it into mustachex unchanged.

## 6. Render flow

```
Template(source, filters: [...])
   │
   ▼
Scanner+Parser → AST including FilterPipelineNode
   │
   ├─ collectDeferredCalls(vars)
   │     │
   │     └─ visitor walks AST, for each FilterPipelineNode whose
   │        chain contains a deferred filter, builds a DeferredCall
   │
   ├─ caller invokes filter.fulfill(calls) and merges resolutions
   │
   └─ renderString(vars, resolutions:)
         │
         ├─ Mustache nodes render as today
         └─ FilterPipelineNode renders by:
              1. resolving head (literal | variable lookup)
              2. for each filter in chain:
                   - sync   → invoke filter.renderSync(value, args, ctx)
                   - deferred → resolutions[call.id] (must be present)
              3. emit final value
```

## 7. Equivalence to v1

| v1 component (masonex)            | v2 home              |
|-----------------------------------|----------------------|
| `lib/src/ai/pipeline/parser.dart` | mustachex Scanner+Parser |
| `lib/src/ai/pipeline/tag_finder.dart` | mustachex Scanner    |
| `lib/src/ai/pipeline/rewriter.dart`   | gone (mustachex AST replaces it) |
| `_transpileMasonSyntax`               | gone (sync filters are first-class) |
| `lib/src/ai/orchestrator/`            | unchanged (still in masonex) |
| `lib/src/ai/provider/`                | unchanged |
| `lib/src/ai/cache/`                   | unchanged |
| `lib/src/ai/envelope/`                | unchanged |
| `lib/src/ai/validation/`              | unchanged |

## 8. Migration plan

### 8.1. PR 1 — mustachex v2.0 (additive)

1. Scanner: tokenize `|`, `.`, `(`, `)`, `,`, `:`, `"`, `'`, `[`, `]`,
   `/` inside tag content. Behind a per-template opt-in flag for the
   first preview release; default ON in 2.0 final.
2. Parser: emit `FilterPipelineNode` when a tag's content matches the
   pipeline grammar; otherwise behave exactly as today.
3. New types: `MustachexFilter`, `FilterArgs`, `FilterContext`,
   `DeferredCall`, `DeferredCallId`, `HeadKind`,
   `MissingDeferredResolutionError`, `MustachexFilterException`.
4. Add `filters:` to `MustachexProcessor`. Add `collectDeferredCalls` and
   the `resolutions:` parameter to `Template.renderString` /
   `renderBytes`.
5. Compatibility tests: every existing test passes byte-identically.
6. Doc + CHANGELOG entry.

### 8.2. PR 2 — masonex 0.3.0

1. Delete `lib/src/ai/pipeline/{parser,tag_finder,rewriter}.dart` and
   `lib/src/ai/pipeline/ai_tag_request.dart` (replaced by mustachex
   equivalents).
2. Implement `AiFilter extends MustachexFilter` (deferred). Its `fulfill`
   simply hands the calls to the existing `AiOrchestrator`.
3. Reimplement `runAiPass` as: build `Template(filters: [AiFilter, ...
   syncFilters])`, call `collectDeferredCalls`, call `AiFilter.fulfill`,
   call `renderString(resolutions: ...)`. Public surface
   (`String.render(... aiOptions: ...)`) stays identical.
4. Remove `_transpileMasonSyntax` once every legacy lambda has been
   ported to a `SyncFilter` registration. Keep a feature flag for one
   release in case bricks-in-the-wild break.
5. Run the existing 41 AI tests + the brick reference suite. All must
   pass byte-identical.

## 9. Risks & mitigations

| Risk | Mitigation |
|---|---|
| Existing bricks that use `{{x | uppercase}}` or `{{x.snakeCase}}` regress. | Keep the legacy paths intact during 0.3.0; flip to filter-native rendering in 0.4.0 after a soak. |
| Scanner extension hurts performance for templates without filters. | Benchmark on the brick repo before merge; allow `Template(enableFilterPipeline: false)` opt-out in 2.0.x. |
| Filters with state get accidentally shared across renders. | Document the lifecycle: filters are bound to the `MustachexProcessor` instance and live as long as it does. The `AiFilter` carries an orchestrator that is itself per-render. |
| Deferred filters that try to enqueue more deferred calls inside `fulfill`. | Forbid by contract; documented; tested with a guard that throws if `fulfill` returns a map containing unknown ids or if it tries to recurse. |
| Public API churn before 2.0 stabilises. | Mark v2 surface as `@experimental` in 2.0-dev releases until masonex 0.3.0 actually exercises it. |

## 10. Open questions (resolve before 2.0 GA)

1. Should sync filters be registerable as raw closures (`String Function`)
   or strictly as `MustachexFilter` instances? Voting: **closures allowed
   via a thin adapter**, to keep registration ergonomic.
2. Argument typing. Voting: **typed `PipelineValue` hierarchy** identical
   to today's. Cleaner for filter authors than `dynamic`.
3. Should `collectDeferredCalls` deduplicate identical calls? Voting:
   **no**, dedup is the filter's responsibility (it already happens via
   the cache key in `AiFilter`).
4. Filter precedence when names collide with the recase shorthand
   (`{{x.snakeCase}}`). Voting: **registered filter wins** if it has the
   exact name and arity matches the call.
5. Should `MustachexFilter.fulfill` receive a `concurrency` hint from the
   caller? Voting: **no**, the filter owns its concurrency policy. The
   caller passes a configured filter instance.
6. Versioning of the wire format between mustachex and the consumer
   (e.g., `DeferredCall` JSON). Voting: **none in 2.0** — types are
   passed in-process; serialization is masonex's job (envelope XML).

## 11. Acceptance criteria

- mustachex 2.0 preview ships with the new API behind a flag, every
  existing test green, plus a fresh test suite covering:
  - filter registry resolution
  - sync filter chaining
  - deferred filter collection
  - `MissingDeferredResolutionError`
  - filter+section interactions
- masonex 0.3.0-dev consumes the preview API, deletes the rewriter, and
  the existing 41 AI tests + the `ai_codegen_example` brick render
  byte-identical to 0.2.0.
- Doc updates: this RFC graduates from Draft to Accepted; v1 RFC adds a
  superseded-by header pointing here.

## 12. Out of scope but tracked

- A `walk(Visitor)` API on `Template` for static-analysis tools (would
  let `audit-ai` live in mustachex too). Defer to v2.1.
- Filter-aware partials (`{{> x | filter}}`). Defer to v2.x.
- Allow filters to register their own sub-grammars (e.g., a JSON schema
  filter that consumes its own DSL). Probably never; keep filters
  declarative.
