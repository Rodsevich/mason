// ignore_for_file: public_member_api_docs, lines_longer_than_80_chars

import 'package:masonex/src/ai/filter_registry/filter_registry.dart';
import 'package:masonex/src/recase.dart';

/// Registers the built-in synchronous filters that masonex understands as
/// post-AI filters in the new pipeline syntax.
///
/// These mirror the lambdas already exposed by `lib/src/render.dart`. They
/// exist here so that `{{ "foo" | ai | uppercase }}` can apply `uppercase`
/// to the AI's reply before substitution, without going through mustachex
/// lambdas (which would require re-encoding the value into the template).
FilterRegistry buildDefaultFilterRegistry() {
  return FilterRegistry()
    ..register('uppercase', (s, _) => s.toUpperCase())
    ..register('upperCase', (s, _) => s.toUpperCase())
    ..register('lowercase', (s, _) => s.toLowerCase())
    ..register('lowerCase', (s, _) => s.toLowerCase())
    ..register('camelCase', (s, _) => ReCase(s).camelCase)
    ..register('constantCase', (s, _) => ReCase(s).constantCase)
    ..register('dotCase', (s, _) => ReCase(s).dotCase)
    ..register('headerCase', (s, _) => ReCase(s).headerCase)
    ..register('paramCase', (s, _) => ReCase(s).paramCase)
    ..register('pascalCase', (s, _) => ReCase(s).pascalCase)
    ..register('pathCase', (s, _) => ReCase(s).pathCase)
    ..register('sentenceCase', (s, _) => ReCase(s).sentenceCase)
    ..register('snakeCase', (s, _) => ReCase(s).snakeCase)
    ..register('titleCase', (s, _) => ReCase(s).titleCase)
    ..register('trim', (s, _) => s.trim());
}
