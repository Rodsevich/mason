@pragma('masonex:header', {
  Task: '{{taskName.pascalCase()}}',
})
library;

/// {{ "Write a one-line dartdoc for {{taskName}}, a taskflow Task." | ai(expect: line, max_chars: 120) }}
class Task {
  const Task({required this.id, required this.title});

  /// Stable kebab-case id used in URLs.
  static const slug =
      '{{ "Generate a unique kebab-case slug for {{taskName}}" | ai(expect: identifier, case: kebab, max_chars: 40) }}';

  /// Marketing tagline aimed at the chosen {{audience}}. Built from
  /// two nested `| ai` calls: the outer call uses the inner one as the
  /// concrete prompt, demonstrating composition.
  static const tagline =
      '{{ "{{ \"Compose a one-sentence prompt asking for a tagline targeted at {{audience}} for {{taskName}}\" | ai(expect: line, max_chars: 120) }}" | ai(expect: sentence, max_chars: 120) }}';

  final String id;
  final String title;
}
