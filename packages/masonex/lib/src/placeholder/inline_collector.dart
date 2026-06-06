// ignore_for_file: public_member_api_docs, lines_longer_than_80_chars

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:masonex/src/placeholder/edit.dart';

/// Walks the token stream of a parsed compilation unit and emits [Edit]s
/// for every `/*{{...}}*/` block comment that holds a Mustache tag.
///
/// Two flavors:
///
/// - **Passthrough** (tag starts with a sigil `#`, `^`, `/`, `>`, `!`, `&`,
///   or is `{{{...}}}`): the comment delimiters `/*` and `*/` are stripped
///   and the tag is left in place.
/// - **Substitution** (plain variable / dotted path / filter pipeline):
///   the comment AND the next adjacent stand-in token (identifier or
///   literal) are replaced by the tag. If no eligible stand-in follows,
///   we fall back to passthrough.
class InlineCollector {
  InlineCollector({required this.unit, required this.source});

  final CompilationUnit unit;
  final String source;

  final List<Edit> edits = [];

  /// Walks every multi-line comment attached to every token in the unit.
  void run() {
    final visited = <int>{};
    var t = unit.beginToken;
    final stop = unit.endToken.next;
    while (t != stop) {
      _processCommentsBefore(t, visited);
      final next = t.next;
      if (next == null) break;
      t = next;
    }
  }

  void _processCommentsBefore(Token host, Set<int> visited) {
    Token? c = host.precedingComments;
    while (c != null) {
      if (visited.add(c.offset) &&
          c.type == TokenType.MULTI_LINE_COMMENT) {
        _emitForComment(c, host);
      }
      c = c.next;
    }
  }

  void _emitForComment(Token comment, Token host) {
    final tag = _matchPlaceholderComment(comment.lexeme);
    if (tag == null) return;

    if (_hasSigil(tag)) {
      edits.add(Edit.replace(comment.offset, comment.length, tag));
      return;
    }

    final standIn = _adjacentStandInToken(comment, host);
    if (standIn == null) {
      edits.add(Edit.replace(comment.offset, comment.length, tag));
      return;
    }

    final length = standIn.end - comment.offset;
    edits.add(Edit.replace(comment.offset, length, tag));
  }

  /// Returns the next stand-in token after [comment], if it sits adjacent
  /// (only whitespace between) and is one of: IDENTIFIER, INT, DOUBLE,
  /// STRING, or one of a small allow-list of keyword stand-ins.
  Token? _adjacentStandInToken(Token comment, Token host) {
    if (comment.next != null) {
      // Another comment follows the same host; not a stand-in.
      return null;
    }
    if (!_isStandIn(host)) return null;
    if (!_isAdjacent(comment.end, host.offset)) return null;
    return host;
  }

  bool _isStandIn(Token t) {
    final type = t.type;
    if (type == TokenType.IDENTIFIER) return true;
    if (type == TokenType.INT) return true;
    if (type == TokenType.DOUBLE) return true;
    if (type == TokenType.STRING) return true;
    if (type.isKeyword) {
      const allowed = {
        'void', 'dynamic', 'bool', 'int', 'double', 'num', 'String', //
        'true', 'false', 'null',
      };
      return allowed.contains(t.lexeme);
    }
    return false;
  }

  bool _isAdjacent(int commentEnd, int tokenOffset) {
    if (tokenOffset < commentEnd) return false;
    for (var i = commentEnd; i < tokenOffset; i++) {
      final c = source.codeUnitAt(i);
      if (c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D) continue;
      return false;
    }
    return true;
  }

  /// Extracts the inner Mustache tag from a `/*{{...}}*/` comment lexeme.
  /// Returns null if the comment does not match.
  String? _matchPlaceholderComment(String lexeme) {
    if (!lexeme.startsWith('/*') || !lexeme.endsWith('*/')) return null;
    final inner = lexeme.substring(2, lexeme.length - 2).trim();
    if (inner.isEmpty) return null;
    if (inner.startsWith('{{{') && inner.endsWith('}}}')) {
      final body = inner.substring(3, inner.length - 3);
      if (body.trim().isEmpty) return null;
      return inner;
    }
    if (inner.startsWith('{{') && inner.endsWith('}}')) {
      final body = inner.substring(2, inner.length - 2);
      if (body.trim().isEmpty) return null;
      if (body.contains('{{') || body.contains('}}')) return null;
      return inner;
    }
    return null;
  }

  bool _hasSigil(String tag) {
    if (tag.startsWith('{{{')) return true;
    final body = tag.substring(2, tag.length - 2).trimLeft();
    if (body.isEmpty) return false;
    final c = body.codeUnitAt(0);
    return c == 0x23 ||
        c == 0x5E ||
        c == 0x2F ||
        c == 0x3E ||
        c == 0x21 ||
        c == 0x26;
  }
}
