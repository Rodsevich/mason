// ignore_for_file: public_member_api_docs, lines_longer_than_80_chars

/// Default exclusions applied to brick contents before they enter the
/// envelope. Brick authors can extend this list via `ai.context.exclude`
/// in `brick.yaml`.
const List<String> defaultPrivacyExcludeGlobs = [
  '.env',
  '.env.*',
  '*.pem',
  '*.key',
  'secrets/**',
  '**/secrets/**',
  '**/.git/**',
  '**/node_modules/**',
];

/// Lightweight glob matcher that supports `*`, `**`, and `?`. Sufficient
/// for the privacy checks done at envelope-build time; we do not depend on
/// `package:glob` to keep masonex's transitive footprint small.
class PrivacyMatcher {
  PrivacyMatcher(this.patterns)
      : _regexps = patterns.map(_compile).toList();

  final List<String> patterns;
  final List<RegExp> _regexps;

  bool isExcluded(String relativePath) {
    return _regexps.any((r) => r.hasMatch(relativePath));
  }

  static RegExp _compile(String glob) {
    final buf = StringBuffer('^');
    var i = 0;
    while (i < glob.length) {
      final c = glob[i];
      if (c == '*') {
        if (i + 1 < glob.length && glob[i + 1] == '*') {
          buf.write('.*');
          i += 2;
          if (i < glob.length && glob[i] == '/') i++;
          continue;
        }
        buf.write('[^/]*');
      } else if (c == '?') {
        buf.write('[^/]');
      } else if (RegExp(r'[.+(){}\[\]^$|\\]').hasMatch(c)) {
        buf
          ..write(r'\')
          ..write(c);
      } else {
        buf.write(c);
      }
      i++;
    }
    buf.write(r'$');
    return RegExp(buf.toString());
  }
}
