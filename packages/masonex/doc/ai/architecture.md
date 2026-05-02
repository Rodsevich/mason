# Architecture

```
                          ┌────────────────────────────────────┐
                          │  String.render(vars, aiOptions:..) │  public API
                          └─────────────┬──────────────────────┘
                                        │
                                        ▼
                       ┌─────────────────────────────────┐
                       │  runAiPass (integration.dart)   │  Pass 1 entry
                       └─────────────┬───────────────────┘
                                     │
        ┌────────────────────────────┼─────────────────────────────┐
        ▼                            ▼                             ▼
┌───────────────┐          ┌──────────────────┐          ┌──────────────────┐
│ AiTagRewriter │──reqs──▶ │  AiOrchestrator  │──hash─▶ │     AiCache      │
│  (rewriter)   │          │  (orchestrator)  │  miss── │ (cache.dart, key)│
└───────┬───────┘          └────────┬─────────┘          └──────────────────┘
        │                            │
        │ rewritten src              ▼
        │                  ┌────────────────────┐
        │                  │ EnvelopeBuilder +  │
        │                  │ EnvelopeSerializer │
        │                  └────────┬───────────┘
        │                            ▼
        │                  ┌────────────────────┐
        │                  │ AiProviderAdapter  │
        │                  │  (claude / mock /  │
        │                  │   custom / ...)    │
        │                  └────────┬───────────┘
        │                            ▼
        │                  ┌────────────────────┐
        │                  │ Validators +       │
        │                  │ Post-processors    │
        │                  └────────┬───────────┘
        ▼                            ▼
┌────────────────────────────────────────────┐
│ Pass 2: existing _transpileMasonSyntax     │
│ + mustachex render with synthetic vars     │
└────────────────────────────────────────────┘
```

## Module map

```
lib/src/ai/
  ai.dart                  # public barrel
  errors.dart              # exception taxonomy
  integration.dart         # Pass 1 entry: runAiPass + AiRenderOptions
  system_prompt.dart       # versioned system prompt + sentinel
  system_prompt.md         # mirrored copy for docs

  pipeline/
    pipeline_node.dart     # AST: FilterPipelineNode, FilterCall, PipelineValue
    parser.dart            # `| ai` syntax parser
    tag_finder.dart        # locates {{...}} tags respecting nested mustache
    rewriter.dart          # rewrites source + emits AiTagRequest list
    ai_tag_request.dart    # data class

  filter_registry/
    filter_registry.dart   # SyncFilterFn registry
    builtin_filters.dart   # uppercase/snakeCase/etc.

  validation/
    expect.dart            # expect: word|line|json|... -> hint
    validators.dart        # match/oneOf/forbid/lines/... checks
    post_processors.dart   # stripFences, applyCase, collapseWhitespace

  envelope/
    envelope.dart          # data classes (BrickContext, ...)
    envelope_builder.dart  # Envelope construction
    envelope_serializer.dart # XML serialization
    inline_detector.dart   # inline-vs-block + surrounding lines
    privacy.dart           # default exclude globs + matcher

  cache/
    cache.dart             # filesystem layout
    keys.dart              # content-addressed key
    trace.dart             # append-only JSONL log

  provider/
    adapter.dart           # AiProviderAdapter interface
    descriptor.dart        # AiProviderDescriptor
    invocation.dart        # AiInvocation / AiInvocationResult
    config_yaml.dart       # ~/.masonex/providers.yaml schema + IO
    registry.dart          # builtinProviderDescriptors + buildAdapter()
    interactive_setup.dart # first-time wizard
    interactive_recovery.dart # edit-and-retry on failure
    builtin/
      cli_runner.dart      # generic CLI runner (stdin/tmpfile/arg)
      claude.dart          # Anthropic Claude CLI adapter
      custom.dart          # generic adapter driven by ProviderConfig
      mock.dart            # test-only fixtures-driven adapter

  orchestrator/
    orchestrator.dart      # Pass-1 driver: cache, retries-with-feedback,
                           # concurrency via package:pool
```

## CLI surface

```
lib/src/cli/commands/
  ai_cache.dart      # stats / clear
  ai_trace.dart      # tail trace.jsonl
  ai_validate.dart   # validate (offline)
  audit_ai.dart      # list all `| ai` tags
  provider.dart      # show / edit / test / reset / setup / set-default
```

All wired into `MasonexCommandRunner` via `command_runner.dart`.
