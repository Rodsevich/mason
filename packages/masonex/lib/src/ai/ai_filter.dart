// ignore_for_file: public_member_api_docs, lines_longer_than_80_chars

import 'package:masonex/src/ai/cache/cache.dart';
import 'package:masonex/src/ai/cache/trace.dart';
import 'package:masonex/src/ai/envelope/envelope.dart';
import 'package:masonex/src/ai/errors.dart';
import 'package:masonex/src/ai/filter_registry/builtin_filters.dart';
import 'package:masonex/src/ai/orchestrator/orchestrator.dart';
import 'package:masonex/src/ai/pipeline/ai_tag_request.dart';
import 'package:masonex/src/ai/pipeline/pipeline_node.dart' as masonex_ast;
import 'package:masonex/src/ai/provider/adapter.dart';
import 'package:masonex/src/ai/system_prompt.dart';
import 'package:mustachex/mustachex.dart' as mx;

/// `MustachexFilter` implementation backed by masonex's existing
/// orchestrator. mustachex 2.0+ owns the parsing and the rendering; this
/// filter only handles the deferred fulfilment.
///
/// Registered into a [mx.Template] via the `filters:` parameter. Each
/// `mason make` builds one [AiFilter] per render so the orchestrator's
/// per-render state (cache, provider, brick metadata) is fresh.
class AiFilter extends mx.MustachexFilter {
  AiFilter({
    required this.provider,
    required this.cache,
    required this.trace,
    required this.brickContext,
    required this.options,
    String? systemPromptOverride,
  }) : systemPrompt = systemPromptOverride ?? aiSystemPrompt;

  final AiProviderAdapter provider;
  final AiCache cache;
  final AiTrace trace;
  final BrickContext brickContext;
  final OrchestratorOptions options;
  final String systemPrompt;

  @override
  String get name => 'ai';

  @override
  bool get deferred => true;

  @override
  Future<Map<mx.DeferredCallId, String>> fulfill(
    List<mx.DeferredCall> calls,
  ) async {
    if (calls.isEmpty) return const {};
    final orchestrator = AiOrchestrator(
      provider: provider,
      cache: cache,
      trace: trace,
      brickContext: brickContext,
      currentFileSource: (_) => '',
      options: options,
      systemPromptOverride: systemPrompt,
      filterRegistry: buildDefaultFilterRegistry(),
    );

    // Translate mustachex DeferredCall → masonex AiTagRequest, preserving
    // ids so we can map back by id (orchestrator runs requests in
    // parallel so results are NOT in submission order).
    final requests = <AiTagRequest>[];
    for (var i = 0; i < calls.length; i++) {
      requests.add(_toAiTagRequest(calls[i], i));
    }
    final results = await orchestrator.resolveAll(requests);
    final byTagId = <String, String>{
      for (final r in results) r.request.id: r.value,
    };
    final byId = <mx.DeferredCallId, String>{};
    for (final c in calls) {
      final v = byTagId[c.id.value];
      if (v != null) byId[c.id] = v;
    }
    return byId;
  }

  AiTagRequest _toAiTagRequest(mx.DeferredCall call, int index) {
    final synthetic = '__masonex_ai_$index';
    final node = _buildLegacyNode(call);
    final id = call.id.value;
    return AiTagRequest(
      id: id,
      syntheticVarName: synthetic,
      relativePath: call.context.currentFilePath ?? '',
      line: call.context.line,
      column: call.context.column,
      prompt: call.headValue,
      node: node,
      tagOriginal: _approxTagOriginal(call),
      inlineHint: call.context.inline,
    );
  }

  // The orchestrator was built around masonex's own
  // `FilterPipelineNode`. We bridge to it so the existing envelope /
  // validators / post-processing keep working unchanged.
  masonex_ast.FilterPipelineNode _buildLegacyNode(mx.DeferredCall call) {
    final masonexFilter = masonex_ast.FilterCall(
      name: call.filterName,
      positional: call.args.positional
          .map<masonex_ast.PipelineValue>(_translatePv)
          .toList(),
      named: call.args.named.map(
        (k, v) => MapEntry(k, _translatePv(v)),
      ),
    );
    return masonex_ast.FilterPipelineNode(
      head: call.headValue,
      headKind: call.headKind == mx.HeadKind.literal
          ? masonex_ast.HeadKind.literal
          : masonex_ast.HeadKind.variable,
      filters: [masonexFilter],
      original: _approxTagOriginal(call),
    );
  }

  String _approxTagOriginal(mx.DeferredCall call) {
    final argSyntax = mx.FilterCall(
      name: call.filterName,
      positional: call.args.positional,
      named: call.args.named,
    ).toSyntax();
    final headRendered = call.headKind == mx.HeadKind.literal
        ? '"${call.headValue}"'
        : call.headValue;
    return '$headRendered | $argSyntax';
  }

  masonex_ast.PipelineValue _translatePv(mx.PipelineValue v) {
    if (v is mx.PvString) return masonex_ast.PvString(v.value);
    if (v is mx.PvInt) return masonex_ast.PvInt(v.value);
    if (v is mx.PvDouble) return masonex_ast.PvDouble(v.value);
    if (v is mx.PvBool) return masonex_ast.PvBool(v.value);
    if (v is mx.PvDuration) return masonex_ast.PvDuration(v.value);
    if (v is mx.PvIdentifier) return masonex_ast.PvIdentifier(v.value);
    if (v is mx.PvList) {
      return masonex_ast.PvList(
        v.values.map(_translatePv).toList(),
      );
    }
    if (v is mx.PvRange) {
      return masonex_ast.PvRange(min: v.min, max: v.max);
    }
    if (v is mx.PvRegex) return masonex_ast.PvRegex(v.pattern, v.flags);
    throw AiException('Unsupported pipeline value type: ${v.runtimeType}');
  }

}
