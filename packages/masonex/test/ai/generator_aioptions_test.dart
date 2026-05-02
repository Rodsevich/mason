// ignore_for_file: lines_longer_than_80_chars

import 'dart:io';

import 'package:masonex/masonex.dart';
import 'package:masonex/src/ai/integration.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Verifies that MasonexGenerator.generate() honours [AiRenderOptions] —
/// the same path `mason make` exercises.
void main() {
  group('MasonexGenerator with AiRenderOptions (mock provider)', () {
    late Directory tmpRoot;
    late Directory brickDir;
    late Directory outDir;

    setUp(() async {
      tmpRoot = Directory.systemTemp.createTempSync('masonex_gen_ai_');
      brickDir = Directory(p.join(tmpRoot.path, 'brick'))
        ..createSync(recursive: true);
      outDir = Directory(p.join(tmpRoot.path, 'out'))
        ..createSync(recursive: true);

      // Minimal brick.yaml.
      File(p.join(brickDir.path, 'brick.yaml')).writeAsStringSync('''
name: ai_smoke
description: smoke
version: 0.1.0+1
environment:
  mason: ^0.1.2
vars: {}
''');

      // __brick__/ with a single AI-bearing template.
      Directory(p.join(brickDir.path, '__brick__')).createSync();
      File(p.join(brickDir.path, '__brick__', 'output.txt'))
          .writeAsStringSync(
        'Champion: {{ "the FIFA winner" | ai(expect: word) | upperCase }}.',
      );

      // brick_test/ai_fixtures.yaml for the mock provider.
      Directory(p.join(brickDir.path, 'brick_test')).createSync();
      File(p.join(brickDir.path, 'brick_test', 'ai_fixtures.yaml'))
          .writeAsStringSync('''
fixtures:
  - match: "the FIFA winner"
    output: "Argentina"
''');
    });

    tearDown(() {
      tmpRoot.deleteSync(recursive: true);
    });

    test('renders a brick end-to-end through generate() with mock provider',
        () async {
      final generator = await MasonexGenerator.fromBrick(
        Brick.path(brickDir.path),
      );
      final target = DirectoryGeneratorTarget(outDir);

      final files = await generator.generate(
        target,
        aiOptions: AiRenderOptions(
          brickRoot: brickDir.path,
          useMockProvider: true,
          brickName: 'ai_smoke',
          brickVersion: '0.1.0+1',
          cacheRootOverride: p.join(tmpRoot.path, '.cache'),
        ),
      );

      expect(files, isNotEmpty);
      final out = File(p.join(outDir.path, 'output.txt'));
      expect(out.existsSync(), isTrue);
      expect(out.readAsStringSync().trim(), 'Champion: ARGENTINA.');
    });
  });
}
