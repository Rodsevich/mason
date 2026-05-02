// ignore_for_file: lines_longer_than_80_chars

import 'package:masonex/src/ai/pipeline/tag_finder.dart';
import 'package:test/test.dart';

void main() {
  group('TagFinder', () {
    test('finds simple tags', () {
      final tags =
          TagFinder('Hello {{name}}, welcome to {{place}}.').find().toList();
      expect(tags.length, 2);
      expect(tags[0].content, 'name');
      expect(tags[1].content, 'place');
    });

    test('finds triple-brace tags', () {
      final tags = TagFinder('{{{raw}}}').find().toList();
      expect(tags.single.openLen, 3);
      expect(tags.single.closeLen, 3);
      expect(tags.single.content, 'raw');
    });

    test('respects nested mustache inside quotes', () {
      const src = '{{ "doc para {{className}}" | ai }}';
      final tags = TagFinder(src).find().toList();
      expect(tags.length, 1);
      expect(tags.single.content.trim(), '"doc para {{className}}" | ai');
    });

    test('reports line and column', () {
      const src = 'a\nb {{x}} c';
      final t = TagFinder(src).find().single;
      expect(t.line, 2);
      expect(t.column, 3);
    });
  });
}
