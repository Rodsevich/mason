import '../../mustache_template.dart';
import '../filters/mustachex_filter.dart';
import 'deferred_collector.dart';
import 'node.dart';
import 'parser.dart' as parser;
import 'renderer.dart';

/// A Template can be efficiently rendered multiple times with different
/// values.
class Template {
  factory Template(
    String source, {
    bool lenient,
    bool htmlEscapeValues,
    String name,
    PartialResolver? partialResolver,
    String delimiters,
    List<MustachexFilter> filters,
  }) = Template.fromSource;

  /// The constructor parses the template source and throws [TemplateException]
  /// if the syntax of the source is invalid.
  /// Tag names may only contain characters a-z, A-Z, 0-9, underscore, and minus,
  /// unless lenient mode is specified.
  Template.fromSource(
    String source, {
    bool lenient = false,
    bool htmlEscapeValues = true,
    String? name,
    PartialResolver? partialResolver,
    String delimiters = '{{ }}',
    List<MustachexFilter> filters = const [],
  })  : source = source,
        _nodes = parser.parse(source, lenient, name, delimiters),
        _lenient = lenient,
        _htmlEscapeValues = htmlEscapeValues,
        _name = name,
        _partialResolver = partialResolver,
        _filters = {for (final f in filters) f.name: f};

  final String source;
  final List<Node> _nodes;
  final bool _lenient;
  final bool _htmlEscapeValues;
  final String? _name;
  final PartialResolver? _partialResolver;
  final Map<String, MustachexFilter> _filters;

  String? get name => _name;

  /// Filters registered with this template (by name).
  Map<String, MustachexFilter> get filters => Map.unmodifiable(_filters);

  /// [values] can be a combination of Map, List, String. Any non-String object
  /// will be converted using toString(). Null values will cause a
  /// [TemplateException], unless lenient module is enabled.
  ///
  /// When [resolutions] is non-empty, deferred filter calls are resolved
  /// from it; otherwise an exception is thrown if any deferred call is
  /// reached during rendering.
  String renderString(
    values, {
    Map<DeferredCallId, String> resolutions = const {},
  }) {
    var buf = StringBuffer();
    render(values, buf, resolutions: resolutions);
    return buf.toString();
  }

  void render(
    values,
    StringSink sink, {
    Map<DeferredCallId, String> resolutions = const {},
  }) {
    var renderer = Renderer(
      sink,
      [values],
      _lenient,
      _htmlEscapeValues,
      _partialResolver,
      _name,
      '',
      source,
      filters: _filters,
      resolutions: resolutions,
    );
    renderer.render(_nodes);
  }

  /// Renders the template to raw bytes. Binary values (Uint8List / List<int>)
  /// are written directly without string conversion. Text is UTF-8 encoded.
  List<int> renderBytes(
    values, {
    Map<DeferredCallId, String> resolutions = const {},
  }) {
    var renderer = BinaryRenderer(
      [values],
      _lenient,
      _htmlEscapeValues,
      _partialResolver,
      _name,
      source,
      filters: _filters,
      resolutions: resolutions,
    );
    renderer.render(_nodes);
    return renderer.collectBytes();
  }

  /// Walks the AST and returns every deferred filter call observed (in
  /// document order). Pure: no rendering side effects.
  ///
  /// Throws [UnknownFilterError] if a filter name appears in the
  /// template but has not been registered with this Template.
  List<DeferredCall> collectDeferredCalls(values) {
    final collector = DeferredCallCollector(
      stack: [values],
      filters: _filters,
      source: source,
      lenient: _lenient,
    );
    for (final node in _nodes) {
      node.accept(collector);
    }
    return collector.calls;
  }
}

// Expose getter for nodes internally within this package.
List<Node> getTemplateNodes(Template template) => template._nodes;
