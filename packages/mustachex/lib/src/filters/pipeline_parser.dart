// ignore_for_file: public_member_api_docs, parameter_assignments

import 'filter_call.dart';
import 'pipeline_value.dart';

/// Thrown when a tag containing pipeline syntax cannot be parsed.
class PipelineSyntaxException implements Exception {
  PipelineSyntaxException(this.tagOriginal, this.reason);
  final String tagOriginal;
  final String reason;
  @override
  String toString() =>
      'Invalid pipeline syntax in tag "$tagOriginal": $reason';
}

/// Parses the contents of a Mustache tag (the part between `{{` and `}}`)
/// into a head + filter chain.
///
/// Returns null if the tag does not contain pipeline syntax (no `|` or
/// `.<ident>(`); callers fall back to the legacy variable path.
class PipelineParser {
  PipelineParser(this._source) : _pos = 0;

  factory PipelineParser.fromTag(String tagContent) =>
      PipelineParser(tagContent.trim());

  final String _source;
  int _pos;

  /// Quick check: does the tag content look like a pipeline?
  /// Used by callers to avoid invoking the full parser when not needed.
  static bool looksLikePipeline(String tagContent) {
    final trimmed = tagContent.trim();
    if (trimmed.isEmpty) return false;
    var i = 0;
    while (i < trimmed.length) {
      final c = trimmed[i];
      if (c == '|') return true;
      if (c == '"' || c == "'") {
        // Quoted literals always indicate a pipeline (heads are bare in
        // legacy syntax).
        return true;
      }
      if (c == '.') {
        var j = i + 1;
        while (j < trimmed.length && _isWs(trimmed[j])) {
          j++;
        }
        if (j >= trimmed.length) return false;
        if (!_isIdentStart(trimmed[j])) return false;
        while (j < trimmed.length && _isIdentChar(trimmed[j])) {
          j++;
        }
        while (j < trimmed.length && _isWs(trimmed[j])) {
          j++;
        }
        if (j < trimmed.length && trimmed[j] == '(') return true;
      }
      i++;
    }
    return false;
  }

