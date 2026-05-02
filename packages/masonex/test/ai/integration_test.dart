// ignore_for_file: lines_longer_than_80_chars

import 'dart:io';

import 'package:masonex/src/ai/integration.dart';
import 'package:masonex/src/ai/provider/builtin/mock.dart';
import 'package:masonex/src/render.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('runAiPass with mock provider', () {
    late Directory tmp;
    late String brickRoot;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('masonex_ai_int_');
      brickRoot = tmp.path;
      Directory(p.join(brickRoot, 'brick_test')).createSync();
      File(p.join(brickRoot, 'brick_test', 'ai_fixtures.yaml'))
          .writeAsStringSync('''
fixtures:
  - match: "the FIFA winner"
    output: "Argentina"
  - match: "describe"
    output: "A simple describer"
''');
    });

    tearDown(() {
      tmp.deleteSync(recursive: true);
    });

    test('rewrites and resolves a simple AI tag', () async {
      const src = 'Champion: {{ "the FIFA winner" | ai(expect: word) }}.';
      final result = await runAiPass(
        src,
        vars: const {},
        options: AiRenderOptions(
          brickRoot: brickRoot,
          relativePath: 'inline.txt',
          useMockProvider: true,
          cacheRootOverride: p.join(brickRoot, '.cache', 'ai'),
        ),
      );
      expect(result.injectedVars.values.single, 'Argentina');
      expect(result.source, contains('{{{__masonex_ai_0}}}'));
    });

    test('two-pass render produces final string with post-filters', () async {
      const src =
          'Champion: {{ "the FIFA winner" | ai(expect: word) | upperCase }}.';
      final out = await src.render(
        const {},
        aiOptions: AiRenderOptions(
          brickRoot: brickRoot,
          relativePath: 'inline.txt',
          useMockProvider: true,
          cacheRootOverride: p.join(brickRoot, '.cache', 'ai'),
        ),
      );
      expect(out.trim(), 'Champion: ARGENTINA.');
    });

    test('cache hit on second run', () async {
      const src = 'X: {{ "describe me" | ai(expect: line) }}';
      final cacheRoot = p.join(brickRoot, '.cache', 'ai');
      // First run populates cache.
      final r1 = await runAiPass(
        src,
        vars: const {},
        options: AiRenderOptions(
          brickRoot: brickRoot,
          relativePath: 'inline.txt',
          useMockProvider: true,
          cacheRootOverride: cacheRoot,
        ),
      );
      expect(r1.resolutions.single.fromCache, isFalse);

      // Second run should hit cache.
      final r2 = await runAiPass(
        src,
        vars: const {},
        options: AiRenderOptions(
          brickRoot: brickRoot,
          relativePath: 'inline.txt',
          useMockProvider: true,
          cacheRootOverride: cacheRoot,
        ),
      );
      expect(r2.resolutions.single.fromCache, isTrue);
    });

    test('atomicity: missing fixture aborts whole render', () async {
      const src =
          '{{ "the FIFA winner" | ai }} and {{ "no fixture for me" | ai }}';
      await expectLater(
        runAiPass(
          src,
          vars: const {},
          options: AiRenderOptions(
            brickRoot: brickRoot,
            relativePath: 'inline.txt',
            useMockProvider: true,
            cacheRootOverride: p.join(brickRoot, '.cache', 'ai'),
          ),
        ),
        throwsA(anything),
      );
    });

    test('lenient mode produces MOCK_OUTPUT for unknown prompts', () async {
      const src = '{{ "totally unknown prompt" | ai }}';
      final r = await runAiPass(
        src,
        vars: const {},
        options: AiRenderOptions(
          brickRoot: brickRoot,
          relativePath: 'inline.txt',
          useMockProvider: true,
          mockMode: MockMode.lenient,
          cacheRootOverride: p.join(brickRoot, '.cache', 'ai'),
        ),
      );
      expect(r.resolutions.single.value, 'MOCK_OUTPUT');
    });
  });
}
