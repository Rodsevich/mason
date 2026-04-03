import 'dart:io';

import 'package:masonex/src/cli/command.dart';

/// {@template build_command}
/// `masonex build` command which triggers build_runner.
/// {@endtemplate}
class BuildCommand extends MasonexCommand {
  /// {@macro build_command}
  BuildCommand({super.logger});

  @override
  final String description = 'Trigger build_runner to generate metadata.';

  @override
  final String name = 'build';

  @override
  Future<int> run() async {
    final progress = logger.progress('Running build_runner');
    final result = await Process.run(
      'dart',
      ['pub', 'run', 'build_runner', 'build', '--delete-conflicting-outputs'],
      runInShell: true,
    );

    if (result.exitCode == 0) {
      progress.complete('build_runner completed successfully.');
    } else {
      progress.fail('build_runner failed.');
      logger.err(result.stderr as String);
      logger.info(result.stdout as String);
    }

    return result.exitCode;
  }
}
