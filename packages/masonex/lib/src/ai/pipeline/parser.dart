// ignore_for_file: public_member_api_docs, lines_longer_than_80_chars, parameter_assignments

import 'package:masonex/src/ai/errors.dart';
import 'package:masonex/src/ai/pipeline/pipeline_node.dart';

/// Parses the contents of a Mustache tag (the part between `{{` and `}}`)
/// into a [FilterPipelineNode].
///
/// Supports the masonex pipeline grammar:
///
///   tag        := head ( filterOp )*
///   head       := stringLiteral | identifier | bareLiteral
///   filterOp   := pipeFilter | dotFilter
///   pipeFilter := '|' WS identifier ( '(' args ')' )?
///   dotFilter  := '.' identifier '(' args ')'
///   args       := arg ( ',' arg )*
///   arg        := ( identifier ':' )? value
///   value      := stringLiteral | number | bool | identifier | duration |
///                 list | range | regex
///
/// Head resolution rules (semantic, not syntactic):
///
///   * If the head was quoted, it is always a [HeadKind.literal].
///   * If the head was unquoted with whitespace, it is a [HeadKind.literal]
///     (caller can warn).
///   * If the head was unquoted without whitespace, the caller is expected
///     to lookup the variable; if absent, it falls back to literal.
///
/// This parser is purely syntactic: it returns the head exactly as it was
/// written and reports its kind via [HeadKind]. Resolution of variable values
/// vs. literals happens upstream.
class PipelineParser {
  PipelineParser(this._source) : _pos = 0;

  factory PipelineParser.fromTag(String tagContent) =>
      PipelineParser(tagContent.trim());

  final String _source;
  int _pos;

  /// Returns null if the tag does not look like a pipeline tag (no `|` or
  /// `.<identifier>(` after the head). Otherwise returns the parsed AST.
  ///
  /// Throws [AiSyntaxError] on malformed pipeline syntax.
  FilterPipelineNode? parse() {
    final original = _source;
    if (original.isEmpty) return null;

    _skipWs();
    final headParse = _parseHead();
    if (headParse == null) return null;
    final (head, headKind, headHadFilters) = headParse;

    _skipWs();
    final filters = <FilterCall>[];

    while (_pos < _source.length) {
      _skipWs();
      if (_pos >= _source.length) break;
      final c = _source[_pos];
      if (c == '|') {
        _pos++;
        _skipWs();
        filters.add(_parsePipeFilter(original));
      } else if (c == '.') {
        _pos++;
        _skipWs();
        filters.add(_parseDotFilter(original));
      } else {
        throw AiSyntaxError(
          original,
          'Unexpected character "$c" at position $_pos.',
        );
      }
    }

    if (filters.isEmpty && !headHadFilters) {
      // No pipeline ops detected. Caller can decide if this is a plain mustache
      // tag (no rewriting needed).
      return null;
    }

    return FilterPipelineNode(
      head: head,
      headKind: headKind,
      filters: filters,
      original: original,
    );
  }

  // -------- Head parsing --------

  /// Returns (head, kind, alreadyConsumedDotFilter).
  /// The third element is true when the head was an identifier and we
  /// stopped at a `.` that begins a dot-filter (we don't want to misinterpret
  /// dotted identifiers, but masonex doesn't support dotted variable names
  /// in pipelines for now: `a.b` is treated as `a` then dot-filter `b()`
  /// only when followed by `(`).
  (String, HeadKind, bool)? _parseHead() {
    if (_pos >= _source.length) return null;
    final c = _source[_pos];

    if (c == '"' || c == "'") {
      final s = _readStringLiteral(c);
      return (s, HeadKind.literal, false);
    }

    // Read until first `|` or first `.<ident>(` (dot followed by identifier
    // followed by paren). Trailing whitespace is allowed.
    final start = _pos;
    while (_pos < _source.length) {
      final ch = _source[_pos];
      if (ch == '|') break;
      if (ch == '.' && _looksLikeDotFilter(_pos)) break;
      _pos++;
    }
    final raw = _source.substring(start, _pos).trimRight();
    if (raw.isEmpty) {
      throw AiSyntaxError(_source, 'Pipeline head is empty.');
    }
    // If the raw head contains whitespace, treat as literal.
    final isLiteral = _containsWhitespace(raw);
    return (raw, isLiteral ? HeadKind.literal : HeadKind.variable, false);
  }

