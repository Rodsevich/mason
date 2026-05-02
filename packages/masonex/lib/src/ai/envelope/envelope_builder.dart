// ignore_for_file: public_member_api_docs, lines_longer_than_80_chars

import 'package:masonex/src/ai/envelope/envelope.dart';
import 'package:masonex/src/ai/envelope/inline_detector.dart';
import 'package:masonex/src/ai/pipeline/ai_tag_request.dart';
import 'package:masonex/src/ai/pipeline/pipeline_node.dart';
import 'package:masonex/src/ai/validation/expect.dart';

/// Builds an [Envelope] for a single [AiTagRequest], assembling the
/// constraints declared in the pipeline filter args and the surrounding
/// context.
class EnvelopeBuilder {
  const EnvelopeBuilder();

  Envelope build({
    required AiTagRequest request,
    required BrickContext brickContext,
    required String currentFileSource,
    int linesAround = 5,
    List<BrickFileEntry> extraFiles = const [],
    String? extraContext,
    PreviousAttempt? previousAttempt,
    List<PreviousResolution> previousResolutions = const [],
  }) {
    final filter = request.node.filters.firstWhere(
      (f) => f.name == 'ai',
      orElse: () => const FilterCall(name: 'ai'),
    );

    final args = filter.named;

    final caseHint =
        (args['case'] as PvIdentifier?)?.value ??
            (args['case'] as PvString?)?.value;

    final expectArg = (args['expect'] as PvIdentifier?)?.value ??
        (args['expect'] as PvString?)?.value;

    var expectedShape = expectedShapeFor(expectArg, caseHint: caseHint);
    if (request.inlineHint) {
      expectedShape = '$expectedShape; the tag is inline so the answer must '
          'be a single line with no newlines';
    }

    final constraintLines = <String>[];
    final retries = (args['retries'] as PvInt?)?.value;
    if (retries != null) {
      constraintLines.add('<retries>$retries</retries>');
    }
    final maxChars = (args['max_chars'] as PvInt?)?.value;
    if (maxChars != null) {
      constraintLines.add('<max_chars>$maxChars</max_chars>');
    }
    final minChars = (args['min_chars'] as PvInt?)?.value;
    if (minChars != null) {
      constraintLines.add('<min_chars>$minChars</min_chars>');
    }
    final lines = args['lines'];
    if (lines is PvInt) {
      constraintLines.add('<lines>${lines.value}</lines>');
    } else if (lines is PvRange) {
      constraintLines.add('<lines>${lines.toSyntax()}</lines>');
    }
    final match = args['match'];
    if (match is PvRegex) {
      constraintLines.add('<match>${_xmlText(match.toSyntax())}</match>');
    } else if (match is PvString) {
      constraintLines.add('<match>${_xmlText(match.value)}</match>');
    }
    final oneOf = args['oneOf'];
    if (oneOf is PvList) {
      final allowed = oneOf.values.map((v) => v.toString()).join(',');
      constraintLines.add('<oneOf>${_xmlText(allowed)}</oneOf>');
    }
    final forbid = args['forbid'];
    if (forbid is PvRegex) {
      constraintLines.add('<forbid>${_xmlText(forbid.toSyntax())}</forbid>');
    } else if (forbid is PvString) {
      constraintLines.add('<forbid>${_xmlText(forbid.value)}</forbid>');
    } else if (forbid is PvList) {
      constraintLines.add(
        '<forbid>${_xmlText(forbid.values.map((v) => v.toString()).join(','))}</forbid>',
      );
    }
    final language = (args['language'] as PvString?)?.value
        ?? (args['language'] as PvIdentifier?)?.value;
    if (language != null) {
      constraintLines.add('<language>${_xmlText(language)}</language>');
    }
    final style = (args['style'] as PvString?)?.value;
    if (style != null) {
      constraintLines.add('<style>${_xmlText(style)}</style>');
    }
    final tone = (args['tone'] as PvString?)?.value;
    if (tone != null) {
      constraintLines.add('<tone>${_xmlText(tone)}</tone>');
    }
    final persona = (args['persona'] as PvString?)?.value;
    if (persona != null) {
      constraintLines.add('<persona>${_xmlText(persona)}</persona>');
    }

    final postFilters =
        request.node.postAiFilters.map((f) => f.toSyntax()).toList();

    final detector = InlineDetector(currentFileSource);
    // Compute byte offsets via the rewriter's metadata: not directly
    // available. We approximate using line+column (1-based) and the source.
    final offset = _offsetForLineCol(
      currentFileSource,
      request.line,
      request.column,
    );
    final tagSrc = '{{ ${request.tagOriginal} }}';
    final tagEnd = offset + tagSrc.length;
    final before = detector.linesBefore(offset, maxLines: linesAround);
    final after = detector.linesAfter(tagEnd, maxLines: linesAround);

    return Envelope(
      brickContext: brickContext,
      request: request,
      expectedShape: expectedShape,
      constraintLines: constraintLines,
      postFilters: postFilters,
      authorNote: (args['description'] as PvString?)?.value,
      extras: TagEnvelopeExtras(
        extraFiles: extraFiles,
        extraContext: extraContext,
        linesBefore: before,
        linesAfter: after,
        previousAttempt: previousAttempt,
      ),
      previousResolutions: previousResolutions,
    );
  }

  static int _offsetForLineCol(String src, int line, int col) {
    var l = 1;
    var c = 1;
    for (var i = 0; i < src.length; i++) {
      if (l == line && c == col) return i;
      if (src[i] == '\n') {
        l++;
        c = 1;
      } else {
        c++;
      }
    }
    return src.length;
  }

  static String _xmlText(String s) =>
      s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
}
