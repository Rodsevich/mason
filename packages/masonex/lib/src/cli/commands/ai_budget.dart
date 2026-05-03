// ignore_for_file: public_member_api_docs, lines_longer_than_80_chars

import 'dart:io';

import 'package:masonex/masonex.dart';
import 'package:masonex/src/ai/ai.dart';
import 'package:masonex/src/cli/command.dart';
import 'package:path/path.dart' as p;

/// `masonex ai-budget --brick <path> [--budget <tokens>]` — heuristic
/// token estimate per `| ai` tag in a brick. Useful for spotting tags
/// that risk exceeding a model's context window before running them.
///
/// Estimation is intentionally crude: ~`len/4` tokens-per-char for
/// English-ish prose. Good enough for "is this in the right
/// neighborhood" decisions; not a substitute for the real tokenizer.
class AiBudgetCommand extends MasonexCommand {
  AiBudgetCommand({super.logger}) {
    argParser
      ..addOption(
        'brick',
        abbr: 'b',
        help: 'Path to the brick directory (default: cwd).',
      )
      ..addOption(
        'budget',
        help: 'Token budget per tag. Tags above the budget are flagged.',
        defaultsTo: '8000',
      );
  }

  @override
  String get description =>
      'Estimate tokens for each `| ai` tag in a brick.';

  @override
  String get name => 'ai-budget';

  @override
  Future<int> run() async {
    final brickRoot =
        (argResults?['brick'] as String?) ?? Directory.current.path;
    final brickDir = Directory(p.join(brickRoot, '__brick__'));
    if (!brickDir.existsSync()) {
      logger.err('No __brick__/ directory at ${brickDir.path}');
      return ExitCode.usage.code;
    }
    final budget =
        int.tryParse((argResults?['budget'] as String?) ?? '8000') ?? 8000;

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
    var flagged = 0;
    await for (final entity in brickDir.list(recursive: true)) {
      if (entity is! File) continue;
      String content;
      try {
        content = await entity.readAsString();
      } on FileSystemException {
        continue;
      }
      final relative = p.relative(entity.path, from: brickDir.parent.path);
      for (final tag in TagFinder(content).find()) {
        final node = PipelineParser.fromTag(tag.content).parse();
        if (node == null || !node.hasAi) continue;
        total++;

        final id = '$relative#L${tag.line}:c${tag.column}';
        final request = AiTagRequest(
          id: id,
          syntheticVarName: '__masonex_ai_preview',
          relativePath: relative,
          line: tag.line,
          column: tag.column,
          prompt: node.head,
          node: node,
          tagOriginal: tag.content,
          inlineHint: false,
        );
        final envelope = builder.build(
          request: request,
          brickContext: brickContext,
          currentFileSource: content,
        );
        final xml = serializer.serialize(envelope);
        // System prompt + envelope ≈ what the model sees (input only).
        final inputChars = aiSystemPrompt.length + xml.length;
        final estTokens = (inputChars / 4).round();
        final flag = estTokens > budget ? red.wrap(' OVER!') : '';
        flagged += estTokens > budget ? 1 : 0;
        logger.info(
          '${estTokens.toString().padLeft(7)} tok  $id$flag',
        );
      }
    }
    logger
      ..info('')
      ..info('Total tags: $total. Over budget ($budget): $flagged.');
    return flagged == 0 ? ExitCode.success.code : ExitCode.data.code;
  }
}
