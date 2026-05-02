// ignore_for_file: public_member_api_docs, lines_longer_than_80_chars

import 'dart:io';

import 'package:masonex/masonex.dart';
import 'package:masonex/src/ai/ai.dart';
import 'package:masonex/src/cli/command.dart';
import 'package:path/path.dart' as p;

/// `masonex ai-cache stats|clear` — inspect or wipe `.masonex/cache/ai/`.
class AiCacheCommand extends MasonexCommand {
  AiCacheCommand({Logger? logger}) : super(logger: logger) {
    addSubcommand(_AiCacheStatsCommand(logger: logger));
    addSubcommand(_AiCacheClearCommand(logger: logger));
  }

  @override
  String get description => 'Manage the AI output cache.';

  @override
  String get name => 'ai-cache';
}

class _AiCacheStatsCommand extends MasonexCommand {
  _AiCacheStatsCommand({super.logger});

  @override
  String get description => 'Print stats for .masonex/cache/ai/.';

  @override
  String get name => 'stats';

  @override
  Future<int> run() async {
    final root = p.join(Directory.current.path, '.masonex', 'cache', 'ai');
    final cache = AiCache(root);
    final size = await cache.sizeBytes();
    final outputs = Directory(p.join(root, 'outputs'));
    final count = outputs.existsSync()
        ? outputs.listSync().whereType<File>().length
        : 0;
    logger
      ..info('cache root: $root')
      ..info('cached outputs: $count')
      ..info('size: ${(size / 1024).toStringAsFixed(1)} KiB');
    return ExitCode.success.code;
  }
}

class _AiCacheClearCommand extends MasonexCommand {
  _AiCacheClearCommand({super.logger});

  @override
  String get description => 'Delete .masonex/cache/ai/.';

  @override
  String get name => 'clear';

  @override
  Future<int> run() async {
    final root = p.join(Directory.current.path, '.masonex', 'cache', 'ai');
    await AiCache(root).clear();
    logger.info('Cleared $root');
    return ExitCode.success.code;
  }
}
