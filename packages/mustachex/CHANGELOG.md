## 2.0.0-dev.1

- **Native filter pipeline.** Tags now support `{{ head | filter(args) | other }}`
  and `{{ head.filter(args).other() }}`, equivalent at the AST level.
  - New AST node: `FilterPipelineNode`. Backward compatible — tags without
    pipeline operators continue to parse as `VariableNode`.
  - New public types: `MustachexFilter`, `FilterArgs`, `FilterContext`,
    `DeferredCall`, `DeferredCallId`, `HeadKind`, `FilterCall`,
    `ParsedPipeline`, `PipelineParser`, `PipelineSyntaxException`,
    `MissingDeferredResolutionError`, `UnknownFilterError`, plus the
    `PipelineValue` typed-arg hierarchy (`PvString`, `PvInt`, `PvDouble`,
    `PvBool`, `PvDuration`, `PvIdentifier`, `PvList`, `PvRange`,
    `PvRegex`).
  - `Template` accepts `filters: List<MustachexFilter>`. New methods:
    `Template.collectDeferredCalls(values)` and
    `Template.renderString(values, resolutions: ...)` /
    `Template.renderBytes(values, resolutions: ...)`.
  - `MustachexProcessor` accepts `filters` and `deferredResolutions`.
  - Scanner is now quote-aware inside tag content: literals like
    `{{ "doc para {{name}}" | ai }}` parse correctly even when the inner
    text contains `}}`.
- All 116 existing tests pass byte-identical (full backward compatibility).
- 11 new tests cover the filter pipeline (sync + deferred).

## 1.1.0
- Added `processBytes()` method to `MustachexProcessor` for binary data support
- When a variable's value is `Uint8List` or `List<int>`, raw bytes are written directly without string conversion
- Text portions are UTF-8 encoded, producing a single `List<int>` output
- Existing `process()` method remains unchanged for backward compatibility
- Minimal code order improvement with own exceptions file.

## 1.0.0
- Introduced mustache_template code. All test passing.

## 0.9.9+1
- export LambdaContext

## 0.9.9
- Introduced mustache_template code. Almsot all code is working, will be fully working on next 1.0.0 version after twerking the dependencies with mustache_recase

## 0.1.4
- Added support for emojis

## 0.1.3
- Fixed bug that didn't use mustache_recase package lambdas
- Minor version bump
## 0.1.2
- Fixed a bug when recasing inside hasXxx guards
- Fixed fauty bug
## 0.1.1

- now {"foo": false} will render {{#hasFoo}} as true instead of false
## 0.1.0

- NNBD, packages versions upgrades and all tests passings

## 0.0.1

- Initial version
