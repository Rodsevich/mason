// ignore_for_file: public_member_api_docs, lines_longer_than_80_chars

import 'package:masonex/src/ai/pipeline/pipeline_node.dart';

/// Function signature for synchronous post-AI filters (`uppercase`,
/// `snakeCase`, `lowerCase`, …).
///
/// AI-aware filters do not live here — `ai` itself is implemented inside the
/// orchestrator since its execution is async, cached, and provider-mediated.
typedef SyncFilterFn = String Function(String input, FilterCall call);

/// Registry of synchronous filters that can be applied to a string value
/// before or after the AI invocation.
class FilterRegistry {
  FilterRegistry();

  final Map<String, SyncFilterFn> _filters = {};

  void register(String name, SyncFilterFn fn) {
    _filters[name] = fn;
  }

  SyncFilterFn? lookup(String name) => _filters[name];

  bool has(String name) => _filters.containsKey(name);

  Iterable<String> get names => _filters.keys;
}
