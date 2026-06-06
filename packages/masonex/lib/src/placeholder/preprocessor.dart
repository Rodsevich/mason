// ignore_for_file: public_member_api_docs, lines_longer_than_80_chars

import 'package:analyzer/dart/analysis/utilities.dart' as parsing;
import 'package:analyzer/error/error.dart';
import 'package:masonex/src/placeholder/edit.dart';
import 'package:masonex/src/placeholder/errors.dart';
import 'package:masonex/src/placeholder/inline_collector.dart';
import 'package:masonex/src/placeholder/pragma_collector.dart';

/// Magic markers used to recognize a brick file as "placeholder mode".
/// A file that contains either an `@pragma('masonex:…', …)` annotation
/// **or** an inline `/*{{…}}*/` block comment is rewritten by the
/// preprocessor before the rest of the render pipeline kicks in. Other
/// files are returned untouched.
const _pragmaMarkers = <String>[
  "@pragma('masonex:header'",
  "@pragma('masonex:replace'",
  '@pragma("masonex:header"',
  '@pragma("masonex:replace"',
];

final _inlineMarker = RegExp(r'/\*\s*\{\{');

bool _looksLikePlaceholderMode(String source) {
  for (final marker in _pragmaMarkers) {
    if (source.contains(marker)) return true;
  }
  return _inlineMarker.hasMatch(source);
}

/// Pre-processes a Dart brick file written in placeholder mode and
/// returns its Mustache equivalent.
///
/// If [source] does not contain any placeholder-mode marker, [source] is
/// returned unchanged. Otherwise the file is parsed with
/// `package:analyzer`, both collectors run, and the resulting [Edit]s
/// are applied bottom-up.
///
/// Throws [PlaceholderParseError] if the source isn't valid Dart, or
/// [PlaceholderPragmaShapeError] if a `masonex:` pragma is malformed.
String preprocessPlaceholderDart(String source) {
  if (!_looksLikePlaceholderMode(source)) return source;

  final result = parsing.parseString(
    content: source,
    throwIfDiagnostics: false,
  );

  final fatal = result.errors
      .where((d) => d.errorCode.errorSeverity == ErrorSeverity.ERROR)
      .toList(growable: false);
  if (fatal.isNotEmpty) {
    throw PlaceholderParseError(
      fatal
          .map((d) {
            final loc = result.lineInfo.getLocation(d.offset);
            return '${loc.lineNumber}:${loc.columnNumber}: ${d.message}';
          })
          .toList(growable: false),
    );
  }

  final unit = result.unit;
  final lineInfo = result.lineInfo;

  final pragma = PragmaCollector(
    unit: unit,
    lineInfo: lineInfo,
    source: source,
  );
  unit.accept(pragma);
  final pragmaEdits = <Edit>[
    ...pragma.edits,
    ...applyPragmaRewrites(unit, pragma.rewrites),
  ];

  final inline = InlineCollector(unit: unit, source: source)..run();

  final edits = <Edit>[...pragmaEdits, ...inline.edits];
  if (edits.isEmpty) return source;

  return applyEdits(source, edits);
}
