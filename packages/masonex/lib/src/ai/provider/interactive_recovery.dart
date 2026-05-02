// ignore_for_file: public_member_api_docs, lines_longer_than_80_chars

import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:masonex/src/ai/errors.dart';
import 'package:masonex/src/ai/provider/config_yaml.dart';

/// Outcome of an interactive recovery prompt after a provider failure.
enum RecoveryDecision { editAndRetry, abort }

/// Shows a recovery prompt and either opens the user's $EDITOR on the
/// providers.yaml file (returning [editAndRetry]) or returns [abort].
Future<RecoveryDecision> recoverFromProviderFailure({
  required Logger logger,
  required AiException cause,
  String? configPath,
}) async {
  logger
    ..err('AI provider failed: ${cause.message}')
    ..info('');
  final choice = logger.chooseOne(
    'Choose:',
    choices: [
      'edit ~/.masonex/providers.yaml and retry',
      'abort the render',
    ],
  );
  if (choice.startsWith('abort')) return RecoveryDecision.abort;
  await _openEditor(configPath ?? ProvidersYaml.defaultPath(), logger);
  return RecoveryDecision.editAndRetry;
}

Future<void> _openEditor(String path, Logger logger) async {
  final editor = Platform.environment['EDITOR']
      ?? Platform.environment['VISUAL']
      ?? (Platform.isWindows ? 'notepad' : 'vi');
  logger.info('Opening $path in $editor...');
  try {
    final result = await Process.run(editor, [path], runInShell: true);
    if (result.exitCode != 0) {
      logger.warn('Editor exited with code ${result.exitCode}.');
    }
  } on ProcessException catch (e) {
    logger.warn('Could not launch editor: ${e.message}');
  }
}
