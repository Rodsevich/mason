// ignore_for_file: public_member_api_docs, lines_longer_than_80_chars

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';
import 'package:masonex/src/placeholder/edit.dart';
import 'package:masonex/src/placeholder/errors.dart';

/// One staged pragma rewrite: a token-text → Mustache-tag map and the
/// source range within which to apply it.
class PragmaRewrite {
  PragmaRewrite({
    required this.scopeOffset,
    required this.scopeEnd,
    required this.map,
  });

  final int scopeOffset;
  final int scopeEnd;
  final Map<String, String> map;
}

/// Walks the AST collecting `@pragma('masonex:header', ...)` and
/// `@pragma('masonex:replace', ...)` annotations and translates them
/// into [PragmaRewrite]s + [Edit]s that delete the annotation itself.
///
/// The actual token-level rewrite (looking for keys inside each scope's
/// token range) happens after this pass — see [applyPragmaRewrites].
class PragmaCollector extends RecursiveAstVisitor<void> {
  PragmaCollector({
    required this.unit,
    required this.lineInfo,
    required this.source,
  });

  final CompilationUnit unit;
  final LineInfo lineInfo;
  final String source;

  final List<PragmaRewrite> rewrites = [];
  final List<Edit> edits = [];
  final Set<int> _strippedLibraryDirectives = <int>{};

  static const _pragmaName = 'pragma';
  static const _replaceTag = 'masonex:replace';
  static const _headerTag = 'masonex:header';

  @override
  void visitAnnotation(Annotation node) {
    super.visitAnnotation(node);
    if (node.name.name != _pragmaName) return;
    final args = node.arguments?.arguments;
    if (args == null || args.length != 2) return;

    final tagName = _extractStringLiteral(args[0]);
    if (tagName != _replaceTag && tagName != _headerTag) return;

    final mapNode = args[1];
    if (mapNode is! SetOrMapLiteral) {
      _failShape(node, 'second argument must be a Map literal');
    }

    final map = _extractMap(mapNode);

    final parent = node.parent;
    final scope = _scopeFor(parent);

    rewrites.add(
      PragmaRewrite(
        scopeOffset: scope.$1,
        scopeEnd: scope.$2,
        map: map,
      ),
    );

    final stripWholeLibrary =
        parent is LibraryDirective && _libraryDirectiveOnlyMasonex(parent);

    if (stripWholeLibrary) {
      // Emit a single span deletion covering the whole `library;`
      // directive (with metadata + leading whitespace + trailing
      // newline). Do this ONCE per library directive even if it carries
      // multiple masonex pragmas.
      if (_strippedLibraryDirectives.add(parent.offset)) {
        final start = _libraryDirectiveDeleteStart(parent);
        final end = _libraryDirectiveDeleteEnd(parent);
        edits.add(Edit.delete(start, end - start));
      }
      return;
    }

    // Otherwise, stage deletion of just the annotation itself (including
    // leading whitespace + trailing newline).
    final delStart = _annotationDeleteStart(node);
    final delEnd = _annotationDeleteEnd(node);
    edits.add(Edit.delete(delStart, delEnd - delStart));
  }

  // ---------- helpers ----------

  String? _extractStringLiteral(Expression e) {
    if (e is SimpleStringLiteral) return e.value;
    return null;
  }

  Map<String, String> _extractMap(SetOrMapLiteral node) {
    final result = <String, String>{};
    for (final entry in node.elements) {
      if (entry is! MapLiteralEntry) {
        _failShape(node, 'all map entries must be key-value pairs');
      }
      final key = _keyText(entry.key);
      if (key == null) {
        _failShape(
          entry.key,
          'map keys must be a string literal, an identifier '
          '(class name / type / top-level function), or a prefixed '
          'identifier — got ${entry.key.runtimeType}',
        );
      }
      final value = entry.value;
      if (value is! SimpleStringLiteral) {
        _failShape(
          value,
          'map values must be string literals containing a Mustache '
          'tag (got ${value.runtimeType})',
        );
      }
      final tag = value.value;
      if (!_looksLikeTag(tag)) {
        _failShape(
          value,
          'map values must look like a Mustache tag '
          '(starting with `{{` and ending with `}}`); got "$tag"',
        );
      }
      result[key] = tag;
    }
    return result;
  }

  String? _keyText(Expression key) {
    if (key is SimpleStringLiteral) return key.value;
    if (key is SimpleIdentifier) return key.name;
    if (key is PrefixedIdentifier) return key.identifier.name;
    return null;
  }

  bool _looksLikeTag(String s) {
    // The value must contain at least one Mustache tag, but it may also
    // be free text wrapping the tag (e.g. `'Bloc{{name}}State'` from the
    // BlocXState pattern in the RFC §4.7).
    return s.contains('{{') && s.contains('}}');
  }

