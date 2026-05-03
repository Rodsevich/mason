// ignore_for_file: public_member_api_docs, lines_longer_than_80_chars

import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:masonex/src/ai/errors.dart';
import 'package:masonex/src/ai/i18n.dart';
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
  final i18n = AiI18n.fromEnv();
  logger
    ..err(i18n.tr('providerFailed', params: {'message': cause.message}))
    ..info('');
  final editLabel = i18n.tr('editAndRetry');
  final abortLabel = i18n.tr('abortRender');
  final choice = logger.chooseOne(
    i18n.tr('choose'),
    choices: [editLabel, abortLabel],
  );
  if (choice == abortLabel) return RecoveryDecision.abort;
  await _openEditor(configPath ?? ProvidersYaml.defaultPath(), logger, i18n);
  return RecoveryDecision.editAndRetry;
}

Future<void> _openEditor(String path, Logger logger, AiI18n i18n) async {
  final editor = Platform.environment['EDITOR']
      ?? Platform.environment['VISUAL']
      ?? (Platform.isWindows ? 'notepad' : 'vi');
  logger.info(i18n.tr('openingEditor', params: {'path': path, 'editor': editor}));
  try {
    final result = await Process.run(editor, [path], runInShell: true);
    if (result.exitCode != 0) {
      logger.warn(
        i18n.tr('editorExitedNonZero', params: {'code': '${result.exitCode}'}),
      );
    }
  } on ProcessException catch (e) {
    logger.warn(i18n.tr('launchFailed', params: {'message': e.message}));
  }
}
