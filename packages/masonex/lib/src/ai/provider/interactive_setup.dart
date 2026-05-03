// ignore_for_file: public_member_api_docs, lines_longer_than_80_chars

import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:masonex/src/ai/i18n.dart';
import 'package:masonex/src/ai/provider/config_yaml.dart';
import 'package:masonex/src/ai/provider/registry.dart';

/// Result of the interactive setup wizard.
class SetupOutcome {
  const SetupOutcome({required this.config, required this.providerId});
  final ProvidersYaml config;
  final String providerId;
}

/// Walks the user through the first-time setup, persisting
/// `~/.masonex/providers.yaml`. Returns null if the user aborted.
Future<SetupOutcome?> runInteractiveSetup({
  required Logger logger,
  String? configPath,
}) async {
  final i18n = AiI18n.fromEnv();
  logger
    ..info(i18n.tr('noProviderConfigured'))
    ..info(i18n.tr('detectingClis'));
  final detected = <String>[];
  for (final desc in builtinProviderDescriptors) {
    if (await _isOnPath(desc.requiredCommand)) {
      detected.add(desc.id);
    }
  }
  if (detected.isEmpty) {
    logger.warn(i18n.tr('noClisDetected'));
  } else {
    logger.info(i18n.tr('detectedList', params: {'list': detected.join(', ')}));
  }

  final manualLabel = i18n.tr('configureManually');
  final abortLabel = i18n.tr('abort');
  final choices = [
    ...detected,
    manualLabel,
    abortLabel,
  ];
  final chosen = logger.chooseOne(
    i18n.tr('pickProvider'),
    choices: choices,
  );
  if (chosen == abortLabel) return null;

  ProviderConfig cfg;
  String id;
  if (chosen == manualLabel) {
    final wizard = await _customWizard(logger);
    if (wizard == null) return null;
    id = wizard.id;
    cfg = wizard;
  } else {
    id = chosen;
    cfg = _defaultConfigFor(id);
  }

  final yaml = ProvidersYaml(
    defaultProvider: id,
    providers: {id: cfg},
  );
  await yaml.save(configPath);
  logger.info(
    i18n.tr(
      'savedConfig',
      params: {'path': configPath ?? ProvidersYaml.defaultPath()},
    ),
  );
  return SetupOutcome(config: yaml, providerId: id);
}

Future<ProviderConfig?> _customWizard(Logger logger) async {
  final id = logger.prompt('Provider id (e.g., my_local):').trim();
  if (id.isEmpty) return null;
  final cmdRaw = logger
      .prompt('Command (space-separated, first token is the binary):')
      .trim();
  if (cmdRaw.isEmpty) return null;
  final cmd = cmdRaw.split(RegExp(r'\s+'));
  final passModeRaw = logger.chooseOne(
    'How does the CLI want the prompt?',
    choices: ['stdin', 'tmpfile', 'arg'],
  );
  final passMode = PassMode.values.firstWhere((m) => m.name == passModeRaw);
  final passSystemRaw = logger
      .prompt('Flags to pass the system prompt (empty = prepend to user):')
      .trim();
  final passSystem = passSystemRaw.isEmpty
      ? null
      : passSystemRaw.split(RegExp(r'\s+'));
  final timeoutRaw = logger.prompt('Timeout (default 60s):').trim();
  final timeout = timeoutRaw.isEmpty
      ? const Duration(seconds: 60)
      : _parseDurationOrDefault(timeoutRaw);
  return ProviderConfig(
    id: id,
    cmd: cmd,
    passPrompt: passMode,
    passSystem: passSystem,
    timeout: timeout,
    notes: 'configured manually on ${DateTime.now().toIso8601String()}',
  );
}

ProviderConfig _defaultConfigFor(String id) {
  final builtin = defaultConfigFor(id);
  if (builtin != null) return builtin;
  // Best-effort default for unknown descriptors.
  return ProviderConfig(
    id: id,
    cmd: [id],
    passPrompt: PassMode.stdin,
    timeout: const Duration(seconds: 60),
    notes: 'auto-suggested default; verify with `masonex provider test`.',
  );
}

Duration _parseDurationOrDefault(String raw) {
  final m = RegExp(r'^(\d+)\s*([smh])?$').firstMatch(raw);
  if (m == null) return const Duration(seconds: 60);
  final n = int.parse(m.group(1)!);
  switch (m.group(2)) {
    case 'm':
      return Duration(minutes: n);
    case 'h':
      return Duration(hours: n);
    case 's':
    case null:
      return Duration(seconds: n);
  }
  return Duration(seconds: n);
}

Future<bool> _isOnPath(String cmd) async {
  if (cmd.isEmpty) return false;
  final which = Platform.isWindows ? 'where' : 'which';
  try {
    final r = await Process.run(which, [cmd]);
    return r.exitCode == 0;
  } on ProcessException {
    return false;
  }
}
