// import 'dart:mirrors';

import 'package:analysis_utils/src/analysis.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:source_span/source_span.dart';

// SourceSpan computeLocationFromMirror(DeclarationMirror mirror) {
//   if (mirror.location == null) return null;
//   var source = SourceAnalysis.forMirror(mirror);
//   int offset =
//       _calculateOffset(source, mirror.location.line, mirror.location.column);
//   var finder = _NodeFinder(offset);
//   source.compilationUnit.accept(finder);
//   if (finder.finded == null) throw StateError("Couldn't find the node");
//   return computeLocationFromNode(finder.finded, source);
// }

int _calculateOffset(SourceAnalysis source, int line, int column) {
  var lines = source.code.split("\n");
  int offset = 0;
  line--; //line comes in a 1-indexed bias, while lines is a 0-indexed list
  while (line > 0) {
    offset += lines[--line].length + 1;
  }
  //column is 1-indexed also, must substract that
  return offset + column - 1;
}

SourceSpan computeLocationFromNode(AstNode node, SourceAnalysis source) {
  try {
    node = (node as AnnotatedNode);
  } catch (e) {
    node = node;
  }
  Token startToken, endToken = node.endToken;
  if (node is AnnotatedNode) {
    if (node.documentationComment != null && node.metadata.isNotEmpty) {
      startToken = node.documentationComment!.beginToken;
      Token firstMetadataToken = node.metadata.first.beginToken;
      if (firstMetadataToken.offset < startToken.offset) {
        startToken = firstMetadataToken;
      }
    } else {
      startToken = node.documentationComment?.beginToken ??
          ((node.metadata.isEmpty)
              ? node.beginToken
              : node.metadata.first.beginToken);
    }
  } else {
    startToken = node.beginToken;
  }
  SourceLocation start =
      SourceLocation(startToken.offset, sourceUrl: source.path);
  SourceLocation end =
      SourceLocation(endToken.offset + 1, sourceUrl: source.path);
  String text = source.code.substring(start.offset, end.offset);
  return SourceSpan(start, end, text);
}

class _NodeFinder extends UnifyingAstVisitor {
  int searchedOffset;
  AstNode? found;

  _NodeFinder(this.searchedOffset);

  @override
  visitCompilationUnit(node) {
    node.childEntities.forEach((c) {
      if (c is AstNode) visitNode(c);
    });
  }

  @override
  visitNode(AstNode node) {
    if (found != null) return null;
    // los childEntities contienen también los tokens, por eso
    if (node.offset == searchedOffset ||
        node.childEntities.any((c) => c.offset == searchedOffset)) {
      found = node.parent is CompilationUnit ? node : node.parent;
    } else {
      super.visitNode(node);
    }
    // int nodeOffset;
    // if (node is AnnotatedNode) {
    //   nodeOffset = _min(
    //       node?.documentationComment?.beginToken?.offset,
    //       node?.metadata?.isEmpty ?? true
    //           ? null
    //           : node?.metadata?.first?.beginToken?.offset);
    // }
    // nodeOffset ??= node.beginToken.offset;
    // print("$nodeOffset == $searchedOffset");
    // if (nodeOffset == searchedOffset) {
    //   finded = node;
    // }
    // if (nodeOffset - 100 < searchedOffset) {
    //   return super.visitNode(node);
    // } else {
    //   debugger();
    // }
  }
}

// int _min(int j, int i) {
//   if (i == null) {
//     if (j == null) {
//       return null;
//     } else {
//       return j;
//     }
//   } else {
//     if (j == null) {
//       return i;
//     } else {
//       if (i <= j) {
//         return i;
//       } else {
//         return j;
//       }
//     }
//   }
// }
