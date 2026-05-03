// ignore_for_file: public_member_api_docs, lines_longer_than_80_chars

import 'dart:io';

import 'package:masonex/masonex.dart';
import 'package:masonex/src/ai/ai.dart';
import 'package:masonex/src/cli/command.dart';
import 'package:path/path.dart' as p;

/// `masonex ai-context-preview --brick <path> [--tag <id>]` — prints the
/// envelope XML that would be sent to the AI for one or all tags in a
/// brick. Does NOT contact any provider.
class AiContextPreviewCommand extends MasonexCommand {
  AiContextPreviewCommand({super.logger}) {
    argParser
      ..addOption(
        'brick',
        abbr: 'b',
        help: 'Path to the brick directory (default: cwd).',
      )
      ..addOption(
        'tag',
        help: 'Filter by tag id substring. Default: print all.',
      );
  }

  @override
  String get description =>
      'Print the XML envelope that would be sent to the AI for each tag.';

  @override
  String get name => 'ai-context-preview';

  @override
  Future<int> run() async {
    final brickRoot =
        (argResults?['brick'] as String?) ?? Directory.current.path;
    final brickDir = Directory(p.join(brickRoot, '__brick__'));
    if (!brickDir.existsSync()) {
      logger.err('No __brick__/ directory at ${brickDir.path}');
      return ExitCode.usage.code;
    }
    final tagFilter = argResults?['tag'] as String?;

    const builder = EnvelopeBuilder();
    const serializer = EnvelopeSerializer();
    final brickContext = BrickContext(
      brickName: p.basename(brickRoot),
      brickVersion: '0.0.0-preview',
      brickDescription: null,
      userVars: const {},
      providerName: '<preview>',
      providerModel: null,
      brickFiles: const [],
    );

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
        final node = PipelineParser.fromTag(tag.content).parse();
        if (node == null || !node.hasAi) continue;
        final id = '$relative#L${tag.line}:c${tag.column}';
        if (tagFilter != null && !id.contains(tagFilter)) continue;
        total++;

        final aiCall = node.filters.firstWhere((f) => f.name == 'ai');
        final request = AiTagRequest(
          id: id,
          syntheticVarName: '__masonex_ai_preview',
          relativePath: relative,
          line: tag.line,
          column: tag.column,
          prompt: node.head,
          node: node,
          tagOriginal: tag.content,
          inlineHint: !_ownLine(content, tag.tagStart, tag.tagEnd),
        );
        final envelope = builder.build(
          request: request,
          brickContext: brickContext,
          currentFileSource: content,
        );
        final xml = serializer.serialize(envelope);
        logger
          ..info('')
          ..info('${cyan.wrap('=== $id ===')}')
          ..info('args: ${aiCall.toSyntax()}')
          ..info('')
          ..info(xml);
      }
    }
    logger
      ..info('')
      ..info('Total previewed tags: $total');
    return ExitCode.success.code;
  }

  static bool _ownLine(String src, int start, int end) {
    var i = start - 1;
    while (i >= 0) {
      final c = src[i];
      if (c == '\n') break;
      if (c != ' ' && c != '\t' && c != '\r') return false;
      i--;
    }
    var j = end;
    while (j < src.length) {
      final c = src[j];
      if (c == '\n') break;
      if (c != ' ' && c != '\t' && c != '\r') return false;
      j++;
    }
    return true;
  }
}
