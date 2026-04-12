import 'dart:convert';
import 'dart:io';

import 'package:masonex/masonex.dart';
import 'package:masonex/masonex.dart' as masonex show packageVersion;
import 'package:masonex/src/cli/command.dart';
import 'package:masonex/src/cli/command_runner.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as path;
import 'package:pub_updater/pub_updater.dart';
import 'package:test/test.dart';

import '../helpers/helpers.dart';
import '../../helpers/get_brick_path.dart';

class _MockLogger extends Mock implements Logger {}

class _MockPubUpdater extends Mock implements PubUpdater {}

class _MockProgress extends Mock implements Progress {}

void main() {
  final cwd = Directory.current.path;

  group('masonex get', () {
    late Logger logger;
    late PubUpdater pubUpdater;
    late MasonexCommandRunner commandRunner;

    setUpAll(() async {
      registerFallbackValue(Object());
      logger = _MockLogger();
      pubUpdater = _MockPubUpdater();

      when(
        () => logger.prompt(any(), defaultValue: any(named: 'defaultValue')),
      ).thenReturn('');
      when(() => logger.progress(any())).thenReturn(_MockProgress());
      when(
        () => pubUpdater.getLatestVersion(any()),
      ).thenAnswer((_) async => packageVersion);
      await MasonexCommandRunner(
        logger: logger,
        pubUpdater: pubUpdater,
      ).run(['cache', 'clear']);
    });

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
      setUpTestingEnvironment(cwd, suffix: '.get');

      File(path.join(Directory.current.path, 'masonex.yaml')).writeAsStringSync(
        '''
bricks:
  app_icon:
    path: ${getBrickPath('app_icon')}
  documentation:
    path: ${getBrickPath('documentation')}
  greeting:
    path: ${getBrickPath('greeting')}
  hooks:
    git:
      url: https://github.com/felangel/mason
      path: bricks/hooks
      ref: c744e19c23243453f568b539bb122767e6542929
  simple:
    path: ${getBrickPath('simple')}
  todos:
    path: ${getBrickPath('todos')}
  widget:
    git:
      url: https://github.com/felangel/mason
      path: bricks/widget
      ref: c744e19c23243453f568b539bb122767e6542929
''',
      );
    });

    tearDown(() {
      Directory.current = cwd;
    });

    test(
      'creates .masonex/brick.json and masonex-lock.json when masonex.yaml exists',
      () async {
        final expectedBrickJsonPath = path.join(
          Directory.current.path,
          '.masonex',
          'bricks.json',
        );
        final expectedMasonexLockJsonPath = path.join(
          Directory.current.path,
          'masonex-lock.json',
        );
        var doneCallCount = 0;
        final progress = _MockProgress();
        when(() => progress.complete(any())).thenAnswer((invocation) {
          doneCallCount++;
        });
        when(() => logger.progress(any())).thenReturn(progress);

        expect(File(expectedBrickJsonPath).existsSync(), isFalse);
        expect(File(expectedMasonexLockJsonPath).existsSync(), isFalse);

        final result = await commandRunner.run(['get']);
        if (result != 0) {
          // Since logger is a mock, we can't easily see its calls without verify.
          // But we can verify it here for debugging.
          try {
            verify(() => logger.err(any())).captured.forEach(print);
          } catch (_) {}
        }
        expect(result, equals(ExitCode.success.code));

        expect(File(expectedBrickJsonPath).existsSync(), isTrue);
        expect(File(expectedMasonexLockJsonPath).existsSync(), isTrue);

        final appIconPath = getBrickPath('app_icon');
        final docPath = getBrickPath('documentation');
        final greetingPath = getBrickPath('greeting');
        final hooksPath = canonicalize(
          path.join(
            BricksJson.rootDir.path,
            'git',
            '''masonex_aHR0cHM6Ly9naXRodWIuY29tL2ZlbGFuZ2VsL21hc29u_c744e19c23243453f568b539bb122767e6542929''',
            'bricks',
            'hooks',
          ),
        );
        final simplePath = getBrickPath('simple');
        final todosPath = getBrickPath('todos');
        final widgetPath = canonicalize(
          path.join(
            BricksJson.rootDir.path,
            'git',
            '''masonex_aHR0cHM6Ly9naXRodWIuY29tL2ZlbGFuZ2VsL21hc29u_c744e19c23243453f568b539bb122767e6542929''',
            'bricks',
            'widget',
          ),
        );

        expect(
          File(expectedBrickJsonPath).readAsStringSync(),
          equals(
            json.encode({
              'app_icon': appIconPath,
              'documentation': docPath,
              'greeting': greetingPath,
              'hooks': hooksPath,
              'simple': simplePath,
              'todos': todosPath,
              'widget': widgetPath,
            }),
          ),
        );
        expect(
          File(expectedMasonexLockJsonPath).readAsStringSync(),
          equals(
            json.encode({
              'bricks': {
                'app_icon': {'path': appIconPath},
                'documentation': {'path': docPath},
                'greeting': {'path': greetingPath},
                'hooks': {
                  'git': {
                    'url': 'https://github.com/felangel/mason',
                    'path': 'bricks/hooks',
                    'ref': 'c744e19c23243453f568b539bb122767e6542929',
                  },
                },
                'simple': {'path': simplePath},
                'todos': {'path': todosPath},
                'widget': {
                  'git': {
                    'url': 'https://github.com/felangel/mason',
                    'path': 'bricks/widget',
                    'ref': 'c744e19c23243453f568b539bb122767e6542929',
                  },
                },
              },
            }),
          ),
        );

        verify(() => logger.progress('Getting bricks')).called(1);
        expect(doneCallCount, equals(1));
      },
    );

    test('does not error when brick.json already exists', () async {
      final expectedBrickJsonPath = path.join(
        Directory.current.path,
        '.masonex',
        'bricks.json',
      );

      final resultA = await commandRunner.run(['get']);
      expect(resultA, equals(ExitCode.success.code));

      final resultB = await commandRunner.run(['get']);
      expect(resultB, equals(ExitCode.success.code));

      expect(File(expectedBrickJsonPath).existsSync(), isTrue);
    });

    test('does not error when masonex-lock.json already exists', () async {
      final expectedMasonexLockJsonPath = path.join(
        Directory.current.path,
        'masonex-lock.json',
      );

      final resultA = await commandRunner.run(['get']);
      expect(resultA, equals(ExitCode.success.code));

      final resultB = await commandRunner.run(['get']);
      expect(resultB, equals(ExitCode.success.code));

      expect(File(expectedMasonexLockJsonPath).existsSync(), isTrue);
    });

    test('resolves git and hosted versions', () async {
      File(path.join(Directory.current.path, 'masonex.yaml')).writeAsStringSync(
        '''
bricks:
  greeting: ^0.1.0-dev
  widget:
    git:
      url: https://github.com/felangel/mason
      path: bricks/widget
''',
      );
      final expectedMasonexLockJsonPath = path.join(
        Directory.current.path,
        'masonex-lock.json',
      );

      final resultA = await commandRunner.run(['get']);
      expect(resultA, equals(ExitCode.success.code));
      expect(File(expectedMasonexLockJsonPath).existsSync(), isTrue);
      final lockA = File(expectedMasonexLockJsonPath).readAsStringSync();

      final resultB = await commandRunner.run(['get']);
      expect(resultB, equals(ExitCode.success.code));
      expect(File(expectedMasonexLockJsonPath).existsSync(), isTrue);
      final lockB = File(expectedMasonexLockJsonPath).readAsStringSync();

      expect(lockA, equals(lockB));
    });

    test('exits with code 64 when masonex.yaml does not exist', () async {
      Directory.current = cwd.path;
      final result = await commandRunner.run(['get']);
      expect(result, equals(ExitCode.usage.code));
      verify(
        () => logger.err(const MasonexYamlNotFoundException().message),
      ).called(1);
    });

    test('throws BrickNotFoundException when path does not exist', () async {
      File(path.join(Directory.current.path, 'masonex.yaml')).writeAsStringSync(
        '''
bricks:
  app_icon:
    path: ../../wrong/path  
''',
      );
      final result = await commandRunner.run(['get']);
      expect(result, equals(ExitCode.usage.code));
      verify(
        () => logger.err(
          BrickNotFoundException(canonicalize('../../wrong/path')).message,
        ),
      ).called(1);
    });

    test(
      'throws BrickNotFoundException when git path does not exist',
      () async {
        File(
          path.join(Directory.current.path, 'masonex.yaml'),
        ).writeAsStringSync('''
bricks:
  widget:
    git:
      url: https://github.com/felangel/mason
      path: bricks/invalid
''');
        final result = await commandRunner.run(['get']);
        expect(result, equals(ExitCode.usage.code));
        verify(
          () => logger.err(
            const BrickNotFoundException(
              'https://github.com/felangel/mason/bricks/invalid',
            ).message,
          ),
        ).called(1);
      },
    );

    test(
      'throws MasonexYamlParseException when masonex.yaml is malformed',
      () async {
        File(
          path.join(Directory.current.path, 'masonex.yaml'),
        ).writeAsStringSync('''
{malformed}
''');
        final result = await commandRunner.run(['get']);
        expect(result, equals(ExitCode.usage.code));
        verify(
          () => logger.err(
            any(
              that: contains(
                'Unrecognized keys: [malformed]; supported keys: [bricks]',
              ),
            ),
          ),
        ).called(1);
      },
    );

    test('throws MasonexYamlNameMismatch '
        'when masonex.yaml contains mismatch', () async {
      File(path.join(Directory.current.path, 'masonex.yaml')).writeAsStringSync(
        '''
bricks:
  app_icon1:
    path: ${getBrickPath('app_icon')}
''',
      );
      commandRunner = MasonexCommandRunner(
        logger: logger,
        pubUpdater: pubUpdater,
      );
      const expectedErrorMessage =
          '''Brick name "app_icon1" doesn't match provided name "app_icon" in masonex.yaml.''';
      final getResult = await commandRunner.run(['get']);
      expect(getResult, equals(ExitCode.usage.code));
      verify(() => logger.err(expectedErrorMessage)).called(1);
    });

    test(
      'exits with code 64 when masonex version constraint cannot be resolved',
      () async {
        await commandRunner.run(['new', 'example']);
        final brickYaml = File(path.join('example', 'brick.yaml'));
        brickYaml.writeAsStringSync(
          brickYaml.readAsStringSync().replaceFirst(
            'masonex: ^${masonex.packageVersion}',
            'masonex: ">=99.99.99 <100.0.0"',
          ),
        );
        File(
          path.join(Directory.current.path, 'masonex.yaml'),
        ).writeAsStringSync('''
  example:
    path:  ./example
''', mode: FileMode.append);

        commandRunner = MasonexCommandRunner(
          logger: logger,
          pubUpdater: pubUpdater,
        );

        final result = await commandRunner.run(['get']);
        expect(result, equals(ExitCode.usage.code));
        verify(
          () => logger.err(
            '''The current masonex version is ${masonex.packageVersion}.\nBecause example requires masonex version >=99.99.99 <100.0.0, version solving failed.''',
          ),
        ).called(1);
      },
    );

    test('throws ProcessException when remote does not exist', () async {
      File(path.join(Directory.current.path, 'masonex.yaml')).writeAsStringSync(
        '''
bricks:
  widget:
    git:
      url: https://github.com/felangel/mason1
      path: bricks/invalid
''',
      );
      final result = await commandRunner.run(['get']);
      expect(result, equals(ExitCode.unavailable.code));
      verify(() => logger.err(any(that: contains('fatal:')))).called(1);
    });
  });
}
