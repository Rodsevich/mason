// ignore_for_file: lines_longer_than_80_chars

import 'dart:io';

import 'package:masonex/src/ai/integration.dart';
import 'package:masonex/src/render.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// End-to-end test for the canonical "section + AI per iteration" case:
///
/// ```mustache
/// {{#estadisticos}}
/// {{.}}: {{ "buscar {{.}} para {{pais}}" | ai(expect: word) }}
/// {{/estadisticos}}
/// ```
///
/// With `pais: "Argentina"` and `estadisticos: ["poblacion", "superficie"]`,
/// each iteration must produce a distinct deferred call against the
/// (mock) provider, with the inner `{{.}}` resolved to the iterator
/// value and `{{pais}}` resolved to the outer-scope variable.
///
/// Verifies:
///   - one DeferredCall per iteration (not one shared across all)
///   - inner `{{.}}` resolves to the current iteration value
///   - outer-scope vars (`{{pais}}`) reach the prompt verbatim
///   - the rendered output matches exactly what the user expects
void main() {
  group('section iteration with deferred ai filter', () {
    late Directory tmp;
    late String brickRoot;
    late String cacheRoot;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('masonex_section_ai_');
      brickRoot = tmp.path;
      cacheRoot = p.join(tmp.path, '.cache', 'ai');
      Directory(p.join(brickRoot, 'brick_test')).createSync();
      File(p.join(brickRoot, 'brick_test', 'ai_fixtures.yaml'))
          .writeAsStringSync('''
fixtures:
  - match: "buscar poblacion para Argentina"
    output: "45.500.000"
  - match: "buscar superficie para Argentina"
    output: "2.756.000"
''');
    });

    tearDown(() => tmp.deleteSync(recursive: true));

    test('Argentina/estadisticos canonical example', () async {
      const src = '{{#estadisticos}}'
          '{{.}}: {{ "buscar {{.}} para {{pais}}" | ai(expect: word) }}\n'
          '{{/estadisticos}}';

      final out = await src.render(
        const {
          'pais': 'Argentina',
          'estadisticos': ['poblacion', 'superficie'],
        },
        aiOptions: AiRenderOptions(
          brickRoot: brickRoot,
          relativePath: 'inline.txt',
          useMockProvider: true,
          cacheRootOverride: cacheRoot,
        ),
      );

      expect(
        out.trim(),
        'poblacion: 45.500.000\n'
        'superficie: 2.756.000',
      );
    });

    test('three-way iteration produces three distinct prompts', () async {
      // Adds capital so we cover N>2 and confirm each iteration is
      // independent (no cache pollution / id collision).
      File(p.join(brickRoot, 'brick_test', 'ai_fixtures.yaml'))
          .writeAsStringSync('''
fixtures:
  - match: "info poblacion para Argentina"
    output: "45.5M"
  - match: "info superficie para Argentina"
    output: "2.78M km2"
  - match: "info capital para Argentina"
    output: "Buenos Aires"
''');

      const src = '{{#estadisticos}}'
          '- {{.}} = {{ "info {{.}} para {{pais}}" | ai }}\n'
          '{{/estadisticos}}';

      final out = await src.render(
        const {
          'pais': 'Argentina',
          'estadisticos': ['poblacion', 'superficie', 'capital'],
        },
        aiOptions: AiRenderOptions(
          brickRoot: brickRoot,
          relativePath: 'inline.txt',
          useMockProvider: true,
          cacheRootOverride: cacheRoot,
        ),
      );

      expect(
        out.trim(),
        '- poblacion = 45.5M\n'
        '- superficie = 2.78M km2\n'
        '- capital = Buenos Aires',
      );
    });

    test('post-filter applies per iteration (e.g., uppercase)', () async {
      const src = '{{#estadisticos}}'
          '{{ "label {{.}}" | ai | upperCase }}\n'
          '{{/estadisticos}}';

      File(p.join(brickRoot, 'brick_test', 'ai_fixtures.yaml'))
          .writeAsStringSync('''
fixtures:
  - match: "label uno"
    output: "primero"
  - match: "label dos"
    output: "segundo"
''');

      final out = await src.render(
        const {
          'estadisticos': ['uno', 'dos'],
        },
        aiOptions: AiRenderOptions(
          brickRoot: brickRoot,
          relativePath: 'inline.txt',
          useMockProvider: true,
          cacheRootOverride: cacheRoot,
        ),
      );

      expect(out.trim(), 'PRIMERO\nSEGUNDO');
    });

    test('iterator with object items (dotted access in literal)', () async {
      File(p.join(brickRoot, 'brick_test', 'ai_fixtures.yaml'))
          .writeAsStringSync('''
fixtures:
  - match: "Buenos Aires - city of"
    output: "tango"
  - match: "Cordoba - city of"
    output: "doctores"
''');

      const src = '{{#cities}}'
          '{{name}}: {{ "{{name}} - city of what?" | ai }}\n'
          '{{/cities}}';

      final out = await src.render(
        const {
          'cities': [
            {'name': 'Buenos Aires'},
            {'name': 'Cordoba'},
          ],
        },
        aiOptions: AiRenderOptions(
          brickRoot: brickRoot,
          relativePath: 'inline.txt',
          useMockProvider: true,
          cacheRootOverride: cacheRoot,
        ),
      );

      expect(
        out.trim(),
        'Buenos Aires: tango\n'
        'Cordoba: doctores',
      );
    });
  });
}
