import 'dart:convert';
import 'dart:typed_data';

import '../filters/mustachex_filter.dart';
import '../interfaces.dart';
import 'lambda_context.dart';
import 'node.dart';
import 'template.dart';
import 'template_exception.dart';

const Object noSuchProperty = Object();
final RegExp _integerTag = RegExp(r'^[0-9]+$');
final RegExp _innerMustache =
    RegExp(r'\{\{\s*(\.|[a-zA-Z_][a-zA-Z0-9_.-]*)\s*\}\}');

class Renderer extends Visitor {
  Renderer(this.sink, List stack, this.lenient, this.htmlEscapeValues,
      this.partialResolver, this.templateName, this.indent, this.source,
      {this.filters = const {},
      this.resolutions = const {}})
      : _stack = List.from(stack);

  Renderer.partial(Renderer ctx, Template partial, String indent)
      : this(
          ctx.sink,
          ctx._stack,
          ctx.lenient,
          ctx.htmlEscapeValues,
          ctx.partialResolver,
          ctx.templateName,
          ctx.indent + indent,
          partial.source,
          filters: ctx.filters,
          resolutions: ctx.resolutions,
        );

  Renderer.subtree(Renderer ctx, StringSink sink)
      : this(
          sink,
          ctx._stack,
          ctx.lenient,
          ctx.htmlEscapeValues,
          ctx.partialResolver,
          ctx.templateName,
          ctx.indent,
          ctx.source,
          filters: ctx.filters,
          resolutions: ctx.resolutions,
        );

  Renderer.lambda(Renderer ctx, String source, String indent, StringSink sink,
      String delimiters)
      : this(
          sink,
          ctx._stack,
          ctx.lenient,
          ctx.htmlEscapeValues,
          ctx.partialResolver,
          ctx.templateName,
          ctx.indent + indent,
          source,
          filters: ctx.filters,
          resolutions: ctx.resolutions,
        );

  final StringSink sink;
  final List _stack;

  /// Stack of section iteration indices at the current visit position.
  /// Empty when not inside any iterable section. Used to make
  /// [DeferredCallId]s context-aware: the same FilterPipelineNode visited
  /// at iteration 0 vs 1 produces different ids so each iteration has
  /// its own resolution.
  final List<int> _iterPath = <int>[];

  final bool lenient;
  final bool htmlEscapeValues;
  final PartialResolver? partialResolver;
  final String? templateName;
  final String indent;
  final String source;

  /// Filter registry (name → adapter). Default empty for backward compat.
  final Map<String, MustachexFilter> filters;

  /// Resolutions map for deferred filter calls. Populated by the consumer
  /// after `Template.collectDeferredCalls` + filter.fulfill().
  final Map<DeferredCallId, String> resolutions;

  void push(value) => _stack.add(value);

  dynamic pop() => _stack.removeLast();

  void write(Object output) => sink.write(output.toString());

  void render(List<Node> nodes) {
    if (indent == '') {
      nodes.forEach((n) => n.accept(this));
    } else if (nodes.isNotEmpty) {
      // Special case to make sure there is not an extra indent after the last
      // line in the partial file.
      write(indent);

      nodes.take(nodes.length - 1).forEach((n) => n.accept(this));

      var node = nodes.last;
      if (node is TextNode) {
        visitText(node, lastNode: true);
      } else {
        node.accept(this);
      }
    }
  }

  @override
  void visitText(TextNode node, {bool lastNode = false}) {
    if (node.text == '') return;
    if (indent == '') {
      write(node.text);
    } else if (lastNode && node.text.runes.last == _NEWLINE) {
      // Don't indent after the last line in a template.
      var s = node.text.substring(0, node.text.length - 1);
      write(s.replaceAll('\n', '\n${indent}'));
      write('\n');
    } else {
      write(node.text.replaceAll('\n', '\n${indent}'));
    }
  }

