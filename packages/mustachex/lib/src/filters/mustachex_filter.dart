// ignore_for_file: public_member_api_docs

import 'filter_call.dart' show HeadKind;
import 'pipeline_value.dart';

export 'filter_call.dart' show HeadKind;

/// Arguments supplied to a filter call. Both positional and named are
/// preserved in their parsed form. Use the typed [PipelineValue] hierarchy
/// when you need to dispatch on the runtime type, or call [unwrappedNamed]
/// / [unwrappedPositional] for plain Dart values.
class FilterArgs {
  const FilterArgs({
    this.positional = const [],
    this.named = const {},
  });

  final List<PipelineValue> positional;
  final Map<String, PipelineValue> named;

  List<Object?> get unwrappedPositional =>
      positional.map((v) => v.unwrap()).toList(growable: false);

  Map<String, Object?> get unwrappedNamed =>
      named.map((k, v) => MapEntry(k, v.unwrap()));
}

/// Per-tag context passed to a filter at evaluation time. mustachex sets
/// the well-known fields it can derive from the source; consumers can
/// extend the metadata via [extras].
class FilterContext {
  const FilterContext({
    required this.vars,
    required this.line,
    required this.column,
    required this.inline,
    this.currentFilePath,
    this.surroundingBefore = '',
    this.surroundingAfter = '',
    this.extras = const {},
  });

  final Map<String, Object?> vars;

  /// 1-based line number of the tag's opening `{{` in the template source.
  final int line;
  final int column;

  /// True when the tag is embedded mid-line; false when it occupies its
  /// own line. Used as a hint by some filters (e.g., the AI filter sends
  /// "single line, no newlines" to the model when inline).
  final bool inline;

  final String? currentFilePath;
  final String surroundingBefore;
  final String surroundingAfter;

  /// Extra metadata passed through from the consumer (e.g., brick name,
  /// version). mustachex itself does not populate this map.
  final Map<String, Object?> extras;
}

/// Stable identifier for a single deferred filter call inside one render.
class DeferredCallId {
  const DeferredCallId(this.value);
  final String value;

  @override
  bool operator ==(Object other) =>
      other is DeferredCallId && other.value == value;
  @override
  int get hashCode => value.hashCode;
  @override
  String toString() => value;
}

/// A single deferred filter invocation collected during pass 1.
class DeferredCall {
  const DeferredCall({
    required this.id,
    required this.filterName,
    required this.headValue,
    required this.headKind,
    required this.args,
    required this.context,
    this.postFilters = const [],
  });

  final DeferredCallId id;
  final String filterName;

  /// Head value already resolved (literal as-is, or the variable's
  /// `toString()`) and pre-rendered for Mustache substitutions inside
  /// literal heads.
  final String headValue;
  final FilterContext context;
  final FilterArgs args;
  final HeadKind headKind;

  /// Names of filters chained AFTER this deferred call. Informational
  /// only; mustachex applies them after `fulfill` returns.
  final List<String> postFilters;
}

/// Public extension point for filters that participate in a pipeline.
///
/// Synchronous filters (recase, trim, etc.) implement [renderSync] and
/// return [deferred] = false. Asynchronous filters (AI, RPC) implement
/// [fulfill] and return [deferred] = true; mustachex collects every call
/// to such filters via [collectDeferredCalls] before rendering, lets the
/// consumer fulfil them in bulk, and then renders with the resolutions
/// map.
abstract class MustachexFilter {
  const MustachexFilter();

  String get name;

  /// When true, mustachex collects calls to this filter into a list and
  /// expects the consumer to invoke [fulfill] on them before rendering.
  /// When false, [renderSync] is used inline.
  bool get deferred => false;

  /// Inline path. Receives the head value (already resolved) and returns
  /// the transformed value. Pure and synchronous.
  String renderSync(String input, FilterArgs args, FilterContext ctx) =>
      input;

  /// Bulk-fulfilment path. The default implementation throws — deferred
  /// filters MUST override.
  Future<Map<DeferredCallId, String>> fulfill(
    List<DeferredCall> calls,
  ) async {
    throw UnimplementedError(
      'Filter "$name" is deferred but did not override fulfill().',
    );
  }
}

/// Thrown by `Template.renderString` when the template references a
/// deferred filter call whose id was not present in the supplied
/// resolutions map.
class MissingDeferredResolutionError implements Exception {
  MissingDeferredResolutionError(this.id, this.filterName);
  final DeferredCallId id;
  final String filterName;
  @override
  String toString() =>
      'Missing resolution for deferred call $id (filter "$filterName"). '
      'Did you call Template.collectDeferredCalls and fulfill them before '
      'renderString?';
}

/// Thrown by `Template.collectDeferredCalls` / `renderString` when a tag
/// references a filter name that was not registered with the processor.
class UnknownFilterError implements Exception {
  UnknownFilterError(this.filterName, this.tagOriginal);
  final String filterName;
  final String tagOriginal;
  @override
  String toString() =>
      'Unknown filter "$filterName" in tag "$tagOriginal". '
      'Register it via MustachexProcessor(filters: [...]).';
}
