// ignore_for_file: public_member_api_docs, lines_longer_than_80_chars

import 'dart:io';

import 'package:masonex/src/ai/ai_filter.dart';
import 'package:masonex/src/ai/cache/cache.dart';
import 'package:masonex/src/ai/cache/trace.dart';
import 'package:masonex/src/ai/compat_filters.dart';
import 'package:masonex/src/ai/envelope/envelope.dart';
import 'package:masonex/src/ai/errors.dart';
import 'package:masonex/src/ai/orchestrator/orchestrator.dart';
import 'package:masonex/src/ai/provider/adapter.dart';
import 'package:masonex/src/ai/provider/builtin/mock.dart';
import 'package:masonex/src/ai/provider/config_yaml.dart';
import 'package:masonex/src/ai/provider/registry.dart';
import 'package:mustachex/mustachex.dart' as mx;
import 'package:path/path.dart' as p;

/// Caller-controlled knobs that survive the boundary between the public
/// `String.render` extension and the AI machinery.
class AiRenderOptions {
  const AiRenderOptions({
    this.disabled = false,
    this.refreshAi = false,
    this.disableCache = false,
    this.concurrency = 4,
    this.refreshGlob,
    this.providerOverride,
    this.relativePath = '',
    this.brickRoot,
    this.useMockProvider = false,
    this.mockMode = MockMode.strict,
    this.brickName = '<inline>',
    this.brickVersion = '0.0.0',
    this.brickDescription,
    this.cacheRootOverride,
    this.tokenBudget,
  });

  /// When true, the rewriter is bypassed entirely and the source is returned
  /// verbatim. Used by `--no-ai`.
  final bool disabled;

  final bool refreshAi;
  final bool disableCache;
  final int concurrency;
  final String? refreshGlob;

  /// Force a specific provider id from `providers.yaml`. When null, the
  /// `default` from the file is used.
  final String? providerOverride;

  /// Path of the source within `__brick__/` (without leading `__brick__/`).
  /// Used in tag IDs and for the envelope's `current_file`.
  final String relativePath;

  /// Filesystem root of the brick (used by the mock provider to find
  /// `brick_test/ai_fixtures.yaml`, and as the anchor for `.masonex/cache/`).
  final String? brickRoot;

  /// When true, ignore providers.yaml and use the mock provider. Used in
  /// integration tests of the brick itself.
  final bool useMockProvider;
  final MockMode mockMode;

  /// Metadata embedded in the envelope's <meta> block.
  final String brickName;
  final String brickVersion;
  final String? brickDescription;

  /// Override `.masonex/cache/ai/` location (otherwise nested under
  /// [brickRoot] or current working directory).
  final String? cacheRootOverride;

  /// Per-tag input token budget (heuristic chars/4). When non-null and
  /// any tag's envelope exceeds the budget, masonex aborts with
  /// [AiContextOverflowError] before invoking the provider.
  final int? tokenBudget;

  /// Returns a copy with the given fields overridden. Used by the
  /// generator to inject per-file metadata (relative path) without
  /// rewriting all the call-site options.
  AiRenderOptions copyWith({
    bool? disabled,
    bool? refreshAi,
    bool? disableCache,
    int? concurrency,
    String? refreshGlob,
    String? providerOverride,
    String? relativePath,
    String? brickRoot,
    bool? useMockProvider,
    MockMode? mockMode,
    String? brickName,
    String? brickVersion,
    String? brickDescription,
    String? cacheRootOverride,
    int? tokenBudget,
  }) {
    return AiRenderOptions(
      disabled: disabled ?? this.disabled,
      refreshAi: refreshAi ?? this.refreshAi,
      disableCache: disableCache ?? this.disableCache,
      concurrency: concurrency ?? this.concurrency,
      refreshGlob: refreshGlob ?? this.refreshGlob,
      providerOverride: providerOverride ?? this.providerOverride,
      relativePath: relativePath ?? this.relativePath,
      brickRoot: brickRoot ?? this.brickRoot,
      useMockProvider: useMockProvider ?? this.useMockProvider,
      mockMode: mockMode ?? this.mockMode,
      brickName: brickName ?? this.brickName,
      brickVersion: brickVersion ?? this.brickVersion,
      brickDescription: brickDescription ?? this.brickDescription,
      cacheRootOverride: cacheRootOverride ?? this.cacheRootOverride,
      tokenBudget: tokenBudget ?? this.tokenBudget,
    );
  }
}

