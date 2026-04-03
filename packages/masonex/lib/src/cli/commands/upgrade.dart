import 'package:masonex/masonex.dart';
import 'package:masonex/src/cli/command.dart';
import 'package:masonex/src/cli/install_brick.dart';

/// {@template upgrade_command}
/// `masonex upgrade` command which upgrades bricks to their latest versions.
/// {@endtemplate}
class UpgradeCommand extends MasonexCommand with InstallBrickMixin {
  /// {@macro upgrade_command}
  UpgradeCommand({super.logger}) {
    argParser.addFlag(
      'global',
      abbr: 'g',
      help: 'Upgrades globally installed bricks.',
    );
  }

  @override
  final String description = 'Upgrade bricks to their latest versions.';

  @override
  final String name = 'upgrade';

  @override
  Future<int> run() async {
    final isGlobal = results['global'] == true;
    final progress = logger.progress('Upgrading bricks');
    try {
      await getBricks(upgrade: true, global: isGlobal);
    } catch (_) {
      progress.fail();
      rethrow;
    }
    progress.complete('Upgraded bricks');
    return ExitCode.success.code;
  }
}
