// ignore_for_file: public_member_api_docs

import '../filters/filter_call.dart';

abstract class Node {
  Node(this.start, this.end);

  // The offset of the start of the token in the file. Unless this is a section
  // or inverse section, then this stores the start of the content of the
  // section.
  final int start;
  final int end;

  void accept(Visitor visitor);
  void visitChildren(Visitor visitor) {}
}

abstract class Visitor {
  void visitText(TextNode node);
  void visitVariable(VariableNode node);
  void visitSection(SectionNode node);
  void visitPartial(PartialNode node);
  void visitFilterPipeline(FilterPipelineNode node);
}

class TextNode extends Node {
  TextNode(this.text, int start, int end) : super(start, end);

  final String text;

  @override
  String toString() => '(TextNode "$_debugText" $start $end)';

  String get _debugText {
    var t = text.replaceAll('\n', '\\n');
    return t.length < 50 ? t : t.substring(0, 48) + '...';
  }

  @override
  void accept(Visitor visitor) => visitor.visitText(this);
}

class VariableNode extends Node {
  VariableNode(this.name, int start, int end, {this.escape = true})
      : super(start, end);

  final String name;
  final bool escape;

  @override
  void accept(Visitor visitor) => visitor.visitVariable(this);

  @override
  String toString() => '(VariableNode "$name" escape: $escape $start $end)';
}

class SectionNode extends Node {
  SectionNode(this.name, int start, int end, this.delimiters,
      {this.inverse = false})
      : contentStart = end,
        super(start, end);

  final String name;
  final String delimiters;
  final bool inverse;
  final int contentStart;
  int? contentEnd; // Set in parser when close tag is parsed.
  final List<Node> children = <Node>[];

  @override
  void accept(Visitor visitor) => visitor.visitSection(this);

  @override
  void visitChildren(Visitor visitor) {
    children.forEach((node) => node.accept(visitor));
  }

  @override
  String toString() => '(SectionNode $name inverse: $inverse $start $end)';
}

class PartialNode extends Node {
  PartialNode(this.name, int start, int end, this.indent) : super(start, end);

  final String name;

  // Used to store the preceding whitespace before a partial tag, so that
  // it's content can be correctly indented.
  final String indent;

  @override
  void accept(Visitor visitor) => visitor.visitPartial(this);

  @override
  String toString() => '(PartialNode $name $start $end "$indent")';
}

/// Tag whose content carries pipeline syntax (`{{ head | f(args) | g }}`
/// or `{{ head.f(args).g() }}`).
///
/// Backward compat: a tag without any pipeline operator parses as a
/// regular [VariableNode]. Only when `looksLikePipeline` matches does the
/// parser emit a [FilterPipelineNode].
class FilterPipelineNode extends Node {
  FilterPipelineNode({
    required this.head,
    required this.headKind,
    required this.filters,
    required this.original,
    required this.escape,
    required int start,
    required int end,
  }) : super(start, end);

  /// The head value as written: a literal text (no quotes) or a variable
  /// name. Use [headKind] to distinguish.
  final String head;
  final HeadKind headKind;
  final List<FilterCall> filters;

  /// Original tag content (between `{{` and `}}`) for diagnostics.
  final String original;

  /// Whether the value should be HTML-escaped after rendering. False for
  /// triple-mustache and `&` tags.
  final bool escape;

  @override
  void accept(Visitor visitor) => visitor.visitFilterPipeline(this);

  @override
  String toString() =>
      '(FilterPipelineNode head=$head kind=$headKind filters=${filters.length} '
      'escape=$escape $start $end)';
}
