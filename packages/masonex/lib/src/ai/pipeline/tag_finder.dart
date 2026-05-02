// ignore_for_file: public_member_api_docs, lines_longer_than_80_chars

/// Locates `{{ ... }}` and `{{{ ... }}}` tags inside a Mustache template
/// source while respecting nested `{{ ... }}` sequences that appear inside
/// quoted strings (so the outer regex doesn't trip on them).
///
/// This is intentionally simple: it does NOT validate Mustache syntax. It
/// just hands back ranges of well-formed-looking tags so the AI rewriter can
/// inspect their contents and decide whether they need rewriting.
class FoundTag {
  const FoundTag({
    required this.openLen,
    required this.closeLen,
    required this.tagStart,
    required this.contentStart,
    required this.contentEnd,
    required this.tagEnd,
    required this.content,
    required this.line,
    required this.column,
  });

  final int openLen; // 2 or 3
  final int closeLen; // 2 or 3
  final int tagStart; // index of the first `{`
  final int contentStart; // index after the opening braces
  final int contentEnd; // index of the first `}` of the closing braces
  final int tagEnd; // index after the closing braces
  final String content; // raw content (between braces, untrimmed)
  final int line; // 1-based line number of `tagStart`
  final int column; // 1-based column of `tagStart`
}

class TagFinder {
  TagFinder(this._source);

  final String _source;

  Iterable<FoundTag> find() sync* {
    var i = 0;
    final src = _source;
    while (i < src.length) {
      final ch = src[i];
      if (ch == '{') {
        final openLen = _matchBraces(src, i, openLen: true);
        if (openLen >= 2) {
          final tag = _consumeTag(i, openLen);
          if (tag != null) {
            yield tag;
            i = tag.tagEnd;
            continue;
          }
        }
      }
      i++;
    }
  }

  /// Returns the number of consecutive `{` (or `}`) starting at [start],
  /// capped at 3. Used to detect `{{` vs `{{{`.
  static int _matchBraces(String src, int start, {required bool openLen}) {
    final ch = openLen ? '{' : '}';
    var n = 0;
    var i = start;
    while (i < src.length && src[i] == ch && n < 3) {
      n++;
      i++;
    }
    return n;
  }

  FoundTag? _consumeTag(int tagStart, int openLen) {
    final src = _source;
    final contentStart = tagStart + openLen;
    var i = contentStart;
    final preferredCloseLen = openLen >= 3 ? 3 : 2;

    while (i < src.length) {
      final ch = src[i];
      if (ch == '"' || ch == "'") {
        i = _skipQuoted(i);
        if (i < 0) return null;
        continue;
      }
      if (ch == '}') {
        final closeLen = _matchBraces(src, i, openLen: false);
        if (closeLen >= 2) {
          // Use the same close length as the open length when possible.
          final actualClose =
              closeLen >= preferredCloseLen ? preferredCloseLen : closeLen;
          final contentEnd = i;
          final tagEnd = i + actualClose;
          final content = src.substring(contentStart, contentEnd);
          final pos = _lineColOf(tagStart);
          return FoundTag(
            openLen: openLen,
            closeLen: actualClose,
            tagStart: tagStart,
            contentStart: contentStart,
            contentEnd: contentEnd,
            tagEnd: tagEnd,
            content: content,
            line: pos.$1,
            column: pos.$2,
          );
        }
        i++;
        continue;
      }
      i++;
    }
    return null;
  }

  /// Skips a quoted region. Honors `\\` escapes. Returns the index AFTER the
  /// closing quote, or -1 if the quote was unterminated (caller should treat
  /// the tag as unparseable and bail).
  int _skipQuoted(int start) {
    final src = _source;
    final quote = src[start];
    var i = start + 1;
    while (i < src.length) {
      final ch = src[i];
      if (ch == r'\') {
        i += 2;
        continue;
      }
      if (ch == quote) {
        return i + 1;
      }
      i++;
    }
    return -1;
  }

  (int, int) _lineColOf(int offset) {
    var line = 1;
    var col = 1;
    for (var i = 0; i < offset && i < _source.length; i++) {
      if (_source[i] == '\n') {
        line++;
        col = 1;
      } else {
        col++;
      }
    }
    return (line, col);
  }
}
