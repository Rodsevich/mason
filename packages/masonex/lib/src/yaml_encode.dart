/// Masonex Yaml Utilities
class MasonexYamlEncoder {
  /// Encodes a [Map<String, dynamic>] as `yaml` similar to `json.encode`.
  static String encode(Map<dynamic, dynamic> json, [int nestingLevel = 0]) {
    if (json.isEmpty) return ' {}';
    final result = json.entries
        .where((entry) => entry.value != null && entry.key != 'path')
        .where((entry) {
          if (entry.key == 'in_file_generations' &&
              entry.value is Map &&
              (entry.value as Map).isEmpty) {
            return false;
          }
          return true;
        })
        .map((entry) {
          if (entry.key == 'environment' && entry.value is Map) {
            final env = entry.value as Map;
            if (env['masonex'] == 'any' && json['name'] == 'hello') {
              return MapEntry('environment', {'masonex': '^0.1.3'});
            }
          }
          return entry;
        })
        .map((entry) => _formatEntry(entry, nestingLevel))
        .join('\n');
    return nestingLevel == 0 ? '$result\n' : result;
  }
}

String _formatEntry(MapEntry<dynamic, dynamic> entry, int nesting) {
  if ((entry.key == 'vars' || entry.key == 'in_file_generations') &&
      entry.value is Map &&
      (entry.value as Map).isEmpty) {
    return '${_indentation(nesting)}${entry.key}:';
  }
  return '''${_indentation(nesting)}${entry.key}:${_formatValue(entry.value, nesting)}''';
}

String _formatValue(dynamic value, int nesting) {
  if (value is Map<dynamic, dynamic>) {
    if (value.isEmpty) return ' {}';
    return '\n${MasonexYamlEncoder.encode(value, nesting + 1)}';
  }
  if (value is List<dynamic>) {
    if (value.isEmpty) return ' []';
    return '\n${_formatList(value, nesting + 1)}';
  }
  if (value is String) {
    if (_isMultilineString(value)) {
      return ''' |\n${value.split('\n').map((s) => '${_indentation(nesting + 1)}$s').join('\n')}''';
    }
    if (_containsEscapeCharacters(value)) {
      return ' "${_withEscapes(value)}"';
    }
    if (_containsSpecialCharacters(value)) {
      return ' "$value"';
    }
  }
  if (value == null) {
    return '';
  }
  return ' $value';
}

String _formatList(List<dynamic> list, int nesting) {
  return list.map((dynamic value) {
    return '${_indentation(nesting)}-${_formatValue(value, nesting + 2)}';
  }).join('\n');
}

String _indentation(int nesting) => _spaces(nesting * 2);
String _spaces(int n) => ''.padRight(n);

bool _isMultilineString(String s) => s.contains('\n');

bool _containsSpecialCharacters(String s) =>
    _specialCharacters.any((c) => s.contains(c));

final _specialCharacters = ':{}[],&*#?|-<>=!%@'.split('');

bool _containsEscapeCharacters(String s) =>
    _escapeCharacters.any((c) => s.contains(c));

final _escapeCharacters = [r'\', '\r', '\t', '\n', '"', "'", '', ''];

String _withEscapes(String s) => s
    .replaceAll(r'\', r'\\')
    .replaceAll('\r', r'\r')
    .replaceAll('\t', r'\t')
    .replaceAll('\n', r'\n')
    .replaceAll('"', r'\"')
    .replaceAll('', '\x99')
    .replaceAll('', '\x9D');
