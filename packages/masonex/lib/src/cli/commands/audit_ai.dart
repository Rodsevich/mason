// ignore_for_file: public_member_api_docs, lines_longer_than_80_chars

import 'dart:io';

import 'package:masonex/masonex.dart';
import 'package:masonex/src/ai/ai.dart';
import 'package:masonex/src/cli/command.dart';
import 'package:path/path.dart' as p;

/// `masonex audit-ai <brick>` — list all `| ai` tags in a brick with their
/// pre-rendered prompt and the parameters declared, without contacting any
/// provider. Useful for reviewing what a brick will ask the AI to produce.
class AuditAiCommand extends MasonexCommand {
  AuditAiCommand({super.logger}) {
    argParser.addOption(
      'brick',
      abbr: 'b',
      help: 'Path to the brick directory (default: cwd).',
    );
  }

  @override
  String get description =>
      'List every `| ai` tag in a brick with prompt + parameters.';

  @override
  String get name => 'audit-ai';

  @override
  Future<int> run() async {
    final brickRoot = (argResults?['brick'] as String?) ?? Directory.current.path;
    final brickDir = Directory(p.join(brickRoot, '__brick__'));
    if (!brickDir.existsSync()) {
      logger.err('No __brick__/ directory at ${brickDir.path}');
      return ExitCode.usage.code;
    }
    var total = 0;
    await for (final entity in brickDir.list(recursive: true)) {
      if (entity is! File) continue;
      String content;
      try {
        content = await entity.readAsString();
      } on FileSystemException {
        continue;
      }
      final relative = p.relative(entity.path, from: brickDir.parent.path);
      final tags = TagFinder(content).find();
      for (final tag in tags) {
        try {
          final node = PipelineParser.fromTag(tag.content).parse();
          if (node == null || !node.hasAi) continue;
          total++;
          final aiCall = node.filters.firstWhere((f) => f.name == 'ai');
          logger
            ..info('')
            ..info(
              '${cyan.wrap(relative)}:${tag.line}:${tag.column}',
            )
            ..info('  tag    : ${tag.content.trim()}')
            ..info('  head   : ${node.head} (${node.headKind.name})')
            ..info('  args   : ${aiCall.toSyntax()}')
            ..info(
              '  post   : ${node.postAiFilters.map((f) => f.toSyntax()).join(" | ")}',
            );
        } on AiSyntaxError catch (e) {
          logger.warn(
            'syntax error in $relative:${tag.line}:${tag.column}: '
            '${e.message}',
          );
        }
      }
    }
    logger
      ..info('')
      ..info('Total AI tags: $total');
    return ExitCode.success.code;
  }
}
