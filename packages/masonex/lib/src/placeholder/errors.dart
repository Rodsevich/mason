// ignore_for_file: public_member_api_docs, lines_longer_than_80_chars

import 'package:masonex/src/exception.dart';

/// Base class for errors emitted by the placeholder-mode pre-processor.
class PlaceholderModeException extends MasonexException {
  const PlaceholderModeException(super.message);
}

/// The brick file failed to parse as Dart.
class PlaceholderParseError extends PlaceholderModeException {
  PlaceholderParseError(this.diagnostics)
      : super('Placeholder mode requires the brick file to be valid Dart. '
            'Parse failed:\n${diagnostics.join('\n')}');

  final List<String> diagnostics;
}

/// A `@pragma('masonex:…', …)` annotation has malformed arguments
/// (wrong arity, non-Map options, non-string values, etc.).
class PlaceholderPragmaShapeError extends PlaceholderModeException {
  PlaceholderPragmaShapeError(this.line, this.column, String detail)
      : super('Invalid @pragma masonex annotation at line $line, '
            'column $column: $detail');

  final int line;
  final int column;
}