  @override
  void visitVariable(VariableNode node) {
    var value = resolveValue(node.name);

    if (value is Function) {
      var context = LambdaContext(node, this);
      var valueFunction = value;
      value = valueFunction(context);
      context.close();
    }

    if (value == noSuchProperty) {
      if (!lenient) {
        throw error('Value was missing for variable tag: ${node.name}.', node);
      }
    } else {
      var valueString = (value == null) ? '' : value.toString();
      var output = !node.escape || !htmlEscapeValues
          ? valueString
          : _htmlEscape(valueString);
      write(output);
    }
  }

  @override
  void visitSection(SectionNode node) {
    if (node.inverse) {
      _renderInvSection(node);
    } else {
      _renderSection(node);
    }
  }

  //TODO can probably combine Inv and Normal to shorten.
  void _renderSection(SectionNode node) {
    var value = resolveValue(node.name);

    if (value == null) {
      // Do nothing.
    } else if (value is Iterable) {
      var idx = 0;
      for (final v in value) {
        _iterPath.add(idx);
        try {
          _renderWithValue(node, v);
        } finally {
          _iterPath.removeLast();
        }
        idx++;
      }
    } else if (value is Map) {
      _renderWithValue(node, value);
    } else if (value == true) {
      _renderWithValue(node, value);
    } else if (value == false) {
      // Do nothing.
    } else if (value == noSuchProperty) {
      if (!lenient) {
        throw error('Value was missing for section tag: ${node.name}.', node);
      }
    } else if (value is Function) {
      var context = LambdaContext(node, this);
      var output = value(context);
      context.close();
      if (output != null) write(output);
    } else {
      // Assume the value might have accessible member values via mirrors.
      _renderWithValue(node, value);
    }
  }

  void _renderInvSection(SectionNode node) {
    var value = resolveValue(node.name);

    if (value == null) {
      _renderWithValue(node, null);
    } else if ((value is Iterable && value.isEmpty) || value == false) {
      _renderWithValue(node, node.name);
    } else if (value == true || value is Map || value is Iterable) {
      // Do nothing.
    } else if (value == noSuchProperty) {
      if (lenient) {
        _renderWithValue(node, null);
      } else {
        throw error(
            'Value was missing for inverse section: ${node.name}.', node);
      }
    } else if (value is Function) {
      // Do nothing.
      //TODO in strict mode should this be an error?
    } else if (lenient) {
      // We consider all other values as 'true' in lenient mode. Since this
      // is an inverted section, we do nothing.
    } else {
      throw error(
          'Invalid value type for inverse section, '
          'section: ${node.name}, '
          'type: ${value.runtimeType}.',
          node);
    }
  }

  void _renderWithValue(SectionNode node, value) {
    push(value);
    node.visitChildren(this);
    pop();
  }

  @override
  void visitPartial(PartialNode node) {
    var partialName = node.name;
    var template = partialResolver == null
        ? null
        : (partialResolver!(partialName) as Template?);
    if (template != null) {
      var renderer = Renderer.partial(this, template, node.indent);
      var nodes = getTemplateNodes(template);
      renderer.render(nodes);
    } else if (lenient) {
      // do nothing
    } else {
      throw error('Partial not found: $partialName.', node);
    }
  }

  // Walks up the stack looking for the variable.
  // Handles dotted names of the form "a.b.c".
  Object? resolveValue(String name) {
    if (name == '.') {
      return _stack.last;
    }
    var parts = name.split('.');
    Object? object = noSuchProperty;
    for (var o in _stack.reversed) {
      object = _getNamedProperty(o, parts[0]);
      if (object != noSuchProperty) {
        break;
      }
    }
    for (var i = 1; i < parts.length; i++) {
      if (object == noSuchProperty) {
        return noSuchProperty;
      }
      object = _getNamedProperty(object, parts[i]);
    }
    return object;
  }

  // Returns the property of the given object by name. For a map,
  // which contains the key name, this is object[name]. For other
  // objects, this is object.name or object.name(). If no property
  // by the given name exists, this method returns noSuchProperty.
  Object? _getNamedProperty(dynamic object, dynamic name) {
    if (object is Map && object.containsKey(name)) return object[name];

    if (object is List && _integerTag.hasMatch(name)) {
      var index = int.parse(name);
      if (object.length > index) {
        return object[index];
      }
    }
    return noSuchProperty;
  }

