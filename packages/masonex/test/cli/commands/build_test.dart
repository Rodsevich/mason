

import 'package:masonex/masonex.dart';
import 'package:masonex/src/cli/command_runner.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pub_updater/pub_updater.dart';
import 'package:test/test.dart';

class _MockLogger extends Mock implements Logger {}

class _MockPubUpdater extends Mock implements PubUpdater {}

class _MockProgress extends Mock implements Progress {}

void main() {
  group('masonex build', () {
    late Logger logger;
    late PubUpdater pubUpdater;
    late MasonexCommandRunner commandRunner;
    late Progress progress;

    setUp(() {
      logger = _MockLogger();
      pubUpdater = _MockPubUpdater();
      progress = _MockProgress();

      when(() => logger.progress(any())).thenReturn(progress);
      when(() => pubUpdater.getLatestVersion(any()))
          .thenAnswer((_) async => packageVersion);

      commandRunner = MasonexCommandRunner(
        logger: logger,
        pubUpdater: pubUpdater,
      );
    });

    test('runs build_runner successfully', () async {
      // NOTE: This test might actually invoke build_runner in the current directory.
      // Alternatively, we can mock Process.run, but Process.run is a static method.
      // If we don't mock it, it will try to run build_runner.
      // Since masonex itself has build_runner, it should exit with 0.
      final result = await commandRunner.run(['build']);
      expect(result, equals(ExitCode.success.code));
      verify(() => logger.progress('Running build_runner')).called(1);
    });
  });
}
