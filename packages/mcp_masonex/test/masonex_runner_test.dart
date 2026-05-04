import 'dart:io';

import 'package:mcp_masonex/src/runner/masonex_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('mcp_masonex_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('MasonexRunner', () {
    test('captures stdout, stderr and exitCode', () async {
      final script = File(p.join(tempDir.path, 'fake_masonex.dart'))
        ..writeAsStringSync('''
import 'dart:io';
void main() {
  stdout.writeln('hello-out');
  stderr.writeln('hello-err');
  exitCode = 7;
}
''');
      final runner = MasonexRunner(executable: Platform.resolvedExecutable);
      final result = await runner.run(['run', script.path]);
      expect(result.exitCode, 7);
      expect(result.stdout, contains('hello-out'));
      expect(result.stderr, contains('hello-err'));
      expect(result.timedOut, isFalse);
      expect(result.command.first, Platform.resolvedExecutable);
      expect(result.command, contains('run'));
    });

    test('reports a non-zero result when the binary cannot be spawned',
        () async {
      final runner = MasonexRunner(
        executable: '/this/binary/should/never/exist-$pid',
      );
      final result = await runner.run(['--version']);
      expect(result.exitCode, isNonZero);
      expect(result.success, isFalse);
      expect(result.stderr, contains('Failed to spawn'));
    });

    test('honours timeout', () async {
      final script = File(p.join(tempDir.path, 'sleeper.dart'))
        ..writeAsStringSync('''
import 'dart:async';
void main() async {
  await Future<void>.delayed(const Duration(seconds: 30));
}
''');
      final runner = MasonexRunner(executable: Platform.resolvedExecutable);
      final result = await runner.run(
        ['run', script.path],
        timeout: const Duration(milliseconds: 500),
      );
      expect(result.timedOut, isTrue);
      expect(result.success, isFalse);
    });
  });
}
