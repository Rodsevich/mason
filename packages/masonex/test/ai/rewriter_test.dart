// ignore_for_file: lines_longer_than_80_chars

import 'package:masonex/src/ai/pipeline/rewriter.dart';
import 'package:test/test.dart';

void main() {
  group('AiTagRewriter', () {
    test('leaves source untouched when no AI tags', () {
      const src = 'Hello {{name}} from {{place}}.';
      final result =
          AiTagRewriter(relativePath: 'a.txt', varsForPrompt: const {})
              .rewrite(src);
      expect(result.rewrittenSource, src);
      expect(result.requests, isEmpty);
    });

    test('rewrites AI tag to synthetic var', () {
      const src = 'Champion: {{ "the FIFA winner" | ai(expect: word) }}.';
      final result =
          AiTagRewriter(relativePath: 'a.txt', varsForPrompt: const {})
              .rewrite(src);
      expect(result.requests.length, 1);
      final req = result.requests.single;
      expect(req.prompt, 'the FIFA winner');
      expect(result.rewrittenSource,
          startsWith('Champion: {{{__masonex_ai_0}}}'));
      expect(req.inlineHint, isTrue);
    });

    test('pre-renders mustache substitutions inside literal prompt', () {
      const src =
          'Doc: {{ "doc para {{className}}" | ai(expect: line) }}.';
      final result = AiTagRewriter(
        relativePath: 'a.dart',
        varsForPrompt: const {'className': 'FooRepository'},
      ).rewrite(src);
      expect(result.requests.single.prompt, 'doc para FooRepository');
    });

    test('detects block tag (own line)', () {
      const src = 'header\n{{ "hello" | ai }}\nfooter';
      final r = AiTagRewriter(relativePath: '', varsForPrompt: const {})
          .rewrite(src);
      expect(r.requests.single.inlineHint, isFalse);
    });

    test('handles two AI tags with stable synthetic names', () {
      const src = '{{ "a" | ai }} and {{ "b" | ai }}';
      final r = AiTagRewriter(relativePath: '', varsForPrompt: const {})
          .rewrite(src);
      expect(r.requests.length, 2);
      expect(r.requests[0].syntheticVarName, '__masonex_ai_0');
      expect(r.requests[1].syntheticVarName, '__masonex_ai_1');
    });

    test('skips Mustache section/inverse tags', () {
      const src = '{{#section}}{{name}}{{/section}}';
      final r = AiTagRewriter(relativePath: '', varsForPrompt: const {})
          .rewrite(src);
      expect(r.requests, isEmpty);
      expect(r.rewrittenSource, src);
    });
  });
}
