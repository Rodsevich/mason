// ignore_for_file: public_member_api_docs, lines_longer_than_80_chars

import 'package:masonex/src/recase.dart';
import 'package:mustachex/mustachex.dart';

/// Sync filters that masonex used to expose only via the legacy
/// `_transpileMasonSyntax` (Mustache section lambdas).
///
/// In mustachex 2.0+ they are first-class filters, so when a tag in a
/// brick uses them downstream of a deferred `| ai`, the renderer can
/// apply them without round-tripping through transpile.
///
/// Order matters only for the registry's iteration order in
/// `provider show`-style tools; semantically each filter is keyed by
/// name.
List<MustachexFilter> buildLegacyCompatFilters() => const [
      _Recase('camelCase', _RecaseStyle.camel),
      _Recase('constantCase', _RecaseStyle.constant),
      _Recase('dotCase', _RecaseStyle.dot),
      _Recase('headerCase', _RecaseStyle.header),
      _Lower('lowerCase'),
      _Lower('lowercase'),
      _Recase('paramCase', _RecaseStyle.param),
      _Recase('pascalCase', _RecaseStyle.pascal),
      _Recase('pascalDotCase', _RecaseStyle.pascalDot),
      _Recase('pathCase', _RecaseStyle.path),
      _Recase('sentenceCase', _RecaseStyle.sentence),
      _Recase('snakeCase', _RecaseStyle.snake),
      _Recase('titleCase', _RecaseStyle.title),
      _Upper('upperCase'),
      _Upper('uppercase'),
      _Trim('trim'),
    ];

enum _RecaseStyle {
  camel,
  constant,
  dot,
  header,
  param,
  pascal,
  pascalDot,
  path,
  sentence,
  snake,
  title,
}

class _Recase extends MustachexFilter {
  const _Recase(this._name, this._style);
  final String _name;
  final _RecaseStyle _style;
  @override
  String get name => _name;
  @override
  String renderSync(String input, FilterArgs args, FilterContext ctx) {
    final r = ReCase(input);
    switch (_style) {
      case _RecaseStyle.camel:
        return r.camelCase;
      case _RecaseStyle.constant:
        return r.constantCase;
      case _RecaseStyle.dot:
        return r.dotCase;
      case _RecaseStyle.header:
        return r.headerCase;
      case _RecaseStyle.param:
        return r.paramCase;
      case _RecaseStyle.pascal:
        return r.pascalCase;
      case _RecaseStyle.pascalDot:
        return r.pascalDotCase;
      case _RecaseStyle.path:
        return r.pathCase;
      case _RecaseStyle.sentence:
        return r.sentenceCase;
      case _RecaseStyle.snake:
        return r.snakeCase;
      case _RecaseStyle.title:
        return r.titleCase;
    }
  }
}

class _Upper extends MustachexFilter {
  const _Upper(this._name);
  final String _name;
  @override
  String get name => _name;
  @override
  String renderSync(String input, FilterArgs args, FilterContext ctx) =>
      input.toUpperCase();
}

class _Lower extends MustachexFilter {
  const _Lower(this._name);
  final String _name;
  @override
  String get name => _name;
  @override
  String renderSync(String input, FilterArgs args, FilterContext ctx) =>
      input.toLowerCase();
}

class _Trim extends MustachexFilter {
  const _Trim(this._name);
  final String _name;
  @override
  String get name => _name;
  @override
  String renderSync(String input, FilterArgs args, FilterContext ctx) =>
      input.trim();
}
