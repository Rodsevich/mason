// ignore_for_file: lines_longer_than_80_chars

import 'package:masonex/src/ai/pipeline/parser.dart';
import 'package:masonex/src/ai/pipeline/pipeline_node.dart';
import 'package:masonex/src/ai/validation/post_processors.dart';
import 'package:masonex/src/ai/validation/validators.dart';
import 'package:test/test.dart';

FilterCall _aiCall(String tag) {
  final node = PipelineParser.fromTag(tag).parse()!;
  return node.filters.firstWhere((f) => f.name == 'ai');
}

void main() {
  group('validateAiOutput', () {
    test('expect:word passes single word', () {
      final r = validateAiOutput('Argentina', _aiCall('"x" | ai(expect: word)'));
      expect(r.ok, isTrue);
    });

    test('expect:word fails on whitespace', () {
      final r = validateAiOutput(
        'Argentina!',
        _aiCall(r'"x" | ai(expect: word, match: /^[A-Za-z]+$/)'),
      );
      expect(r.ok, isFalse);
    });

    test('expect:json passes valid JSON', () {
      final r = validateAiOutput(
        '{"a":1}',
        _aiCall('"x" | ai(expect: json)'),
      );
      expect(r.ok, isTrue);
    });

    test('expect:json fails invalid JSON', () {
      final r =
          validateAiOutput('not-json', _aiCall('"x" | ai(expect: json)'));
      expect(r.ok, isFalse);
    });

    test('lines int constraint', () {
      final ok = validateAiOutput(
        'one\ntwo',
        _aiCall('"x" | ai(lines: 2)'),
      );
      expect(ok.ok, isTrue);
      final fail = validateAiOutput(
        'only one',
        _aiCall('"x" | ai(lines: 2)'),
      );
      expect(fail.ok, isFalse);
    });

    test('oneOf check', () {
      final ok = validateAiOutput(
        'red',
        _aiCall('"x" | ai(oneOf: [red, green, blue])'),
      );
      expect(ok.ok, isTrue);
      final fail = validateAiOutput(
        'yellow',
        _aiCall('"x" | ai(oneOf: [red, green, blue])'),
      );
      expect(fail.ok, isFalse);
    });

    test('forbid token list', () {
      final fail = validateAiOutput(
        'this contains password',
        _aiCall('"x" | ai(forbid: [password, secret])'),
      );
      expect(fail.ok, isFalse);
    });
  });

  group('post processors', () {
    test('stripFences removes ```dart fences', () {
      const input = '```dart\nclass Foo {}\n```';
      expect(stripFences(input), 'class Foo {}');
    });

    test('stripFences leaves no-fence input alone', () {
      expect(stripFences('no fences here'), 'no fences here');
    });

    test('applyCase forces snake', () {
      expect(applyCase('FooBarBaz', 'snake'), 'foo_bar_baz');
    });
  });
}
