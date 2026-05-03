// ignore_for_file: public_member_api_docs

import '../filters/filter_call.dart';
import '../filters/mustachex_filter.dart';
import 'node.dart';
import 'renderer.dart';

/// Walks the AST to collect every deferred filter call. Pure: no
/// rendering, no provider invocation.
///
/// Implements [Visitor] but ignores text/section/partial/variable nodes —
/// it only inspects [FilterPipelineNode]s.
class DeferredCallCollector extends Visitor {
  DeferredCallCollector({
    required this.stack,
    required this.filters,
    required this.source,
    required this.lenient,
  });

  final List stack;
  final Map<String, MustachexFilter> filters;
  final String source;
  final bool lenient;

  final List<DeferredCall> calls = [];

  /// Mirror of [Renderer]'s `_iterPath`: the indices of enclosing
  /// section iterations at the current visit position. Both visitors
  /// walk the same tree with the same vars, so the indices align —
  /// that's what makes the [DeferredCallId]s match across passes.
  final List<int> _iterPath = <int>[];

  @override
  void visitText(TextNode node) {}

  @override
  void visitVariable(VariableNode node) {}

  @override
  void visitSection(SectionNode node) {
    if (node.inverse) {
      _visitInverseSection(node);
      return;
    }
    final value = _lookupVar(node.name);
    if (value == null || value == false) return;
    if (value is Iterable) {
      var idx = 0;
      for (final v in value) {
        _iterPath.add(idx);
        stack.add(v);
        try {
          for (final child in node.children) {
            child.accept(this);
          }
        } finally {
          stack.removeLast();
          _iterPath.removeLast();
        }
        idx++;
      }
    } else if (value is Map || value == true) {
      stack.add(value);
      try {
        for (final child in node.children) {
          child.accept(this);
        }
      } finally {
        stack.removeLast();
      }
    } else {
      // Other truthy values (Strings/numbers) — push and recurse.
      stack.add(value);
      try {
        for (final child in node.children) {
          child.accept(this);
        }
      } finally {
        stack.removeLast();
      }
    }
  }

  void _visitInverseSection(SectionNode node) {
    final value = _lookupVar(node.name);
    final isFalsy = value == null
        || value == false
        || (value is Iterable && value.isEmpty);
    if (!isFalsy) return;
    for (final child in node.children) {
      child.accept(this);
    }
  }

  @override
  void visitPartial(PartialNode node) {}

  @override
  void visitFilterPipeline(FilterPipelineNode node) {
    final headValue = _resolveHead(node);
    final ctx = _filterContextFor(node);
    final preFilters = <FilterCall>[];

    for (final call in node.filters) {
      final filter = filters[call.name];
      if (filter == null) {
        throw UnknownFilterError(call.name, node.original);
      }
      if (filter.deferred) {
        final post = node.filters
            .skip(node.filters.indexOf(call) + 1)
            .map((c) => c.name)
            .toList(growable: false);
        calls.add(
          DeferredCall(
            id: Renderer.computeDeferredCallId(node, iterPath: _iterPath),
            filterName: call.name,
            headValue: _applyPre(headValue, preFilters, ctx),
            headKind: node.headKind,
            args: FilterArgs(
              positional: call.positional,
              named: call.named,
            ),
            context: ctx,
            postFilters: post,
          ),
        );
        // We collect only the FIRST deferred filter per pipeline; any
        // additional deferred filters in the same chain would require
        // sequencing and are out of scope for v2.0.
        return;
      }
      preFilters.add(call);
    }
  }

  String _applyPre(
    String headValue,
    List<FilterCall> pre,
    FilterContext ctx,
  ) {
    var v = headValue;
    for (final call in pre) {
      final f = filters[call.name];
      if (f == null) continue;
      v = f.renderSync(
        v,
        FilterArgs(positional: call.positional, named: call.named),
        ctx,
      );
    }
    return v;
  }

  String _resolveHead(FilterPipelineNode node) {
    if (node.headKind == HeadKind.literal) {
      return _preRenderLiteralMustache(node.head);
    }
    final value = _lookupVar(node.head);
    return value?.toString() ?? '';
  }

  Object? _lookupVar(String name) {
    if (name == '.') return stack.isEmpty ? null : stack.last;
    final parts = name.split('.');
    Object? object;
    for (final o in stack.reversed) {
      object = _getProp(o, parts.first);
      if (object != null) break;
    }
    for (var i = 1; i < parts.length; i++) {
      if (object == null) return null;
      object = _getProp(object, parts[i]);
    }
    return object;
  }

  Object? _getProp(dynamic o, String name) {
    if (o is Map && o.containsKey(name)) return o[name];
    return null;
  }

  static final RegExp _innerMustache =
      RegExp(r'\{\{\s*(\.|[a-zA-Z_][a-zA-Z0-9_.-]*)\s*\}\}');

  String _preRenderLiteralMustache(String literal) {
    return literal.replaceAllMapped(_innerMustache, (m) {
      final key = m.group(1)!;
      final v = _lookupVar(key);
      return v?.toString() ?? m.group(0)!;
    });
  }

  FilterContext _filterContextFor(FilterPipelineNode node) {
    final pos = Renderer.computeLineCol(source, node.start);
    return FilterContext(
      vars: stack.isNotEmpty && stack.last is Map
          ? Map<String, Object?>.from(stack.last as Map)
          : const {},
      line: pos.line,
      column: pos.column,
      inline: !_tagOnOwnLine(node),
    );
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
}
