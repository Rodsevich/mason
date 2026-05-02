/// {{ "Write a one-line dartdoc for class {{className}} that handles {{domain}}." | ai(expect: line, max_chars: 120) }}
class {{className}} {
  /// {{ "Spanish-language tagline for the {{domain}} {{className}}." | ai(expect: sentence, max_chars: 120) }}
  static const tagline =
      '{{ "One short marketing line for the {{domain}} {{className}}" | ai(expect: line, max_chars: 80) }}';

  /// Returns a fixture id for tests.
  static const fixtureId =
      '{{ "Generate a unique kebab-case id for {{className}}" | ai(expect: identifier, case: kebab, max_chars: 40) }}';
}
