// ignore_for_file: public_member_api_docs, lines_longer_than_80_chars

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Append-only JSONL log of AI invocations under `cache/ai/trace.jsonl`.
class AiTrace {
  AiTrace(this.cacheRoot);

  final String cacheRoot;

  File get file => File(p.join(cacheRoot, 'trace.jsonl'));

  Future<void> append({
    required String tagId,
    required String promptHash,
    required String envelopeHash,
    required String systemHash,
    required String provider,
    required Duration duration,
    required int retries,
    required bool fromCache,
    required String cacheDecision,
    required String outputHash,
    required String validation,
    String? model,
  }) async {
    await Directory(cacheRoot).create(recursive: true);
    final entry = jsonEncode({
      'ts': DateTime.now().toUtc().toIso8601String(),
      'tag_id': tagId,
      'prompt_hash': promptHash,
      'envelope_hash': envelopeHash,
      'system_hash': systemHash,
      'provider': provider,
      'model': model,
      'duration_ms': duration.inMilliseconds,
      'retries': retries,
      'from_cache': fromCache,
      'cache_decision': cacheDecision,
      'output_hash': outputHash,
      'validation': validation,
    });
    await _lock(() async {
      await file.writeAsString('$entry\n', mode: FileMode.append);
    });
  }

  Future<List<Map<String, dynamic>>> readAll({int? lastN}) async {
    if (!file.existsSync()) return [];
    final lines = await file.readAsLines();
    final all = lines
        .where((l) => l.trim().isNotEmpty)
        .map<Map<String, dynamic>>(
          (l) => jsonDecode(l) as Map<String, dynamic>,
        )
        .toList();
    if (lastN == null || lastN >= all.length) return all;
    return all.sublist(all.length - lastN);
  }

  // Per-process lock; acceptable for masonex's single-CLI usage. Multi-
  // process safety would require a real file lock.
  static Future<void> _lock(FutureOr<void> Function() body) async {
    final completer = Completer<void>();
    _queue.add(() async {
      await body();
      completer.complete();
    });
    if (!_running) {
      _running = true;
      while (_queue.isNotEmpty) {
        final next = _queue.removeAt(0);
        await next();
      }
      _running = false;
    }
    return completer.future;
  }

  static final List<Future<void> Function()> _queue = [];
  static bool _running = false;
}