  bool _looksLikeDotFilter(int dotPos) {
    var i = dotPos + 1;
    while (i < _source.length && _isWs(_source[i])) {
      i++;
    }
    if (i >= _source.length) return false;
    if (!_isIdentStart(_source[i])) return false;
    while (i < _source.length && _isIdentChar(_source[i])) {
      i++;
    }
    while (i < _source.length && _isWs(_source[i])) {
      i++;
    }
    return i < _source.length && _source[i] == '(';
  }

  // -------- Filter parsing --------

  FilterCall _parsePipeFilter(String original) {
    final name = _readIdentifier();
    if (name.isEmpty) {
      throw AiSyntaxError(original, 'Expected filter name after `|`.');
    }
    _skipWs();
    if (_pos < _source.length && _source[_pos] == '(') {
      return _parseFilterArgs(name, original);
    }
    return FilterCall(name: name);
  }

  FilterCall _parseDotFilter(String original) {
    final name = _readIdentifier();
    if (name.isEmpty) {
      throw AiSyntaxError(original, 'Expected filter name after `.`.');
    }
    _skipWs();
    if (_pos >= _source.length || _source[_pos] != '(') {
      throw AiSyntaxError(
        original,
        'Dot-filter `$name` must be followed by `()` (with optional args).',
      );
    }
    return _parseFilterArgs(name, original);
  }

  FilterCall _parseFilterArgs(String name, String original) {
    _expect('(', original);
    final positional = <PipelineValue>[];
    final named = <String, PipelineValue>{};
    _skipWs();
    if (_pos < _source.length && _source[_pos] == ')') {
      _pos++;
      return FilterCall(name: name);
    }
    while (true) {
      _skipWs();
      // Detect named arg: <ident> : ...
      final savedPos = _pos;
      String? namedKey;
      if (_isIdentStart(_source[_pos])) {
        final ident = _peekIdentifier();
        var lookahead = _pos + ident.length;
        while (lookahead < _source.length && _isWs(_source[lookahead])) {
          lookahead++;
        }
        if (lookahead < _source.length && _source[lookahead] == ':') {
          // Consume identifier and colon.
          _pos += ident.length;
          _skipWs();
          _expect(':', original);
          namedKey = ident;
        } else {
          _pos = savedPos;
        }
      }
      _skipWs();
      final value = _parseValue(original);
      if (namedKey != null) {
        if (named.containsKey(namedKey)) {
          throw AiSyntaxError(
            original,
            'Named argument `$namedKey` provided more than once.',
          );
        }
        named[namedKey] = value;
      } else {
        if (named.isNotEmpty) {
          throw AiSyntaxError(
            original,
            'Positional arguments cannot follow named arguments '
                'in `$name(...)`.',
          );
        }
        positional.add(value);
      }
      _skipWs();
      if (_pos >= _source.length) {
        throw AiSyntaxError(
          original,
          'Unterminated argument list for `$name`.',
        );
      }
      if (_source[_pos] == ',') {
        _pos++;
        continue;
      }
      if (_source[_pos] == ')') {
        _pos++;
        break;
      }
      throw AiSyntaxError(
        original,
        'Expected `,` or `)` in argument list for `$name`, '
            'got `${_source[_pos]}`.',
      );
    }
    return FilterCall(name: name, positional: positional, named: named);
  }

  // -------- Value parsing --------

