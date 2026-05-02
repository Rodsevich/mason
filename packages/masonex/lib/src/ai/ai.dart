// ignore_for_file: public_member_api_docs

/// Public surface of the masonex AI subsystem.
///
/// Bricks and integrators interact with this barrel; internals live under
/// `lib/src/ai/`.
library masonex.ai;

export 'cache/cache.dart' show AiCache, CachePolicy, parseCachePolicy;
export 'cache/keys.dart' show computeCacheKey;
export 'cache/trace.dart' show AiTrace;
export 'envelope/envelope.dart'
    show
        BrickContext,
        BrickFileEntry,
        Envelope,
        PreviousAttempt,
        PreviousResolution,
        TagEnvelopeExtras;
export 'envelope/envelope_builder.dart' show EnvelopeBuilder;
export 'envelope/envelope_serializer.dart' show EnvelopeSerializer;
export 'envelope/inline_detector.dart' show InlineDetector;
export 'envelope/privacy.dart'
    show PrivacyMatcher, defaultPrivacyExcludeGlobs;
export 'errors.dart';
export 'filter_registry/builtin_filters.dart' show buildDefaultFilterRegistry;
export 'filter_registry/filter_registry.dart'
    show FilterRegistry, SyncFilterFn;
export 'orchestrator/orchestrator.dart'
    show
        AiOrchestrator,
        CurrentFileSourceLookup,
        OrchestratorOptions,
        ResolutionResult;
export 'pipeline/ai_tag_request.dart' show AiTagRequest;
export 'pipeline/parser.dart' show PipelineParser;
export 'pipeline/pipeline_node.dart';
export 'pipeline/rewriter.dart' show AiTagRewriter, RewriteResult;
export 'pipeline/tag_finder.dart' show FoundTag, TagFinder;
export 'provider/adapter.dart' show AiProviderAdapter;
export 'provider/builtin/claude.dart' show ClaudeProviderAdapter;
export 'provider/builtin/custom.dart' show CustomProviderAdapter;
export 'provider/builtin/mock.dart' show MockAiProvider, MockMode;
export 'provider/config_yaml.dart'
    show PassMode, ProviderConfig, ProvidersYaml;
export 'provider/descriptor.dart' show AiProviderDescriptor;
export 'provider/invocation.dart' show AiInvocation, AiInvocationResult;
export 'provider/registry.dart' show buildAdapter, builtinProviderDescriptors;
export 'system_prompt.dart' show aiErrorSentinel, aiSystemPrompt;
export 'validation/expect.dart' show expectedShapeFor;
export 'validation/post_processors.dart'
    show applyCase, collapseWhitespace, stripFences;
export 'validation/validators.dart' show ValidationResult, validateAiOutput;
