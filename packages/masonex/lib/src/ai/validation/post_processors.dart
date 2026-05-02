// ignore_for_file: public_member_api_docs, lines_longer_than_80_chars

import 'package:masonex/src/recase.dart';

/// Strips markdown code fences (``` and ```lang) at the start and end of [s]
/// if both are present. Preserves the content untouched if no balanced
/// fence pair is found.
String stripFences(String s) {
  final trimmed = s.trim();
  final fenceStart = RegExp(r'^```[a-zA-Z0-9_+-]*\s*\n');
  final m = fenceStart.firstMatch(trimmed);
  if (m == null) return s;
  if (!trimmed.endsWith('```')) return s;
  return trimmed.substring(m.end, trimmed.length - 3).trimRight();
}

/// Collapses internal whitespace and trims, useful for `expect: word`.
String collapseWhitespace(String s) =>
    s.replaceAll(RegExp(r'\s+'), ' ').trim();

/// Forces an identifier into a target casing.
String applyCase(String input, String caseName) {
  final r = ReCase(input);
  switch (caseName) {
    case 'camel':
      return r.camelCase;
    case 'pascal':
      return r.pascalCase;
    case 'snake':
      return r.snakeCase;
    case 'kebab':
    case 'param':
      return r.paramCase;
    case 'const':
    case 'constant':
      return r.constantCase;
    case 'dot':
      return r.dotCase;
    default:
      return input;
  }
}
