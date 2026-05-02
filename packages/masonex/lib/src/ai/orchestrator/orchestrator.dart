// ignore_for_file: public_member_api_docs, lines_longer_than_80_chars

import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:masonex/src/ai/cache/cache.dart';
import 'package:masonex/src/ai/cache/keys.dart';
import 'package:masonex/src/ai/cache/trace.dart';
import 'package:masonex/src/ai/envelope/envelope.dart';
import 'package:masonex/src/ai/envelope/envelope_builder.dart';
import 'package:masonex/src/ai/envelope/envelope_serializer.dart';
import 'package:masonex/src/ai/errors.dart';
import 'package:masonex/src/ai/filter_registry/builtin_filters.dart';
import 'package:masonex/src/ai/filter_registry/filter_registry.dart';
import 'package:masonex/src/ai/pipeline/ai_tag_request.dart';
import 'package:masonex/src/ai/pipeline/pipeline_node.dart';
import 'package:masonex/src/ai/provider/adapter.dart';
import 'package:masonex/src/ai/provider/invocation.dart';
import 'package:masonex/src/ai/system_prompt.dart';
import 'package:masonex/src/ai/validation/post_processors.dart';
import 'package:masonex/src/ai/validation/validators.dart';
import 'package:pool/pool.dart';

/// Behaviour knobs for a single orchestrated pre-resolution pass.
class OrchestratorOptions {
  const OrchestratorOptions({
    this.concurrency = 4,
    this.refreshAi = false,
    this.disableCache = false,
    this.refreshGlob,
  });

  final int concurrency;
  final bool refreshAi;
  final bool disableCache;
  final String? refreshGlob;
}

/// Per-tag source provider: the orchestrator uses this to pull the contents
/// of a file in `__brick__/` for envelope construction (`current_file`,
/// `surrounding_text`).
typedef CurrentFileSourceLookup = String Function(String relativePath);

/// Outcome of a single tag's resolution.
class ResolutionResult {
  const ResolutionResult({
    required this.request,
    required this.value,
    required this.fromCache,
    required this.providerId,
    required this.duration,
    required this.retries,
    this.modelReported,
  });

  final AiTagRequest request;
  final String value;
  final bool fromCache;
  final String providerId;
  final String? modelReported;
  final Duration duration;
  final int retries;
}

/// The pre-resolution orchestrator.
///
/// Resolves all [AiTagRequest]s with bounded concurrency, going through the
/// cache before invoking the provider. On any unrecoverable failure it
/// rethrows immediately; callers (the render integration layer) treat that
/// as "render aborted, no files touched".
class AiOrchestrator {
  AiOrchestrator({
    required this.provider,
    required this.cache,
    required this.trace,
    required this.brickContext,
    required this.currentFileSource,
    required this.options,
    String? systemPromptOverride,
    FilterRegistry? filterRegistry,
  })  : systemPrompt = systemPromptOverride ?? aiSystemPrompt,
        filterRegistry = filterRegistry ?? buildDefaultFilterRegistry();

  final AiProviderAdapter provider;
  final AiCache cache;
  final AiTrace trace;
  final BrickContext brickContext;
  final CurrentFileSourceLookup currentFileSource;
  final OrchestratorOptions options;
  final String systemPrompt;
  final FilterRegistry filterRegistry;

  static const _builder = EnvelopeBuilder();
  static const _serializer = EnvelopeSerializer();

  Future<List<ResolutionResult>> resolveAll(
    List<AiTagRequest> requests,
  ) async {
    if (requests.isEmpty) return [];
    await cache.ensureLayout();

    final pool = Pool(options.concurrency);
    final results = <ResolutionResult>[];
    final errors = <Object>[];

    final futures = requests.map((req) {
      return pool.withResource(() async {
        try {
          final r = await _resolveOne(req);
          results.add(r);
        } on AiException catch (e) {
          errors.add(AiAbortedRenderError(e));
        } on Object catch (e) {
          errors.add(e);
        }
      });
    }).toList();

    await Future.wait(futures);
    await pool.close();

    if (errors.isNotEmpty) {
      // ignore: only_throw_errors
      throw errors.first;
    }
    return results;
  }