  TemplateException error(String message, Node node) =>
      TemplateException(message, templateName, source, node.start);

  static const Map<int, String> _htmlEscapeMap = {
    _AMP: '&amp;',
    _LT: '&lt;',
    _GT: '&gt;',
    _QUOTE: '&quot;',
    _APOS: '&#x27;',
    _FORWARD_SLASH: '&#x2F;'
  };

  String _htmlEscape(String s) {
    var buffer = StringBuffer();
    var startIndex = 0;
    var i = 0;
    for (var c in s.runes) {
      if (c == _AMP ||
          c == _LT ||
          c == _GT ||
          c == _QUOTE ||
          c == _APOS ||
          c == _FORWARD_SLASH) {
        buffer.write(s.substring(startIndex, i));
        buffer.write(_htmlEscapeMap[c]);
        startIndex = i + 1;
      }
      i++;
    }
    buffer.write(s.substring(startIndex));
    return buffer.toString();
  }

  // ----- Filter pipeline -----

  @override
  void visitFilterPipeline(FilterPipelineNode node) {
    final value = evaluateFilterPipeline(node);
    if (value == null) return;
    final escaped = node.escape && htmlEscapeValues
        ? _htmlEscape(value)
        : value;
    write(escaped);
  }

  /// Evaluates a [FilterPipelineNode] and returns the resulting string, or
  /// null when the head resolves to a missing variable in non-lenient
  /// mode (mirrors the variable-not-found behaviour of [visitVariable]).
  String? evaluateFilterPipeline(FilterPipelineNode node) {
    final head = _resolveHead(node);
    if (head == null) return null;
    var value = head;
    for (final call in node.filters) {
      final filter = filters[call.name];
      if (filter == null) {
        throw UnknownFilterError(call.name, node.original);
      }
      if (filter.deferred) {
        final id = computeDeferredCallId(node, iterPath: _iterPath);
        final resolved = resolutions[id];
        if (resolved == null) {
          throw MissingDeferredResolutionError(id, call.name);
        }
        value = resolved;
      } else {
        final args = FilterArgs(
          positional: call.positional,
          named: call.named,
        );
        value = filter.renderSync(value, args, _filterContextFor(node));
      }
    }
    return value;
  }

  String? _resolveHead(FilterPipelineNode node) {
    if (node.headKind == HeadKind.literal) {
      return _preRenderLiteralMustache(node.head);
    }
    final value = resolveValue(node.head);
    if (value == noSuchProperty) {
      if (!lenient) {
        throw error(
          'Value was missing for variable tag: ${node.head}.',
          node,
        );
      }
      return '';
    }
    if (value is Function) {
      final ctx = LambdaContext(
        VariableNode(node.head, node.start, node.end, escape: node.escape),
        this,
      );
      final r = value(ctx);
      ctx.close();
      return r?.toString() ?? '';
    }
    return value?.toString() ?? '';
  }

  /// Resolves `{{varName}}` substitutions inside a literal head against
  /// the current variable context. Anything else (sections, dotted
  /// accessors with method-style invocation, etc.) is left as-is.
  String _preRenderLiteralMustache(String literal) {
    return literal.replaceAllMapped(_innerMustache, (m) {
      final key = m.group(1)!;
      final value = resolveValue(key);
      if (value == noSuchProperty) return m.group(0)!;
      return value?.toString() ?? '';
    });
  }

  FilterContext _filterContextFor(FilterPipelineNode node) {
    final pos = computeLineCol(source, node.start);
    return FilterContext(
      vars: _flattenVars(),
      line: pos.line,
      column: pos.column,
      inline: !_tagOnOwnLine(node),
    );
  }

  Map<String, Object?> _flattenVars() {
    if (_stack.isEmpty) return const {};
    final last = _stack.last;
    if (last is Map) {
      return Map<String, Object?>.from(last);
    }
    return const {};
  }

