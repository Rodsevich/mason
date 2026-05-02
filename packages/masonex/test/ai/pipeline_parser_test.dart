// ignore_for_file: lines_longer_than_80_chars

import 'package:masonex/src/ai/errors.dart';
import 'package:masonex/src/ai/pipeline/parser.dart';
import 'package:masonex/src/ai/pipeline/pipeline_node.dart';
import 'package:test/test.dart';

void main() {
  group('PipelineParser', () {
    test('returns null for plain variable tag', () {
      final node = PipelineParser.fromTag('name').parse();
      expect(node, isNull);
    });

    test('returns null for empty tag', () {
      final node = PipelineParser.fromTag('').parse();
      expect(node, isNull);
    });

    test('parses pipe with single filter', () {
      final node = PipelineParser.fromTag('name | uppercase').parse()!;
      expect(node.head, 'name');
      expect(node.headKind, HeadKind.variable);
      expect(node.filters.single.name, 'uppercase');
    });

    test('parses dotted filter', () {
      final node = PipelineParser.fromTag('name.uppercase()').parse()!;
      expect(node.head, 'name');
      expect(node.filters.single.name, 'uppercase');
    });

    test('treats quoted head as literal', () {
      final node =
          PipelineParser.fromTag('"campeón mundial" | ai').parse()!;
      expect(node.head, 'campeón mundial');
      expect(node.headKind, HeadKind.literal);
      expect(node.filters.single.name, 'ai');
    });

    test('treats unquoted-with-spaces head as literal', () {
      final node =
          PipelineParser.fromTag('dime el campeon | ai').parse()!;
      expect(node.headKind, HeadKind.literal);
      expect(node.head, 'dime el campeon');
    });

    test('parses named args', () {
      final node = PipelineParser.fromTag(
        '"x" | ai(expect: word, retries: 2)',
      ).parse()!;
      final ai = node.filters.firstWhere((f) => f.name == 'ai');
      expect((ai.named['expect']! as PvIdentifier).value, 'word');
      expect((ai.named['retries']! as PvInt).value, 2);
    });

    test('parses string args with escapes', () {
      final node = PipelineParser.fromTag(
        r'"x" | ai(extra_context: "foo\"bar")',
      ).parse()!;
      final v = node.filters.first.named['extra_context']! as PvString;
      expect(v.value, 'foo"bar');
    });

    test('parses range args', () {
      final node = PipelineParser.fromTag('"x" | ai(lines: 1..3)').parse()!;
      final r = node.filters.first.named['lines']! as PvRange;
      expect(r.min, 1);
      expect(r.max, 3);
    });

    test('parses bool args', () {
      final node = PipelineParser.fromTag('"x" | ai(trim: false)').parse()!;
      expect(
        (node.filters.first.named['trim']! as PvBool).value,
        isFalse,
      );
    });

    test('parses duration args', () {
      final node = PipelineParser.fromTag('"x" | ai(timeout: 90s)').parse()!;
      expect(
        (node.filters.first.named['timeout']! as PvDuration).value,
        const Duration(seconds: 90),
      );
    });

    test('parses regex args', () {
      final node =
          PipelineParser.fromTag(r'"x" | ai(match: /^[A-Z]+$/i)').parse()!;
      final r = node.filters.first.named['match']! as PvRegex;
      expect(r.pattern, r'^[A-Z]+$');
      expect(r.flags, 'i');
    });

    test('mixes pipe and method notation', () {
      final node = PipelineParser.fromTag(
        'name.ai(expect: word) | uppercase',
      ).parse()!;
      expect(node.filters.map((f) => f.name).toList(), ['ai', 'uppercase']);
    });

    test('hasAi flag', () {
      final node = PipelineParser.fromTag('"x" | ai | uppercase').parse()!;
      expect(node.hasAi, isTrue);
      expect(node.postAiFilters.single.name, 'uppercase');
    });

    test('errors on unterminated string', () {
      expect(
        () => PipelineParser.fromTag('"x | ai').parse(),
        throwsA(isA<AiSyntaxError>()),
      );
    });

    test('rejects nested string literal in literal head (v1 limitation)', () {
      // Documents the known limitation: an inner `"es"` terminates the
      // outer string literal, so the parser fails fast instead of silently
      // truncating. Tracked for v2 in doc/ai/v2-rfc.md.
      expect(
        () => PipelineParser.fromTag(
          '"in {{ "es" | ai }}" | ai',
        ).parse(),
        throwsA(isA<AiSyntaxError>()),
      );
    });

    test('errors on positional after named', () {
      expect(
        () => PipelineParser.fromTag(
          '"x" | ai(expect: word, "extra")',
        ).parse(),
        throwsA(isA<AiSyntaxError>()),
      );
    });
  });
}