/// The result of running the AI pre-resolution pass.
///
/// In v2 (mustachex 2.0+), the source is no longer rewritten — mustachex
/// natively understands the pipeline syntax. The pre-resolution pass only
/// produces the resolutions map and the filter list to feed into the
/// processor.
class AiRenderResult {
  const AiRenderResult({
    required this.filters,
    required this.deferredResolutions,
  });

  /// Filters to register with [MustachexProcessor] (AI + legacy compat).
  /// Empty when [AiRenderOptions.disabled] is true.
  final List<mx.MustachexFilter> filters;

  /// Resolutions for deferred filter calls, keyed by [mx.DeferredCallId].
  /// Empty when no `| ai` tags were observed.
  final Map<mx.DeferredCallId, String> deferredResolutions;
}

/// Runs the AI pre-resolution pass for a single template source.
///
/// In v2 the pass returns:
///   - the filter list (AiFilter + legacy compat sync filters)
///   - the resolutions map for deferred calls
///
/// Both are then handed to the [mx.MustachexProcessor] / [mx.Template]
/// rendering the brick. The source itself is NOT rewritten.
///
/// Throws [AiAbortedRenderError] (or its cause) if any deferred call
/// could not be resolved. Callers MUST treat that as "render aborted,
/// no files touched".
Future<AiRenderResult> runAiPass(
  String source, {
  required Map<String, dynamic> vars,
  required AiRenderOptions options,
}) async {
  if (options.disabled) {
    return AiRenderResult(
      filters: const [],
      deferredResolutions: const {},
    );
  }

  final compat = buildLegacyCompatFilters();

  // Cheap: build a Template, ask mustachex to scan for deferred calls.
  // The filter doesn't need to be configured yet, since we only inspect
  // structure here.
  final stubFilters = <mx.MustachexFilter>[
    _StubAiFilter(),
    ...compat,
  ];
  final probe = mx.Template(
    source,
    lenient: true,
    filters: stubFilters,
  );
  final calls = probe.collectDeferredCalls(vars);
  if (calls.isEmpty) {
    return AiRenderResult(
      filters: compat,
      deferredResolutions: const {},
    );
  }

  // We have AI work. Build the real provider/cache/orchestrator stack.
  final cacheRoot = options.cacheRootOverride
      ?? p.join(
        options.brickRoot ?? Directory.current.path,
        '.masonex',
        'cache',
        'ai',
      );
  final cache = AiCache(cacheRoot);
  final trace = AiTrace(cacheRoot);
  final provider = await _selectProvider(options);

  final brickContext = BrickContext(
    brickName: options.brickName,
    brickVersion: options.brickVersion,
    brickDescription: options.brickDescription,
    userVars: Map<String, dynamic>.from(vars),
    providerName: provider.descriptor.id,
    providerModel: null,
    brickFiles: const [],
  );

  final aiFilter = AiFilter(
    provider: provider,
    cache: cache,
    trace: trace,
    brickContext: brickContext,
    options: OrchestratorOptions(
      concurrency: options.concurrency,
      refreshAi: options.refreshAi,
      disableCache: options.disableCache,
      refreshGlob: options.refreshGlob,
      tokenBudget: options.tokenBudget,
    ),
  );

  final resolutions = await aiFilter.fulfill(calls);

  return AiRenderResult(
    filters: <mx.MustachexFilter>[aiFilter, ...compat],
    deferredResolutions: resolutions,
  );
}

/// Stub AI filter used only during the probe pass: marks `ai` as a known
/// deferred filter so [mx.Template.collectDeferredCalls] can be invoked
/// without setting up the real provider stack. It is never called.
class _StubAiFilter extends mx.MustachexFilter {
  _StubAiFilter();
  @override
  String get name => 'ai';
  @override
  bool get deferred => true;
}

Future<AiProviderAdapter> _selectProvider(AiRenderOptions options) async {
  if (options.useMockProvider) {
    final root = options.brickRoot
        ?? (throw const AiException(
          'useMockProvider=true requires brickRoot to be set.',
        ));
    return MockAiProvider(brickRoot: root, mode: options.mockMode);
  }
  final config = await ProvidersYaml.load();
  if (config == null) {
    throw AiProviderUnavailableError(
      '<none>',
      '~/.masonex/providers.yaml',
    );
  }
  final id = options.providerOverride ?? config.defaultProvider;
  final entry = config.providers[id];
  if (entry == null) {
    throw AiException(
      'Provider "$id" is not defined in ${ProvidersYaml.defaultPath()}.',
    );
  }
  return buildAdapter(entry);
}
