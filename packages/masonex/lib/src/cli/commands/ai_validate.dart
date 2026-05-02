// ignore_for_file: public_member_api_docs, lines_longer_than_80_chars

import 'dart:io';

import 'package:masonex/masonex.dart';
import 'package:masonex/src/ai/ai.dart';
import 'package:masonex/src/cli/command.dart';
import 'package:path/path.dart' as p;

/// `masonex validate <brick>` — static checks for AI pipeline syntax inside
/// a brick. Does not invoke any AI provider.
class AiValidateCommand extends MasonexCommand {
  AiValidateCommand({super.logger}) {
    argParser.addOption(
      'brick',
      abbr: 'b',
      help: 'Path to the brick directory (default: cwd).',
    );
  }

  @override
  String get description =>
      'Validate AI pipeline syntax inside a brick (offline).';

  @override
  String get name => 'validate';

  @override
  Future<int> run() async {
    final brickRoot = (argResults?['brick'] as String?) ?? Directory.current.path;
    final brickDir = Directory(p.join(brickRoot, '__brick__'));
    if (!brickDir.existsSync()) {
      logger.err('No __brick__/ directory at ${brickDir.path}');
      return ExitCode.usage.code;
    }
    var errors = 0;
    var aiTagsFound = 0;
    await for (final entity in brickDir.list(recursive: true)) {
      if (entity is! File) continue;
      final relative = p.relative(entity.path, from: brickDir.parent.path);
      if (_looksBinary(entity)) continue;
      String content;
      try {
        content = await entity.readAsString();
      } on FileSystemException {
        continue;
      }

      // 1. Check for `| ai` in file PATH (forbidden).
      if (_pathHasAi(relative)) {
        logger.err('AI filter is not allowed in paths: $relative');
        errors++;
      }

      // 2. Validate pipeline syntax in tags.
      final tags = TagFinder(content).find();
      for (final tag in tags) {
        try {
          final node = PipelineParser.fromTag(tag.content).parse();
          if (node?.hasAi ?? false) {
            aiTagsFound++;
          }
        } on AiSyntaxError catch (e) {
          logger.err(
            '$relative:${tag.line}:${tag.column}  ${e.message}',
          );
          errors++;
        }
      }
    }
    if (errors == 0) {
      logger.info(
        'Validated ${green.wrap("OK")} — $aiTagsFound AI tag(s) found.',
      );
      return ExitCode.success.code;
    }
    logger.err('$errors error(s).');
    return ExitCode.data.code;
  }

  bool _pathHasAi(String relativePath) {
    // Catches `| ai` and `.ai(` in the path string (which would mean someone
    // tried to use AI inside a filename).
    return RegExp(r'\|\s*ai\b|\.ai\s*\(').hasMatch(relativePath);
  }

  bool _looksBinary(File f) {
    try {
      final head = f.openRead(0, 1024).first;
      return head.then((bytes) => bytes.contains(0)) is bool;
    } on Exception {
      return false;
    }
  }
}
