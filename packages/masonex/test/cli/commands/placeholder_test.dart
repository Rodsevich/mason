import 'dart:io';

import 'package:masonex/masonex.dart';
import 'package:masonex/src/cli/command_runner.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as path;
import 'package:pub_updater/pub_updater.dart';
import 'package:test/test.dart';

import '../helpers/helpers.dart';

class _MockLogger extends Mock implements Logger {}

class _MockPubUpdater extends Mock implements PubUpdater {}

class _MockProgress extends Mock implements Progress {}

void main() {
  final cwd = Directory.current.path;

  group('masonex placeholder', () {
    late Logger logger;
    late PubUpdater pubUpdater;
    late MasonexCommandRunner commandRunner;

    setUp(() {
      logger = _MockLogger();
      pubUpdater = _MockPubUpdater();

      when(() => logger.progress(any())).thenReturn(_MockProgress());
      when(
        () => pubUpdater.getLatestVersion(any()),
      ).thenAnswer((_) async => packageVersion);

      commandRunner = MasonexCommandRunner(
        logger: logger,
        pubUpdater: pubUpdater,
      );
      setUpTestingEnvironment(cwd, suffix: '.placeholder');
    });

    tearDown(() {
      Directory.current = cwd;
    });

    group('render', () {
      test('exits with usage code when <file> is missing', () async {
        final result = await commandRunner.run(['placeholder', 'render']);
        expect(result, equals(ExitCode.usage.code));
        verify(() => logger.err(any())).called(1);
      });

      test('exits with noInput code when the file does not exist', () async {
        final result = await commandRunner.run(
          ['placeholder', 'render', 'does_not_exist.dart'],
        );
        expect(result, equals(ExitCode.noInput.code));
        verify(() => logger.err(any())).called(1);
      });

      test('exits successfully for a valid placeholder file', () async {
        final file = File(
          path.join(Directory.current.path, 'widget.dart'),
        )..writeAsStringSync('class /*{{className}}*/ Foo {}\n');

        final result = await commandRunner.run(
          ['placeholder', 'render', file.path],
        );
        expect(result, equals(ExitCode.success.code));
      });

      test('exits successfully when there is no placeholder marker', () async {
        final file = File(
          path.join(Directory.current.path, 'plain.dart'),
        )..writeAsStringSync('class Foo {}\n');

        final result = await commandRunner.run(
          ['placeholder', 'render', file.path],
        );
        expect(result, equals(ExitCode.success.code));
      });

      test('exits with data code when the placeholder file is invalid',
          () async {
        final file = File(
          path.join(Directory.current.path, 'broken.dart'),
        )..writeAsStringSync(
            "@pragma('masonex:header', { 'X': '{{x}}' })\n"
            'library;\n\nclass { broken\n',
          );

        final result = await commandRunner.run(
          ['placeholder', 'render', file.path],
        );
        expect(result, equals(ExitCode.data.code));
        verify(() => logger.err(any())).called(1);
      });
    });

    group('check', () {
      test('exits with usage code when there is no __brick__ directory',
          () async {
        final result = await commandRunner.run(['placeholder', 'check']);
        expect(result, equals(ExitCode.usage.code));
        verify(() => logger.err(any())).called(1);
      });

      test('exits successfully when every Dart file is valid', () async {
        final brickDir = Directory(
          path.join(Directory.current.path, '__brick__', 'lib'),
        )..createSync(recursive: true);
        File(path.join(brickDir.path, 'a.dart'))
            .writeAsStringSync('class /*{{name}}*/ Foo {}\n');
        File(path.join(brickDir.path, 'b.dart'))
            .writeAsStringSync('class Plain {}\n');

        final result = await commandRunner.run(['placeholder', 'check']);
        expect(result, equals(ExitCode.success.code));
        verify(() => logger.info(any())).called(1);
      });

      test('honors the --brick option', () async {
        final brickRoot = Directory(
          path.join(Directory.current.path, 'nested_brick'),
        );
        Directory(path.join(brickRoot.path, '__brick__'))
            .createSync(recursive: true);
        File(path.join(brickRoot.path, '__brick__', 'a.dart'))
            .writeAsStringSync('class Plain {}\n');

        final result = await commandRunner.run(
          ['placeholder', 'check', '--brick', brickRoot.path],
        );
        expect(result, equals(ExitCode.success.code));
      });

      test('reports an error when a Dart file is invalid', () async {
        final brickDir = Directory(
          path.join(Directory.current.path, '__brick__'),
        )..createSync(recursive: true);
        File(path.join(brickDir.path, 'bad.dart')).writeAsStringSync(
          "@pragma('masonex:header', 'not a map')\nlibrary;\n\nclass Foo {}\n",
        );

        final result = await commandRunner.run(['placeholder', 'check']);
        expect(result, equals(ExitCode.data.code));
        verify(() => logger.err(any())).called(greaterThanOrEqualTo(1));
      });
    });
  });
}
