// ignore_for_file: public_member_api_docs, lines_longer_than_80_chars

import 'dart:io';

import 'package:masonex/masonex.dart';
import 'package:masonex/src/ai/ai.dart';
import 'package:masonex/src/cli/command.dart';
import 'package:path/path.dart' as p;

/// `masonex ai-trace [--last N] [--tag X]` — pretty-print recent entries
/// from `.masonex/cache/ai/trace.jsonl`.
class AiTraceCommand extends MasonexCommand {
  AiTraceCommand({super.logger}) {
    argParser
      ..addOption(
        'last',
        abbr: 'n',
        help: 'Show only the last N entries.',
      )
      ..addOption(
        'tag',
        help: 'Filter by tag id substring.',
      );
  }

  @override
  String get description => 'Inspect the AI invocation trace.';

  @override
  String get name => 'ai-trace';

  @override
  Future<int> run() async {
    final root = p.join(Directory.current.path, '.masonex', 'cache', 'ai');
    final trace = AiTrace(root);
    final lastRaw = argResults?['last'] as String?;
    final tagFilter = argResults?['tag'] as String?;
    final lastN = lastRaw == null ? null : int.tryParse(lastRaw);

    final entries = await trace.readAll(lastN: lastN);
    if (entries.isEmpty) {
      logger.info('No trace entries (have you rendered with `| ai` yet?).');
      return ExitCode.success.code;
    }
    var shown = 0;
    for (final e in entries) {
      final tagId = e['tag_id']?.toString() ?? '?';
      if (tagFilter != null && !tagId.contains(tagFilter)) continue;
      shown++;
      logger.info(
        '${e['ts']}  ${e['provider']}  '
        '${e['from_cache'] == true ? "[cache]" : "[live]"}  '
        '${e['duration_ms']}ms  retries=${e['retries']}  '
        'tag=$tagId',
      );
    }
    logger
      ..info('')
      ..info('Shown: $shown of ${entries.length}');
    return ExitCode.success.code;
  }
}