  /// Result of parsing.
  ParsedPipeline parse() {
    final original = _source;
    if (original.isEmpty) {
      throw PipelineSyntaxException(original, 'empty tag content');
    }

    _skipWs();
    final head = _parseHead();
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
        throw PipelineSyntaxException(
          original,
          'unexpected character "$c" at position $_pos',
        );
      }
    }

    return ParsedPipeline(
      head: head.value,
      headKind: head.kind,
      filters: filters,
      original: original,
    );
  }

  // -------- Head parsing --------

  _Head _parseHead() {
    if (_pos >= _source.length) {
      throw PipelineSyntaxException(_source, 'pipeline head is empty');
    }
    final c = _source[_pos];
    if (c == '"' || c == "'") {
      return _Head(_readStringLiteral(c), HeadKind.literal);
    }
    final start = _pos;
    while (_pos < _source.length) {
      final ch = _source[_pos];
      if (ch == '|') break;
      if (ch == '.' && _looksLikeDotFilter(_pos)) break;
      _pos++;
    }
    final raw = _source.substring(start, _pos).trimRight();
    if (raw.isEmpty) {
      throw PipelineSyntaxException(_source, 'pipeline head is empty');
    }
    final isLiteral = _containsWhitespace(raw);
    return _Head(raw, isLiteral ? HeadKind.literal : HeadKind.variable);
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
      throw PipelineSyntaxException(
        original,
        'expected filter name after "|"',
      );
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
      throw PipelineSyntaxException(
        original,
        'expected filter name after "."',
      );
    }
    _skipWs();
    if (_pos >= _source.length || _source[_pos] != '(') {
      throw PipelineSyntaxException(
        original,
        'dot-filter "$name" must be followed by "()"',
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
      String? namedKey;
      final savedPos = _pos;
      if (_isIdentStart(_source[_pos])) {
        final ident = _peekIdentifier();
        var lookahead = _pos + ident.length;
        while (lookahead < _source.length && _isWs(_source[lookahead])) {
          lookahead++;
        }
        if (lookahead < _source.length && _source[lookahead] == ':') {
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
          throw PipelineSyntaxException(
            original,
            'named argument "$namedKey" provided more than once',
          );
        }
        named[namedKey] = value;
      } else {
        if (named.isNotEmpty) {
          throw PipelineSyntaxException(
            original,
            'positional arguments cannot follow named arguments',
          );
        }
        positional.add(value);
      }
      _skipWs();
      if (_pos >= _source.length) {
        throw PipelineSyntaxException(
          original,
          'unterminated argument list for "$name"',
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
      throw PipelineSyntaxException(
        original,
        'expected "," or ")" in argument list, got "${_source[_pos]}"',
      );
    }
    return FilterCall(name: name, positional: positional, named: named);
  }

  // -------- Value parsing --------

  PipelineValue _parseValue(String original) {
    if (_pos >= _source.length) {
      throw PipelineSyntaxException(original, 'expected value');
    }
    final c = _source[_pos];
    if (c == '"' || c == "'") return PvString(_readStringLiteral(c));
    if (c == '[') return _parseList(original);
    if (c == '/') return _parseRegex(original);
    if (c == '>' || c == '<') return _parseRangeBound(original);
    if (_isDigit(c) || c == '-' || c == '+') {
      return _parseNumberOrDuration(original);
    }
    if (_isIdentStart(c)) {
      final ident = _readIdentifier();
      if (ident == 'true') return const PvBool(true);
      if (ident == 'false') return const PvBool(false);
      return PvIdentifier(ident);
    }
    throw PipelineSyntaxException(
      original,
      'unexpected character "$c" while parsing value at $_pos',
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
        throw PipelineSyntaxException(original, 'unterminated list');
      }
      if (_source[_pos] == ',') {
        _pos++;
        continue;
      }
      if (_source[_pos] == ']') {
        _pos++;
        break;
      }
      throw PipelineSyntaxException(
        original,
        'expected "," or "]" in list, got "${_source[_pos]}"',
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
      if (ch == '/') break;
      buf.write(ch);
      _pos++;
    }
    if (_pos >= _source.length) {
      throw PipelineSyntaxException(original, 'unterminated regex literal');
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
      throw PipelineSyntaxException(
        original,
        'range bound "$op" must be followed by "="',
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
      if (_pos + 1 < _source.length && _source[_pos + 1] == '.') {
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
      throw PipelineSyntaxException(original, 'expected integer at $_pos');
    }
    return int.parse(_source.substring(start, _pos));
  }

  // -------- Lexer helpers --------

  String _readStringLiteral(String quote) {
    _pos++;
    final buf = StringBuffer();
    while (_pos < _source.length) {
      final ch = _source[_pos];
      if (ch == r'\') {
        if (_pos + 1 >= _source.length) {
          throw PipelineSyntaxException(_source, 'unterminated string escape');
        }
        final next = _source[_pos + 1];
        switch (next) {
          case 'n':
            buf.write('\n');
            break;
          case 't':
            buf.write('\t');
            break;
          case 'r':
            buf.write('\r');
            break;
          case r'\':
            buf.write(r'\');
            break;
          case '"':
            buf.write('"');
            break;
          case "'":
            buf.write("'");
            break;
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
    throw PipelineSyntaxException(_source, 'unterminated string literal');
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
      throw PipelineSyntaxException(
        original,
        'expected "$expected" at position $_pos',
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
    return _isIdentStart(c) || _isDigit(c) || code == 0x2D;
  }

  static bool _containsWhitespace(String s) {
    for (var i = 0; i < s.length; i++) {
      if (_isWs(s[i])) return true;
    }
    return false;
  }
}

class _Head {
  const _Head(this.value, this.kind);
  final String value;
  final HeadKind kind;
}

/// AST-level result of parsing. Used both by the runtime parser and by
/// callers that want to inspect a tag without going through the renderer.
class ParsedPipeline {
  ParsedPipeline({
    required this.head,
    required this.headKind,
    required this.filters,
    required this.original,
  });

  final String head;
  final HeadKind headKind;
  final List<FilterCall> filters;
  final String original;
}