  /// Returns the (offset, end) pair defining the scope of an annotation.
  ///
  /// - On a `LibraryDirective` → file body AFTER the directive.
  /// - On any annotated declaration → the declaration body (excluding
  ///   its own metadata).
  /// - Fallback → enclosing declaration / directive / unit (body only).
  (int, int) _scopeFor(AstNode? parent) {
    if (parent is LibraryDirective) {
      return (parent.endToken.end, unit.end);
    }
    if (parent is AnnotatedNode) {
      final body = parent.firstTokenAfterCommentAndMetadata;
      return (body.offset, parent.end);
    }
    var n = parent;
    while (n != null && n is! Declaration && n is! Directive) {
      n = n.parent;
    }
    if (n is AnnotatedNode) {
      final body = n.firstTokenAfterCommentAndMetadata;
      return (body.offset, n.end);
    }
    if (n != null) {
      return (n.offset, n.end);
    }
    return (unit.offset, unit.end);
  }

  /// Where to start deleting the annotation, including any leading
  /// whitespace on the same line.
  int _annotationDeleteStart(Annotation node) {
    var i = node.offset;
    while (i > 0) {
      final c = source.codeUnitAt(i - 1);
      if (c == 0x20 || c == 0x09) {
        i--;
      } else {
        break;
      }
    }
    return i;
  }

  /// Where to stop deleting the annotation: consume trailing whitespace
  /// and at most one trailing newline so the next declaration ends up
  /// at the start of its line.
  int _annotationDeleteEnd(Annotation node) {
    var i = node.end;
    while (i < source.length) {
      final c = source.codeUnitAt(i);
      if (c == 0x20 || c == 0x09) {
        i++;
      } else if (c == 0x0D) {
        i++;
        if (i < source.length && source.codeUnitAt(i) == 0x0A) i++;
        return i;
      } else if (c == 0x0A) {
        return i + 1;
      } else {
        break;
      }
    }
    return i;
  }

  /// True when a `library;` directive carries only `masonex:*` pragmas
  /// (and nothing else). In that case the directive is purely
  /// administrative and we strip it from the rendered output.
  bool _libraryDirectiveOnlyMasonex(LibraryDirective dir) {
    if (dir.metadata.isEmpty) return false;
    for (final ann in dir.metadata) {
      if (!_isMasonexPragma(ann)) return false;
    }
    return true;
  }

  bool _isMasonexPragma(Annotation ann) {
    if (ann.name.name != _pragmaName) return false;
    final args = ann.arguments?.arguments;
    if (args == null || args.isEmpty) return false;
    final tag = _extractStringLiteral(args.first);
    return tag == _replaceTag || tag == _headerTag;
  }

  int _libraryDirectiveDeleteStart(LibraryDirective dir) {
    // The first metadata's start (already deleted), but we want to be
    // sure we cover any leading whitespace before the directive itself.
    var i = dir.offset;
    while (i > 0) {
      final c = source.codeUnitAt(i - 1);
      if (c == 0x20 || c == 0x09) {
        i--;
      } else {
        break;
      }
    }
    return i;
  }

  int _libraryDirectiveDeleteEnd(LibraryDirective dir) {
    // Consume the directive's trailing newline plus any subsequent blank
    // lines so the file body that follows isn't padded by an extra blank
    // line where the directive used to be.
    var i = dir.end;
    var consumedNewline = false;
    while (i < source.length) {
      final c = source.codeUnitAt(i);
      if (c == 0x20 || c == 0x09) {
        i++;
      } else if (c == 0x0D) {
        i++;
        if (i < source.length && source.codeUnitAt(i) == 0x0A) i++;
        consumedNewline = true;
      } else if (c == 0x0A) {
        i++;
        consumedNewline = true;
      } else {
        break;
      }
    }
    // If we never saw a newline (directive sits on a single line followed
    // by text on the same physical line), don't return past the next
    // token start.
    if (!consumedNewline) return dir.end;
    return i;
  }

  Never _failShape(AstNode node, String detail) {
    final loc = lineInfo.getLocation(node.offset);
    throw PlaceholderPragmaShapeError(
      loc.lineNumber,
      loc.columnNumber,
      detail,
    );
  }
}

/// Walks the [unit]'s token stream within each rewrite's scope and
/// emits an [Edit] for every token whose lexeme matches a key.
///
/// `STRING` tokens are skipped (we don't substitute inside string
/// literals). Comment tokens are skipped (they're handled by the
/// inline pass).
List<Edit> applyPragmaRewrites(
  CompilationUnit unit,
  List<PragmaRewrite> rewrites,
) {
  if (rewrites.isEmpty) return const [];
  final out = <Edit>[];
  for (final rw in rewrites) {
    var t = unit.beginToken;
    final stop = unit.endToken.next;
    while (t != stop) {
      if (t.offset >= rw.scopeOffset && t.end <= rw.scopeEnd) {
        if (t.type != TokenType.STRING && !_isCommentToken(t)) {
          final tag = rw.map[t.lexeme];
          if (tag != null) {
            out.add(Edit.replace(t.offset, t.length, tag));
          }
        }
      }
      final next = t.next;
      if (next == null) break;
      t = next;
    }
  }
  return out;
}

bool _isCommentToken(Token t) {
  return t.type == TokenType.MULTI_LINE_COMMENT ||
      t.type == TokenType.SINGLE_LINE_COMMENT;
}
