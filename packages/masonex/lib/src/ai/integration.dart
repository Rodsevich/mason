// ignore_for_file: public_member_api_docs, lines_longer_than_80_chars

import 'dart:io';

import 'package:masonex/src/ai/cache/cache.dart';
import 'package:masonex/src/ai/cache/trace.dart';
import 'package:masonex/src/ai/envelope/envelope.dart';
import 'package:masonex/src/ai/errors.dart';
import 'package:masonex/src/ai/orchestrator/orchestrator.dart';
import 'package:masonex/src/ai/pipeline/rewriter.dart';
import 'package:masonex/src/ai/provider/adapter.dart';
import 'package:masonex/src/ai/provider/builtin/mock.dart';
import 'package:masonex/src/ai/provider/config_yaml.dart';
import 'package:masonex/src/ai/provider/registry.dart';
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
    );
  }
}

/// The result of running a two-pass AI render.
class AiRenderResult {
  const AiRenderResult({
    required this.source,
    required this.injectedVars,
    required this.resolutions,
  });

  /// Rewritten template source: AI tags replaced by `{{{__masonex_ai_<n>}}}`.
  final String source;

  /// Map of synthetic variable name -> resolved value, ready to be merged
  /// into the user's `vars` map for the regular Mustache render.
  final Map<String, String> injectedVars;

  /// All resolutions, in the order they completed. Available for traces /
  /// audit output.
  final List<ResolutionResult> resolutions;
}

/// Runs the AI pre-resolution pass for a single template source.
///
/// Returns:
///   - the rewritten source (with synthetic vars in place of `| ai` tags)
///   - the synthetic var values, ready to be merged into the Mustache vars
///
/// Throws [AiAbortedRenderError] (or its cause) if any tag could not be
/// resolved. Callers MUST treat that as "render aborted, no files touched".
Future<AiRenderResult> runAiPass(
  String source, {
  required Map<String, dynamic> vars,
  required AiRenderOptions options,
}) async {
  if (options.disabled) {
    return AiRenderResult(
      source: source,
      injectedVars: const {},
      resolutions: const [],
    );
  }

  final rewriter = AiTagRewriter(
    relativePath: options.relativePath,
    varsForPrompt: vars,
  );
  final rewrite = rewriter.rewrite(source);
  if (rewrite.requests.isEmpty) {
    return AiRenderResult(
      source: rewrite.rewrittenSource,
      injectedVars: const {},
      resolutions: const [],
    );
  }

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

  final orchestrator = AiOrchestrator(
    provider: provider,
    cache: cache,
    trace: trace,
    brickContext: brickContext,
    currentFileSource: (_) => source,
    options: OrchestratorOptions(
      concurrency: options.concurrency,
      refreshAi: options.refreshAi,
      disableCache: options.disableCache,
      refreshGlob: options.refreshGlob,
    ),
  );

  final results = await orchestrator.resolveAll(rewrite.requests);
  final injected = <String, String>{
    for (final r in results)
      r.request.syntheticVarName: r.value,
  };

  return AiRenderResult(
    source: rewrite.rewrittenSource,
    injectedVars: injected,
    resolutions: results,
  );
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