  bool _tagOnOwnLine(FilterPipelineNode node) {
    var i = node.start - 1;
    while (i >= 0) {
      final c = source[i];
      if (c == '\n') break;
      if (c != ' ' && c != '\t' && c != '\r') return false;
      i--;
    }
    var j = node.end;
    while (j < source.length) {
      final c = source[j];
      if (c == '\n') break;
      if (c != ' ' && c != '\t' && c != '\r') return false;
      j++;
    }
    return true;
  }

  /// Stable identifier for a deferred call.
  ///
  /// Combines the AST node's source position with the current section
  /// iteration path (`iterPath`). When the same FilterPipelineNode is
  /// visited at different iterations of an enclosing section, each
  /// iteration gets a distinct id so it can be resolved independently.
  ///
  /// `iterPath` is supplied by the caller (Renderer or
  /// [DeferredCallCollector] tracks it as it walks the tree). Both
  /// passes walk the same template with the same vars, so the indices
  /// match and the ids align.
  static DeferredCallId computeDeferredCallId(
    FilterPipelineNode node, {
    List<int> iterPath = const [],
  }) {
    final iterSuffix =
        iterPath.isEmpty ? '' : ':iter${iterPath.join(".")}';
    return DeferredCallId(
      'pos:${node.start}-${node.end}:${node.original.hashCode}$iterSuffix',
    );
  }

  static LineCol computeLineCol(String source, int offset) {
    var line = 1;
    var col = 1;
    for (var i = 0; i < offset && i < source.length; i++) {
      if (source[i] == '\n') {
        line++;
        col = 1;
      } else {
        col++;
      }
    }
    return LineCol(line, col);
  }
}

class LineCol {
  const LineCol(this.line, this.column);
  final int line;
  final int column;
}

const int _AMP = 38;
const int _LT = 60;
const int _GT = 62;
const int _QUOTE = 34;
const int _APOS = 39;
const int _FORWARD_SLASH = 47;
const int _NEWLINE = 10;

/// A renderer that collects output as raw bytes (List<int>).
/// Text is UTF-8 encoded, and binary values (Uint8List / List<int>)
/// are written directly without any string conversion.
class BinaryRenderer extends Renderer {
  final List<List<int>> _segments = [];

  BinaryRenderer(
    List stack,
    bool lenient,
    bool htmlEscapeValues,
    PartialResolver? partialResolver,
    String? templateName,
    String source, {
    Map<String, MustachexFilter> filters = const {},
    Map<DeferredCallId, String> resolutions = const {},
  }) : super(
          StringBuffer(),
          stack,
          lenient,
          htmlEscapeValues,
          partialResolver,
          templateName,
          '',
          source,
          filters: filters,
          resolutions: resolutions,
        );

  /// Collects all segments into a single flat List<int>.
  List<int> collectBytes() {
    // Flush any leftover text from the StringBuffer sink
    _flushTextSink();
    final result = <int>[];
    for (final segment in _segments) {
      result.addAll(segment);
    }
    return result;
  }

  /// Flushes the current StringBuffer contents as a UTF-8 segment.
  void _flushTextSink() {
    final text = sink.toString();
    if (text.isNotEmpty) {
      _segments.add(utf8.encode(text));
      // Clear the StringBuffer by replacing it with a new write
      (sink as StringBuffer).clear();
    }
  }

  @override
  void visitVariable(VariableNode node) {
    var value = resolveValue(node.name);

    if (value is Function) {
      var context = LambdaContext(node, this);
      var valueFunction = value;
      value = valueFunction(context);
      context.close();
    }

    if (value == noSuchProperty) {
      if (!lenient) {
        throw error('Value was missing for variable tag: ${node.name}.', node);
      }
    } else if (value is Uint8List) {
      // Write raw binary data directly
      _flushTextSink();
      _segments.add(value);
    } else if (value is List<int>) {
      // Write raw binary data directly
      _flushTextSink();
      _segments.add(List<int>.from(value));
    } else {
      var valueString = (value == null) ? '' : value.toString();
      var output = !node.escape || !htmlEscapeValues
          ? valueString
          : _htmlEscape(valueString);
      write(output);
    }
  }
}
