// ignore_for_file: avoid_positional_boolean_parameters, public_member_api_docs

/// A typed argument value parsed from a filter call's argument list.
///
/// The pipeline parser stores arguments as [PipelineValue] instances so
/// filter implementations can dispatch on the runtime type without
/// re-parsing or string-stuffing.
abstract class PipelineValue {
  const PipelineValue();

  /// Render the value back to a syntactic representation (useful for
  /// diagnostics / audit output).
  String toSyntax();

  /// Returns a plain Dart object suitable for filter implementations:
  ///   - PvString → String
  ///   - PvInt → int
  ///   - PvDouble → double
  ///   - PvBool → bool
  ///   - PvDuration → Duration
  ///   - PvIdentifier → String (the bare identifier)
  ///   - PvList → List<Object?>
  ///   - PvRange → PvRange (no Dart-native range; consumers handle it)
  ///   - PvRegex → RegExp (compiled)
  Object? unwrap();
}

class PvString extends PipelineValue {
  const PvString(this.value);
  final String value;
  @override
  String toSyntax() => '"${value.replaceAll('"', r'\"')}"';
  @override
  String toString() => value;
  @override
  Object unwrap() => value;
}

class PvInt extends PipelineValue {
  const PvInt(this.value);
  final int value;
  @override
  String toSyntax() => '$value';
  @override
  String toString() => '$value';
  @override
  Object unwrap() => value;
}

class PvDouble extends PipelineValue {
  const PvDouble(this.value);
  final double value;
  @override
  String toSyntax() => '$value';
  @override
  String toString() => '$value';
  @override
  Object unwrap() => value;
}

class PvBool extends PipelineValue {
  const PvBool(this.value);
  final bool value;
  @override
  String toSyntax() => '$value';
  @override
  String toString() => '$value';
  @override
  Object unwrap() => value;
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
  @override
  Object unwrap() => value;
}

class PvIdentifier extends PipelineValue {
  const PvIdentifier(this.value);
  final String value;
  @override
  String toSyntax() => value;
  @override
  String toString() => value;
  @override
  Object unwrap() => value;
}

class PvList extends PipelineValue {
  const PvList(this.values);
  final List<PipelineValue> values;
  @override
  String toSyntax() => '[${values.map((v) => v.toSyntax()).join(', ')}]';
  @override
  String toString() => values.map((v) => v.toString()).toList().toString();
  @override
  Object unwrap() => values.map((v) => v.unwrap()).toList(growable: false);
}

/// Range like `1..3`, `>=2`, `<=5`. At least one bound is non-null.
class PvRange extends PipelineValue {
  const PvRange({this.min, this.max})
      : assert(min != null || max != null, 'Range needs at least one bound');
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
  @override
  Object unwrap() => this;
}

/// Regex literal `/pattern/flags`.
class PvRegex extends PipelineValue {
  const PvRegex(this.pattern, this.flags);
  final String pattern;
  final String flags;
  RegExp toRegExp() => RegExp(
        pattern,
        caseSensitive: !flags.contains('i'),
        multiLine: flags.contains('m'),
        dotAll: flags.contains('s'),
        unicode: flags.contains('u'),
      );

  @override
  String toSyntax() => '/$pattern/$flags';
  @override
  String toString() => toSyntax();
  @override
  Object unwrap() => toRegExp();
}
