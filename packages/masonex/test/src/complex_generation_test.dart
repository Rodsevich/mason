import 'dart:convert';
import 'dart:io';
import 'package:masonex/masonex.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('Complex Generation', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('masonex_complex_test');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('verifies all advanced features in tandem', () async {
      final brickDir = Directory(p.join(tempDir.path, 'brick'))..createSync();
      final brickYamlFile = File(p.join(brickDir.path, 'brick.yaml'));
      brickYamlFile.writeAsStringSync('''
name: complex_brick
description: A complex brick for testing
version: 0.1.0
vars:
  items:
    type: list
  include_meta:
    type: boolean
  name:
    type: string
in_file_generations:
  main.dart:
    imports: "Import section"
    classes: "Class section"
''');

      final brickTemplateDir = Directory(p.join(brickDir.path, '__brick__'))
        ..createSync();

      // Iterator and Conditional
      // *items*?include_meta?{{item}}.meta
      final iteratorFile = File(
        p.join(brickTemplateDir.path, '*items*?include_meta?{{item}}.meta'),
      );
      iteratorFile.writeAsStringSync('Meta for {{item}}');

      // Merge JSON
      final jsonMergeFile = File(p.join(brickTemplateDir.path, '>>>data.json'));
      jsonMergeFile.writeAsStringSync('{"new_key": "{{name}}"}');

      // Merge YAML
      final yamlMergeFile = File(
        p.join(brickTemplateDir.path, '>>>config.yaml'),
      );
      yamlMergeFile.writeAsStringSync('''
settings:
  feature_x: true
  name: {{name}}
''');

      // Append/Prepend
      final appendFile = File(p.join(brickTemplateDir.path, '>>log.txt'));
      appendFile.writeAsStringSync('End of log for {{name}}\n');

      final prependFile = File(p.join(brickTemplateDir.path, '<<log.txt'));
      prependFile.writeAsStringSync('Start of log for {{name}}\n');

      // In-file generation
      final inFileSnippet = File(
        p.join(brickTemplateDir.path, '%imports%.dart'),
      );
      inFileSnippet.writeAsStringSync(
        "import 'package:{{name}}/{{name}}.dart';",
      );

      final outputDir = Directory(p.join(tempDir.path, 'output'))..createSync();

      // Pre-existing files for merging
      File(
        p.join(outputDir.path, 'data.json'),
      ).writeAsStringSync('{"existing_key": "old_value"}');
      File(p.join(outputDir.path, 'config.yaml')).writeAsStringSync('''
version: 1.0
settings:
  feature_y: false
''');
      File(
        p.join(outputDir.path, 'log.txt'),
      ).writeAsStringSync('Existing content\n');
      File(p.join(outputDir.path, 'main.dart')).writeAsStringSync('''
// @GenerateBefore('imports')
void main() {}
// @GenerateAfter('classes')
''');

      final generator = await MasonexGenerator.fromBrick(
        Brick.path(brickDir.path),
      );
      final target = DirectoryGeneratorTarget(outputDir);

      await generator.generate(
        target,
        vars: {
          'items': ['one', 'two'],
          'include_meta': true,
          'name': 'masonex_test',
        },
      );

      // Verify Iterator and Conditional
      expect(File(p.join(outputDir.path, 'one.meta')).existsSync(), isTrue);
      expect(File(p.join(outputDir.path, 'two.meta')).existsSync(), isTrue);
      expect(
        File(p.join(outputDir.path, 'one.meta')).readAsStringSync(),
        equals('Meta for one'),
      );

      // Verify JSON Merge
      final dataJson =
          json.decode(
                File(p.join(outputDir.path, 'data.json')).readAsStringSync(),
              )
              as Map<String, dynamic>;
      expect(dataJson['existing_key'], equals('old_value'));
      expect(dataJson['new_key'], equals('masonex_test'));

      // Verify YAML Merge
      final configYaml = File(
        p.join(outputDir.path, 'config.yaml'),
      ).readAsStringSync();
      expect(configYaml, contains('version: 1.0'));
      expect(configYaml, contains('feature_y: false'));
      expect(configYaml, contains('feature_x: true'));
      expect(configYaml, contains('name: masonex_test'));

      // Verify Append/Prepend
      final logContent = File(
        p.join(outputDir.path, 'log.txt'),
      ).readAsStringSync();
      expect(
        logContent,
        equals(
          'Start of log for masonex_test\n'
          'Existing content\n'
          'End of log for masonex_test\n',
        ),
      );

      // Verify In-file generation
      final mainContent = File(
        p.join(outputDir.path, 'main.dart'),
      ).readAsStringSync();
      expect(
        mainContent,
        contains(
          '\n'
          '// Import section\n'
          "import 'package:masonex_test/masonex_test.dart';\n"
          '\n'
          "// @GenerateBefore('imports')",
        ),
      );
    });

    test('verifies conditional skip', () async {
      final brickDir = Directory(p.join(tempDir.path, 'brick_skip'))
        ..createSync();
      File(p.join(brickDir.path, 'brick.yaml')).writeAsStringSync('''
name: skip_brick
description: A brick for testing skip
version: 0.1.0
vars:
  show:
    type: boolean
''');
      final brickTemplateDir = Directory(p.join(brickDir.path, '__brick__'))
        ..createSync();
      File(
        p.join(brickTemplateDir.path, '?show?file.txt'),
      ).writeAsStringSync('Content');

      final outputDir = Directory(p.join(tempDir.path, 'output_skip'))
        ..createSync();
      final generator = await MasonexGenerator.fromBrick(
        Brick.path(brickDir.path),
      );
      final target = DirectoryGeneratorTarget(outputDir);

      await generator.generate(target, vars: {'show': false});
      expect(File(p.join(outputDir.path, 'file.txt')).existsSync(), isFalse);
    });
  });
}
