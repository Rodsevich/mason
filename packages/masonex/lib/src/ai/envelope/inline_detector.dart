// ignore_for_file: public_member_api_docs, lines_longer_than_80_chars

/// Decides whether a tag occurrence is "inline" (embedded mid-line, must
/// produce a single-line output) or "block" (occupies its own line, may
/// produce multi-line output).
///
/// The result is used both as a hint to the model (`inline="true"`) and as
/// part of the validation contract.
class InlineDetector {
  const InlineDetector(this.source);

  final String source;

  bool isInline(int tagStart, int tagEnd) {
    final beforeOk = _onlyWhitespaceBackToNewline(tagStart - 1);
    if (!beforeOk) return true;
    final afterOk = _onlyWhitespaceForwardToNewline(tagEnd);
    if (!afterOk) return true;
    return false;
  }

  bool _onlyWhitespaceBackToNewline(int from) {
    var i = from;
    while (i >= 0) {
      final c = source[i];
      if (c == '\n') return true;
      if (c != ' ' && c != '\t' && c != '\r') return false;
      i--;
    }
    return true;
  }

  bool _onlyWhitespaceForwardToNewline(int from) {
    var i = from;
    while (i < source.length) {
      final c = source[i];
      if (c == '\n') return true;
      if (c != ' ' && c != '\t' && c != '\r') return false;
      i++;
    }
    return true;
  }

  /// Returns up to [maxLines] lines preceding the tag (right side: closer to
  /// the tag). Lines are joined with `\n` without trailing newline.
  String linesBefore(int tagStart, {int maxLines = 5}) {
    final upto = tagStart;
    final lines = <String>[];
    var lineEnd = upto;
    var lineStart = upto;
    while (lineStart > 0 && lines.length < maxLines) {
      lineStart = source.lastIndexOf('\n', lineEnd - 1);
      final from = lineStart < 0 ? 0 : lineStart + 1;
      lines.insert(0, source.substring(from, lineEnd));
      if (lineStart < 0) break;
      lineEnd = lineStart;
    }
    return lines.join('\n');
  }

  String linesAfter(int tagEnd, {int maxLines = 5}) {
    final lines = <String>[];
    var i = tagEnd;
    while (i < source.length && lines.length < maxLines) {
      final next = source.indexOf('\n', i);
      if (next < 0) {
        lines.add(source.substring(i));
        break;
      }
      lines.add(source.substring(i, next));
      i = next + 1;
    }
    return lines.join('\n');
  }
}
