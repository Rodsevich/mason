// ignore_for_file: avoid_positional_boolean_parameters, public_member_api_docs, lines_longer_than_80_chars

/// Whether the pipeline head is a string literal or a variable reference.
enum HeadKind { literal, variable }

/// A typed argument value. The pipeline parser stores arguments as instances
/// of [PipelineValue] so filters can dispatch on the runtime type without
/// re-parsing.
sealed class PipelineValue {
  const PipelineValue();

  /// Render the value back to a syntactic representation. Useful for audit /
  /// trace output.
  String toSyntax();
}

class PvString extends PipelineValue {
  const PvString(this.value);
  final String value;
  @override
  String toSyntax() => '"${value.replaceAll('"', r'\"')}"';
  @override
  String toString() => value;
}

class PvInt extends PipelineValue {
  const PvInt(this.value);
  final int value;
  @override
  String toSyntax() => '$value';
  @override
  String toString() => '$value';
}

class PvDouble extends PipelineValue {
  const PvDouble(this.value);
  final double value;
  @override
  String toSyntax() => '$value';
  @override
  String toString() => '$value';
}

class PvBool extends PipelineValue {
  const PvBool(this.value);
  final bool value;
  @override
  String toSyntax() => '$value';
  @override
  String toString() => '$value';
}

class PvDuration extends PipelineValue {
  const PvDuration(this.value);
  final Duration value;
  @override
  String toSyntax() {
    if (value.inHours > 0 && value.inMinutes % 60 == 0) {
      return '${value.inHours}h';
    }
    if (value.inMinutes > 0 && value.inSeconds % 60 == 0) {
      return '${value.inMinutes}m';
    }
    return '${value.inSeconds}s';
  }

  @override
  String toString() => toSyntax();
}

class PvIdentifier extends PipelineValue {
  const PvIdentifier(this.value);
  final String value;
  @override
  String toSyntax() => value;
  @override
  String toString() => value;
}

class PvList extends PipelineValue {
  const PvList(this.values);
  final List<PipelineValue> values;
  @override
  String toSyntax() => '[${values.map((v) => v.toSyntax()).join(', ')}]';
  @override
  String toString() => values.map((v) => v.toString()).toList().toString();
}

/// A range like `1..3`, `>=2`, `<=5`. Stored as inclusive lower / upper bounds.
/// Either bound may be null for half-open ranges.
class PvRange extends PipelineValue {
  const PvRange({this.min, this.max})
      : assert(min != null || max != null,
            'A range needs at least one bound');
  final int? min;
  final int? max;
  bool contains(int n) =>
      (min == null || n >= min!) && (max == null || n <= max!);
  @override
  String toSyntax() {
    if (min != null && max != null) return '$min..$max';
    if (min != null) return '>=$min';
    return '<=${max!}';
  }

  @override
  String toString() => toSyntax();
}

/// A regular expression literal `/pattern/flags`.
class PvRegex extends PipelineValue {
  const PvRegex(this.pattern, this.flags);
  final String pattern;
  final String flags;
  RegExp toRegExp() {
    final caseSensitive = !flags.contains('i');
    final multiLine = flags.contains('m');
    final dotAll = flags.contains('s');
    final unicode = flags.contains('u');
    return RegExp(
      pattern,
      caseSensitive: caseSensitive,
      multiLine: multiLine,
      dotAll: dotAll,
      unicode: unicode,
    );
  }

  @override
  String toSyntax() => '/$pattern/$flags';
  @override
  String toString() => toSyntax();
}

/// A single filter call inside a pipeline (`ai(expect: word, retries: 2)`).
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

/// The compiled AST of a pipelined tag.
///
/// Examples:
///   `{{ "campeón" | ai(expect: word) | uppercase }}`
///   `{{ varName.ai(expect: word).uppercase() }}`
///
/// Both notations compile to the same node.
class FilterPipelineNode {
  const FilterPipelineNode({
    required this.head,
    required this.headKind,
    required this.filters,
    required this.original,
  });

  /// The textual head: either a string literal (with no quotes) or a variable
  /// name. The parser resolves which one it is via [headKind].
  final String head;
  final HeadKind headKind;
  final List<FilterCall> filters;

  /// The original tag content (between `{{` and `}}`) for diagnostics and
  /// envelope generation.
  final String original;

  bool get hasAi => filters.any((f) => f.name == 'ai');

  /// Filters applied AFTER the AI filter (`ai`). These are the "post filters"
  /// that masonex applies to the AI's output before substitution. Includes
  /// the trailing chain only; pre-AI filters are applied to the head before
  /// the prompt is built.
  List<FilterCall> get postAiFilters {
    final aiIndex = filters.indexWhere((f) => f.name == 'ai');
    if (aiIndex < 0) return const [];
    return filters.sublist(aiIndex + 1);
  }

  /// Filters applied BEFORE the AI filter, used to transform the head value
  /// (only meaningful when [headKind] is [HeadKind.variable]).
  List<FilterCall> get preAiFilters {
    final aiIndex = filters.indexWhere((f) => f.name == 'ai');
    if (aiIndex < 0) return filters;
    return filters.sublist(0, aiIndex);
  }
}
