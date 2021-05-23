import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:io/io.dart';

import 'commands/commands.dart';
import 'exception.dart';
import 'logger.dart';
import 'version.dart';

/// {@template mason_command_runner}
/// A [CommandRunner] for the Mason CLI.
/// {@endtemplate}
class MasonCommandRunner extends CommandRunner<int> {
  /// {@macro mason_command_runner}
  MasonCommandRunner({Logger? logger})
      : _logger = logger ?? Logger(),
        super('mason', '⛏️  mason \u{2022} lay the foundation!') {
    argParser.addFlag(
      'version',
      negatable: false,
      help: 'Print the current version.',
    );
    addCommand(CacheCommand(logger: _logger));
    addCommand(BundleCommand(logger: _logger));
    addCommand(InitCommand(logger: _logger));
    addCommand(InstallCommand(logger: _logger));
    addCommand(GetCommand(logger: _logger));
    addCommand(MakeCommand(logger: _logger));
    addCommand(NewCommand(logger: _logger));
  }

  final Logger _logger;

  @override
  Future<int> run(Iterable<String> args) async {
    try {
      return await runCommand(parse(args)) ?? ExitCode.success.code;
    } on FormatException catch (e, stackTrace) {
      _logger
        ..err(e.message)
        ..err('$stackTrace')
        ..info('')
        ..info(usage);
      return ExitCode.usage.code;
    } on UsageException catch (e, stackTrace) {
      _logger
        ..err(e.message)
        ..err('$stackTrace')
        ..info('')
        ..info(usage);
      return ExitCode.usage.code;
    } on MasonException catch (e, stackTrace) {
      _logger..err(e.message)..err('$stackTrace');
      return ExitCode.usage.code;
    }
  }

  @override
  Future<int?> runCommand(ArgResults topLevelResults) async {
    if (topLevelResults['version'] == true) {
      _logger.info('mason version: $packageVersion');
      return ExitCode.success.code;
    }
    return super.runCommand(topLevelResults);
  }
}
