// ignore_for_file: lines_longer_than_80_chars

import 'dart:io';

import 'package:masonex/src/ai/integration.dart';
import 'package:masonex/src/render.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// End-to-end smoke test: renders every file under `bricks/ai_codegen_example/__brick__/`
/// using the mock provider and the canned fixtures shipped with the brick.
void main() {
  group('reference brick: ai_codegen_example', () {
    final repoRoot = _findRepoRoot();
    final brickRoot = p.join(repoRoot, 'bricks', 'ai_codegen_example');
    final brickDir = Directory(p.join(brickRoot, '__brick__'));

    test('exists', () {
      expect(brickDir.existsSync(), isTrue,
          reason: 'reference brick missing at ${brickDir.path}');
    });

    test('renders every template file with mock provider', () async {
      final files = brickDir
          .listSync(recursive: true)
          .whereType<File>()
          .toList();
      expect(files, isNotEmpty);

      final tmpCache = Directory.systemTemp.createTempSync('masonex_ref_');
      addTearDown(() => tmpCache.deleteSync(recursive: true));

      for (final file in files) {
        final source = await file.readAsString();
        final rendered = await source.render(
          const {'className': 'FooRepository', 'domain': 'orders'},
          aiOptions: AiRenderOptions(
            brickRoot: brickRoot,
            relativePath: p.relative(file.path, from: brickDir.parent.path),
            useMockProvider: true,
            cacheRootOverride: p.join(tmpCache.path, '.cache'),
          ),
        );
        // Sanity: no AI tag should remain unresolved in the output.
        expect(
          rendered,
          isNot(contains('| ai')),
          reason: 'unresolved AI tag in $file',
        );
        expect(
          rendered,
          isNot(contains('__masonex_ai_')),
          reason: 'unresolved synthetic in $file',
        );
        expect(rendered.trim(), isNotEmpty);
      }
    });
  });
}

String _findRepoRoot() {
  var dir = Directory.current;
  while (true) {
    if (Directory(p.join(dir.path, 'bricks')).existsSync() &&
        File(p.join(dir.path, 'pubspec.yaml')).existsSync()) {
      return dir.path;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError('Could not locate repo root from ${Directory.current.path}');
    }
    dir = parent;
  }
}