  Future<ResolutionResult> _resolveOne(AiTagRequest req) async {
    final filter = req.node.filters.firstWhere((f) => f.name == 'ai');
    final retriesArg = (filter.named['retries'] as PvInt?)?.value ?? 2;
    final cachePolicy = parseCachePolicy(
      (filter.named['cache'] as PvIdentifier?)?.value
          ?? (filter.named['cache'] as PvString?)?.value,
    );

    final overrideKey = (filter.named['cache_key'] as PvString?)?.value;

    final source = currentFileSource(req.relativePath);

    PreviousAttempt? previousAttempt;

    final stopwatch = Stopwatch()..start();
    final systemHash =
        sha256.convert(utf8.encode(systemPrompt)).toString().substring(0, 16);

    var attempt = 0;
    while (true) {
      final envelope = _builder.build(
        request: req,
        brickContext: brickContext,
        currentFileSource: source,
        previousAttempt: previousAttempt,
      );
      final envelopeXml = _serializer.serialize(envelope);
      final modelOverride = (filter.named['model'] as PvString?)?.value;
      final temperatureArg = filter.named['temperature'];
      final temperature = temperatureArg is PvDouble
          ? temperatureArg.value
          : temperatureArg is PvInt
              ? temperatureArg.value.toDouble()
              : null;
      final seedArg = (filter.named['seed'] as PvInt?)?.value;

      final cacheKey = overrideKey
          ?? computeCacheKey(
            prompt: req.prompt,
            envelopeXml: envelopeXml,
            systemPrompt: systemPrompt,
            providerId: provider.descriptor.id,
            model: modelOverride,
            temperature: temperature,
          );

      // Cache lookup — only on the first attempt.
      if (attempt == 0
          && previousAttempt == null
          && !options.disableCache
          && !options.refreshAi
          && cachePolicy != CachePolicy.never) {
        final cached = await cache.readOutput(cacheKey);
        if (cached != null) {
          final v = validateAiOutput(cached, filter);
          if (v.ok) {
            stopwatch.stop();
            await trace.append(
              tagId: req.id,
              promptHash: _hash(req.prompt),
              envelopeHash: _hash(envelopeXml),
              systemHash: systemHash,
              provider: provider.descriptor.id,
              duration: stopwatch.elapsed,
              retries: 0,
              fromCache: true,
              cacheDecision: 'hit',
              outputHash: _hash(cached),
              validation: 'ok',
            );
            return ResolutionResult(
              request: req,
              value: _applyPostProcessing(cached, filter, request: req),
              fromCache: true,
              providerId: provider.descriptor.id,
              duration: stopwatch.elapsed,
              retries: 0,
            );
          }
        }
        if (cachePolicy == CachePolicy.always) {
          throw AiCacheError(
            'cache: always required for tag ${req.id} but no entry found.',
          );
        }
      }

      final invocation = AiInvocation(
        systemPrompt: systemPrompt,
        userEnvelope: envelopeXml,
        modelOverride: modelOverride,
        temperature: temperature,
        seed: seedArg,
      );

      final timeoutArg = filter.named['timeout'];
      final timeout = timeoutArg is PvDuration
          ? timeoutArg.value
          : const Duration(seconds: 60);

      final result = await provider.invoke(invocation, timeout: timeout);

      var raw = result.stdout;
      if (raw.startsWith(aiErrorSentinel)) {
        throw AiOutputContractError(
          req.id,
          raw.substring(aiErrorSentinel.length).trim(),
        );
      }

      // Post-process raw text before validation: strip fences, trim, etc.
      final stripFencesArg =
          (filter.named['strip_fences'] as PvBool?)?.value ?? true;
      if (stripFencesArg) raw = stripFences(raw);
      final trimArg = (filter.named['trim'] as PvBool?)?.value ?? true;
      if (trimArg) raw = raw.trim();

      final v = validateAiOutput(raw, filter);
      if (v.ok) {
        stopwatch.stop();
        if (cachePolicy != CachePolicy.never && !options.disableCache) {
          await cache.writeOutput(
            key: cacheKey,
            output: raw,
            prompt: req.prompt,
            envelopeXml: envelopeXml,
            systemPrompt: systemPrompt,
            systemHash: systemHash,
          );
        }
        await trace.append(
          tagId: req.id,
          promptHash: _hash(req.prompt),
          envelopeHash: _hash(envelopeXml),
          systemHash: systemHash,
          provider: provider.descriptor.id,
          duration: stopwatch.elapsed,
          retries: attempt,
          fromCache: false,
          cacheDecision: options.disableCache ? 'disabled' : 'miss',
          outputHash: _hash(raw),
          validation: 'ok',
          model: result.modelReported,
        );
        return ResolutionResult(
          request: req,
          value: _applyPostProcessing(raw, filter, request: req),
          fromCache: false,
          providerId: provider.descriptor.id,
          modelReported: result.modelReported,
          duration: stopwatch.elapsed,
          retries: attempt,
        );
      }

      // Validation failed: maybe retry.
      attempt++;
      if (attempt > retriesArg) {
        throw AiValidationError(req.id, v.reason!, raw);
      }
      previousAttempt = PreviousAttempt(output: raw, reason: v.reason!);
    }
  }

  String _applyPostProcessing(
    String raw,
    FilterCall filter, {
    AiTagRequest? request,
  }) {
    var value = raw;
    final caseArg = (filter.named['case'] as PvIdentifier?)?.value
        ?? (filter.named['case'] as PvString?)?.value;
    if (caseArg != null) value = applyCase(value, caseArg);
    if (request != null) {
      for (final f in request.node.postAiFilters) {
        final fn = filterRegistry.lookup(f.name);
        if (fn != null) value = fn(value, f);
      }
    }
    return value;
  }

  static String _hash(String s) =>
      sha256.convert(utf8.encode(s)).toString().substring(0, 16);
}
