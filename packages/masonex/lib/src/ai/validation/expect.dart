// ignore_for_file: public_member_api_docs, lines_longer_than_80_chars

/// Maps an `expect:` parameter to the natural-language hint sent to the AI
/// inside `<expected_shape>`.
String expectedShapeFor(String? expect, {String? caseHint}) {
  switch (expect) {
    case null:
      return 'no specific shape; return the value verbatim';
    case 'word':
      return 'a single word, no whitespace, no punctuation, no markdown, '
          'no quotes';
    case 'line':
      return 'a single line of text, no newlines, no markdown';
    case 'sentence':
      return 'a single sentence ending with a period';
    case 'paragraph':
      return 'a single paragraph (multiple sentences allowed but no blank '
          'lines)';
    case 'json':
      return 'raw valid JSON, no markdown fences, no surrounding text';
    case 'yaml':
      return 'raw valid YAML, no markdown fences, no surrounding text';
    case 'identifier':
      final caseDesc =
          caseHint == null ? '' : ' formatted as $caseHint';
      return 'a single programming identifier$caseDesc, no whitespace';
    case 'number':
      return 'a numeric value (integer or decimal), no surrounding text';
    case 'boolean':
      return 'either "true" or "false" (lowercase), nothing else';
    case 'enum':
      return 'exactly one of the allowed values listed under <constraints>';
    case 'raw':
      return 'raw text, no markdown fences, no explanation';
    default:
      if (expect.startsWith('code:')) {
        final lang = expect.substring('code:'.length);
        return 'a self-contained code snippet in $lang, '
            'no markdown fences';
      }
      return 'value of shape "$expect"';
  }
}