  PipelineValue _parseValue(String original) {
    if (_pos >= _source.length) {
      throw AiSyntaxError(original, 'Expected value.');
    }
    final c = _source[_pos];
    if (c == '"' || c == "'") {
      return PvString(_readStringLiteral(c));
    }
    if (c == '[') {
      return _parseList(original);
    }
    if (c == '/') {
      return _parseRegex(original);
    }
    if (c == '>' || c == '<') {
      return _parseRangeBound(original);
    }
    if (_isDigit(c) || c == '-' || c == '+') {
      return _parseNumberOrDuration(original);
    }
    if (_isIdentStart(c)) {
      final ident = _readIdentifier();
      switch (ident) {
        case 'true':
          return const PvBool(true);
        case 'false':
          return const PvBool(false);
      }
      return PvIdentifier(ident);
    }
    throw AiSyntaxError(
      original,
      'Unexpected character `$c` while parsing value at position $_pos.',
    );
  }

  PvList _parseList(String original) {
    _expect('[', original);
    final values = <PipelineValue>[];
    _skipWs();
    if (_pos < _source.length && _source[_pos] == ']') {
      _pos++;
      return PvList(values);
    }
    while (true) {
      _skipWs();
      values.add(_parseValue(original));
      _skipWs();
      if (_pos >= _source.length) {
        throw AiSyntaxError(original, 'Unterminated list.');
      }
      if (_source[_pos] == ',') {
        _pos++;
        continue;
      }
      if (_source[_pos] == ']') {
        _pos++;
        break;
      }
      throw AiSyntaxError(
        original,
        'Expected `,` or `]` in list, got `${_source[_pos]}`.',
      );
    }
    return PvList(values);
  }

  PvRegex _parseRegex(String original) {
    _expect('/', original);
    final buf = StringBuffer();
    var escaped = false;
    while (_pos < _source.length) {
      final ch = _source[_pos];
      if (escaped) {
        buf.write(ch);
        escaped = false;
        _pos++;
        continue;
      }
      if (ch == r'\') {
        buf.write(ch);
        escaped = true;
        _pos++;
        continue;
      }
      if (ch == '/') {
        break;
      }
      buf.write(ch);
      _pos++;
    }
    if (_pos >= _source.length) {
      throw AiSyntaxError(original, 'Unterminated regex literal.');
    }
    _pos++; // consume closing /
    final flagsBuf = StringBuffer();
    while (_pos < _source.length && _isIdentChar(_source[_pos])) {
      flagsBuf.write(_source[_pos]);
      _pos++;
    }
    return PvRegex(buf.toString(), flagsBuf.toString());
  }

  PvRange _parseRangeBound(String original) {
    final op = _source[_pos];
    _pos++;
    if (_pos >= _source.length || _source[_pos] != '=') {
      throw AiSyntaxError(
        original,
        'Range bound `$op` must be followed by `=` (got `>=`/`<=`).',
      );
    }
    _pos++;
    _skipWs();
    final n = _readInt(original);
    if (op == '>') return PvRange(min: n);
    return PvRange(max: n);
  }

  PipelineValue _parseNumberOrDuration(String original) {
    final start = _pos;
    if (_source[_pos] == '+' || _source[_pos] == '-') _pos++;
    while (_pos < _source.length && _isDigit(_source[_pos])) {
      _pos++;
    }
    var isDouble = false;
    if (_pos < _source.length && _source[_pos] == '.') {
      // could be range `1..3` or decimal `1.5`. Disambiguate by next char.
      if (_pos + 1 < _source.length && _source[_pos + 1] == '.') {
        // Range.
        final lo = int.parse(_source.substring(start, _pos));
        _pos += 2;
        final hi = _readInt(original);
        return PvRange(min: lo, max: hi);
      }
      isDouble = true;
      _pos++;
      while (_pos < _source.length && _isDigit(_source[_pos])) {
        _pos++;
      }
    }
    final numText = _source.substring(start, _pos);
    // Optional duration unit.
    if (_pos < _source.length) {
      final unit = _source[_pos];
      if (unit == 's' || unit == 'm' || unit == 'h') {
        _pos++;
        final value = num.parse(numText);
        return PvDuration(_durationFor(value, unit));
      }
    }
    if (isDouble) return PvDouble(double.parse(numText));
    return PvInt(int.parse(numText));
  }

