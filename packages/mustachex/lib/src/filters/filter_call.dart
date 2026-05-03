// ignore_for_file: public_member_api_docs

import 'pipeline_value.dart';

/// Whether the head of a [FilterPipelineNode] was a quoted/spaced literal
/// or an identifier to look up in the variables context.
enum HeadKind { literal, variable }

/// One filter call inside a pipeline (`uppercase`, `ai(expect: word)`).
class FilterCall {
  const FilterCall({
    required this.name,
    this.positional = const [],
    this.named = const {},
  });

  final String name;
  final List<PipelineValue> positional;
  final Map<String, PipelineValue> named;

  String toSyntax() {
    if (positional.isEmpty && named.isEmpty) return name;
    final parts = <String>[
      ...positional.map((v) => v.toSyntax()),
      ...named.entries.map((e) => '${e.key}: ${e.value.toSyntax()}'),
    ];
    return '$name(${parts.join(', ')})';
  }
}
