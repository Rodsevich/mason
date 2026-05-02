// ignore_for_file: public_member_api_docs, lines_longer_than_80_chars

import 'dart:io';

import 'package:path/path.dart' as p;

/// Cache policy declared per tag via the `cache:` argument.
enum CachePolicy { auto, always, never }

CachePolicy parseCachePolicy(String? raw) {
  switch (raw) {
    case 'always':
      return CachePolicy.always;
    case 'never':
      return CachePolicy.never;
    case null:
    case 'auto':
      return CachePolicy.auto;
    default:
      throw ArgumentError.value(raw, 'cache', 'invalid cache policy');
  }
}

/// File-based content-addressed cache living under
/// `<projectRoot>/.masonex/cache/ai/`.
class AiCache {
  AiCache(this.rootDir);

  /// Absolute path to `.masonex/cache/ai/`.
  final String rootDir;

  Directory get _outputs => Directory(p.join(rootDir, 'outputs'));
  Directory get _prompts => Directory(p.join(rootDir, 'prompts'));
  Directory get _envelopes => Directory(p.join(rootDir, 'envelopes'));
  Directory get _system => Directory(p.join(rootDir, 'system'));

  Future<void> ensureLayout() async {
    await Directory(rootDir).create(recursive: true);
    await _outputs.create(recursive: true);
    await _prompts.create(recursive: true);
    await _envelopes.create(recursive: true);
    await _system.create(recursive: true);
  }

  Future<String?> readOutput(String key) async {
    final f = File(p.join(_outputs.path, '$key.txt'));
    if (!f.existsSync()) return null;
    return f.readAsString();
  }

  Future<void> writeOutput({
    required String key,
    required String output,
    required String prompt,
    required String envelopeXml,
    required String systemPrompt,
    required String systemHash,
  }) async {
    await ensureLayout();
    await File(p.join(_outputs.path, '$key.txt')).writeAsString(output);
    await File(p.join(_prompts.path, '$key.md')).writeAsString(prompt);
    await File(p.join(_envelopes.path, '$key.xml'))
        .writeAsString(envelopeXml);
    final sysFile = File(p.join(_system.path, '$systemHash.md'));
    if (!sysFile.existsSync()) {
      await sysFile.writeAsString(systemPrompt);
    }
  }

  Future<void> clear() async {
    if (!Directory(rootDir).existsSync()) return;
    await Directory(rootDir).delete(recursive: true);
  }

  Future<int> sizeBytes() async {
    if (!Directory(rootDir).existsSync()) return 0;
    var total = 0;
    await for (final entity
        in Directory(rootDir).list(recursive: true, followLinks: false)) {
      if (entity is File) {
        total += await entity.length();
      }
    }
    return total;
  }
}
