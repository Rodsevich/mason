// ignore_for_file: public_member_api_docs, lines_longer_than_80_chars

/// A single textual edit to apply to a source string.
///
/// Edits carry their absolute byte offset and length in the ORIGINAL
/// source. The orchestrator collects them across multiple passes and
/// applies them bottom-up so that earlier offsets stay valid.
class Edit {
  const Edit(this.offset, this.length, this.replacement);

  Edit.delete(int offset, int length) : this(offset, length, '');

  Edit.replace(int offset, int length, String replacement)
      : this(offset, length, replacement);

  final int offset;
  final int length;
  final String replacement;

  int get end => offset + length;

  @override
  String toString() => 'Edit($offset..$end → ${_quote(replacement)})';

  static String _quote(String s) =>
      "'${s.replaceAll('\n', r'\n')}'";
}

/// Applies a list of [Edit]s to [source] and returns the result.
///
/// Edits MUST NOT overlap. The function sorts them by descending offset
/// and applies bottom-up so each edit's offset remains valid throughout
/// the rewrite.
String applyEdits(String source, List<Edit> edits) {
  if (edits.isEmpty) return source;
  final sorted = [...edits]..sort((a, b) => b.offset.compareTo(a.offset));
  for (var i = 0; i < sorted.length - 1; i++) {
    final hi = sorted[i];
    final lo = sorted[i + 1];
    if (lo.end > hi.offset) {
      throw StateError(
        'Overlapping edits: $lo and $hi. Both passes claimed the same '
        'source range. Inspect placeholder mode passes for conflicts.',
      );
    }
  }
  final buf = StringBuffer();
  var cursor = 0;
  // Reverse the sorted list so we walk in ascending order while emitting.
  for (final e in sorted.reversed) {
    buf
      ..write(source.substring(cursor, e.offset))
      ..write(e.replacement);
    cursor = e.end;
  }
  buf.write(source.substring(cursor));
  return buf.toString();
}
