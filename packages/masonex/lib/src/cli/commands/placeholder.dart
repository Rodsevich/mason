// ignore_for_file: public_member_api_docs, lines_longer_than_80_chars

import 'dart:io';

import 'package:masonex/masonex.dart';
import 'package:masonex/src/cli/command.dart';
import 'package:masonex/src/placeholder/errors.dart';
import 'package:masonex/src/placeholder/preprocessor.dart';
import 'package:path/path.dart' as p;

/// `masonex placeholder` — entry point for the placeholder-mode pre-processor
/// (Dart bricks authored as valid Dart, see
/// `doc/brick-authoring/placeholder-mode-rfc.md`).
class PlaceholderCommand extends MasonexCommand {
  PlaceholderCommand({super.logger}) {
    addSubcommand(PlaceholderRenderCommand(logger: logger));
    addSubcommand(PlaceholderCheckCommand(logger: logger));
  }

  @override
  String get description => 'Tools for placeholder-mode Dart bricks.';

  @override
  String get name => 'placeholder';
}

/// `masonex placeholder render <file>` — print the Mustache source the
/// pre-processor would emit for a Dart placeholder-mode brick file.
class PlaceholderRenderCommand extends MasonexCommand {
  PlaceholderRenderCommand({super.logger});

  @override
  String get description =>
      'Print the Mustache source the pre-processor emits for <file>.';

  @override
  String get name => 'render';

  @override
  String get invocation => 'masonex placeholder render <file>';

  @override
  Future<int> run() async {
    final rest = argResults?.rest ?? const <String>[];
    if (rest.isEmpty) {
      logger.err('Missing required argument: <file>.');
      return ExitCode.usage.code;
    }
    final file = File(rest.first);
    if (!file.existsSync()) {
      logger.err('No such file: ${file.path}');
      return ExitCode.noInput.code;
    }
    final source = await file.readAsString();
    try {
      final out = preprocessPlaceholderDart(source);
      stdout.write(out);
      return ExitCode.success.code;
    } on PlaceholderModeException catch (e) {
      logger.err(e.message);
      return ExitCode.data.code;
    }
  }
}

/// `masonex placeholder check <brick>` — validate every `.dart` file under
/// `__brick__/` parses cleanly under placeholder-mode rules.
class PlaceholderCheckCommand extends MasonexCommand {
  PlaceholderCheckCommand({super.logger}) {
    argParser.addOption(
      'brick',
      abbr: 'b',
      help: 'Path to the brick directory (default: cwd).',
    );
  }

  @override
  String get description =>
      'Validate every Dart file in a brick under placeholder-mode rules.';

  @override
  String get name => 'check';

  @override
  Future<int> run() async {
    final brickRoot =
        (argResults?['brick'] as String?) ?? Directory.current.path;
    final brickDir = Directory(p.join(brickRoot, '__brick__'));
    if (!brickDir.existsSync()) {
      logger.err('No __brick__/ directory at ${brickDir.path}');
      return ExitCode.usage.code;
    }
    var errors = 0;
    var checked = 0;
    await for (final entity in brickDir.list(recursive: true)) {
      if (entity is! File) continue;
      if (!entity.path.endsWith('.dart')) continue;
      final relative = p.relative(entity.path, from: brickDir.parent.path);
      String source;
      try {
        source = await entity.readAsString();
      } on FileSystemException {
        continue;
      }
      checked++;
      try {
        preprocessPlaceholderDart(source);
      } on PlaceholderModeException catch (e) {
        logger.err('$relative: ${e.message}');
        errors++;
      }
    }
    if (errors == 0) {
      logger.info(
        '${green.wrap("OK")} — checked $checked Dart file(s).',
      );
      return ExitCode.success.code;
    }
    logger.err('$errors error(s).');
    return ExitCode.data.code;
  }
}