  Duration _durationFor(num value, String unit) {
    switch (unit) {
      case 's':
        return Duration(milliseconds: (value * 1000).round());
      case 'm':
        return Duration(seconds: (value * 60).round());
      case 'h':
        return Duration(minutes: (value * 60).round());
    }
    throw StateError('Unknown duration unit: $unit');
  }

  int _readInt(String original) {
    final start = _pos;
    if (_pos < _source.length &&
        (_source[_pos] == '+' || _source[_pos] == '-')) {
      _pos++;
    }
    while (_pos < _source.length && _isDigit(_source[_pos])) {
      _pos++;
    }
    if (start == _pos) {
      throw AiSyntaxError(original, 'Expected integer at position $_pos.');
    }
    return int.parse(_source.substring(start, _pos));
  }

  // -------- Lexer helpers --------

  String _readStringLiteral(String quote) {
    _pos++; // consume opening quote
    final buf = StringBuffer();
    while (_pos < _source.length) {
      final ch = _source[_pos];
      if (ch == r'\') {
        if (_pos + 1 >= _source.length) {
          throw AiSyntaxError(_source, 'Unterminated string escape.');
        }
        final next = _source[_pos + 1];
        switch (next) {
          case 'n':
            buf.write('\n');
          case 't':
            buf.write('\t');
          case 'r':
            buf.write('\r');
          case r'\':
            buf.write(r'\');
          case '"':
            buf.write('"');
          case "'":
            buf.write("'");
          default:
            buf.write(next);
        }
        _pos += 2;
        continue;
      }
      if (ch == quote) {
        _pos++;
        return buf.toString();
      }
      buf.write(ch);
      _pos++;
    }
    throw AiSyntaxError(_source, 'Unterminated string literal.');
  }

  String _readIdentifier() {
    if (_pos >= _source.length || !_isIdentStart(_source[_pos])) return '';
    final start = _pos;
    while (_pos < _source.length && _isIdentChar(_source[_pos])) {
      _pos++;
    }
    return _source.substring(start, _pos);
  }

  String _peekIdentifier() {
    if (_pos >= _source.length || !_isIdentStart(_source[_pos])) return '';
    var i = _pos;
    while (i < _source.length && _isIdentChar(_source[i])) {
      i++;
    }
    return _source.substring(_pos, i);
  }

  void _expect(String expected, String original) {
    if (_pos >= _source.length || _source[_pos] != expected) {
      throw AiSyntaxError(
        original,
        'Expected `$expected` at position $_pos.',
      );
    }
    _pos++;
  }

  void _skipWs() {
    while (_pos < _source.length && _isWs(_source[_pos])) {
      _pos++;
    }
  }

  static bool _isWs(String c) =>
      c == ' ' || c == '\t' || c == '\n' || c == '\r';

  static bool _isDigit(String c) {
    final code = c.codeUnitAt(0);
    return code >= 0x30 && code <= 0x39;
  }

  static bool _isIdentStart(String c) {
    if (c.isEmpty) return false;
    final code = c.codeUnitAt(0);
    return (code >= 0x41 && code <= 0x5A) ||
        (code >= 0x61 && code <= 0x7A) ||
        code == 0x5F;
  }

  static bool _isIdentChar(String c) {
    if (c.isEmpty) return false;
    final code = c.codeUnitAt(0);
    return _isIdentStart(c) ||
        _isDigit(c) ||
        code == 0x2D; // '-'
  }

  static bool _containsWhitespace(String s) {
    for (var i = 0; i < s.length; i++) {
      if (_isWs(s[i])) return true;
    }
    return false;
  }
}
