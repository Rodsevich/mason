// ignore_for_file: public_member_api_docs, lines_longer_than_80_chars

import 'dart:convert';

import 'package:masonex/src/ai/pipeline/pipeline_node.dart';

/// Outcome of validating an AI output against the constraints declared in a
/// pipeline tag.
class ValidationResult {
  ValidationResult.ok(this.processed) : reason = null;
  ValidationResult.fail(this.reason) : processed = null;

  /// Non-null when validation passed; the post-processed value ready to be
  /// substituted in the template.
  final String? processed;

  /// Non-null when validation failed; the human-readable reason.
  final String? reason;

  bool get ok => reason == null;
}

/// Validates [output] against the constraints encoded in [filter] (an `ai`
/// FilterCall). Applies basic post-processing on success.
ValidationResult validateAiOutput(String output, FilterCall filter) {
  final args = filter.named;
  final expect = (args['expect'] as PvIdentifier?)?.value
      ?? (args['expect'] as PvString?)?.value;

  // Lines constraint.
  final linesArg = args['lines'];
  final lineCount = output.split('\n').length;
  if (linesArg is PvInt && lineCount != linesArg.value) {
    return ValidationResult.fail(
      'expected exactly ${linesArg.value} line(s), got $lineCount',
    );
  }
  if (linesArg is PvRange && !linesArg.contains(lineCount)) {
    return ValidationResult.fail(
      'expected $lineCount lines to be in range ${linesArg.toSyntax()}',
    );
  }

  // Char-length constraints.
  final maxChars = (args['max_chars'] as PvInt?)?.value;
  if (maxChars != null && output.length > maxChars) {
    return ValidationResult.fail(
      'output is ${output.length} chars, max is $maxChars',
    );
  }
  final minChars = (args['min_chars'] as PvInt?)?.value;
  if (minChars != null && output.length < minChars) {
    return ValidationResult.fail(
      'output is ${output.length} chars, min is $minChars',
    );
  }

  // Match regex.
  final match = args['match'];
  if (match is PvRegex && !match.toRegExp().hasMatch(output)) {
    return ValidationResult.fail(
      'output does not match ${match.toSyntax()}',
    );
  }
  if (match is PvString && !RegExp(match.value).hasMatch(output)) {
    return ValidationResult.fail(
      'output does not match /${match.value}/',
    );
  }

  // oneOf list.
  final oneOf = args['oneOf'];
  if (oneOf is PvList) {
    final allowed = oneOf.values.map((v) => v.toString()).toSet();
    if (!allowed.contains(output)) {
      return ValidationResult.fail(
        'output "$output" is not in oneOf $allowed',
      );
    }
  }

  // forbid (regex or list).
  final forbid = args['forbid'];
  if (forbid is PvRegex && forbid.toRegExp().hasMatch(output)) {
    return ValidationResult.fail(
      'output matches forbidden pattern ${forbid.toSyntax()}',
    );
  }
  if (forbid is PvString && RegExp(forbid.value).hasMatch(output)) {
    return ValidationResult.fail(
      'output matches forbidden pattern /${forbid.value}/',
    );
  }
  if (forbid is PvList) {
    final tokens = forbid.values.map((v) => v.toString()).toList();
    final hit = tokens.firstWhere(
      output.contains,
      orElse: () => '',
    );
    if (hit.isNotEmpty) {
      return ValidationResult.fail(
        'output contains forbidden token "$hit"',
      );
    }
  }

  // Expect-driven validation.
  if (expect != null) {
    final r = _validateExpect(output, expect);
    if (!r.ok) return r;
  }

  return ValidationResult.ok(output);
}

ValidationResult _validateExpect(String output, String expect) {
  switch (expect) {
    case 'word':
      if (RegExp(r'\s').hasMatch(output)) {
        return ValidationResult.fail(
          'expected a single word, but output contains whitespace',
        );
      }
    case 'line':
      if (output.contains('\n')) {
        return ValidationResult.fail(
          'expected a single line, but output contains newlines',
        );
      }
    case 'json':
      try {
        jsonDecode(output);
      } on FormatException catch (e) {
        return ValidationResult.fail('output is not valid JSON: ${e.message}');
      }
    case 'number':
      if (num.tryParse(output.trim()) == null) {
        return ValidationResult.fail('output is not a valid number');
      }
    case 'boolean':
      if (output != 'true' && output != 'false') {
        return ValidationResult.fail(
          'expected "true" or "false" (lowercase), got "$output"',
        );
      }
    case 'identifier':
      // Permissive on purpose: accepts any identifier-like string with
      // common separators (hyphen, underscore, dot). The `case:` post-
      // processor (if any) normalizes to the target casing afterwards.
      if (!RegExp(r'^[A-Za-z_][A-Za-z0-9_\-.]*$').hasMatch(output)) {
        return ValidationResult.fail(
          'output is not a valid identifier-like token',
        );
      }
  }
  return ValidationResult.ok(output);
}
