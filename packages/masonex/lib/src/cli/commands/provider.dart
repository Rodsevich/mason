// ignore_for_file: public_member_api_docs, lines_longer_than_80_chars

import 'dart:io';

import 'package:masonex/masonex.dart';
import 'package:masonex/src/ai/ai.dart';
import 'package:masonex/src/ai/provider/interactive_setup.dart';
import 'package:masonex/src/cli/command.dart';

/// `masonex provider <show|edit|test|reset|setup>` — manage
/// `~/.masonex/providers.yaml`.
class ProviderCommand extends MasonexCommand {
  ProviderCommand({Logger? logger}) : super(logger: logger) {
    addSubcommand(_ProviderShowCommand(logger: logger));
    addSubcommand(_ProviderEditCommand(logger: logger));
    addSubcommand(_ProviderTestCommand(logger: logger));
    addSubcommand(_ProviderResetCommand(logger: logger));
    addSubcommand(_ProviderSetupCommand(logger: logger));
  }

  @override
  String get description => 'Manage AI provider configuration.';

  @override
  String get name => 'provider';
}

class _ProviderShowCommand extends MasonexCommand {
  _ProviderShowCommand({super.logger});

  @override
  String get description =>
      'Print the current provider configuration (no secrets).';

  @override
  String get name => 'show';

  @override
  Future<int> run() async {
    final cfg = await ProvidersYaml.load();
    if (cfg == null) {
      logger.warn('No providers configured at ${ProvidersYaml.defaultPath()}.');
      return ExitCode.success.code;
    }
    logger.info('default: ${cfg.defaultProvider}');
    for (final entry in cfg.providers.entries) {
      final c = entry.value;
      logger
        ..info('  ${entry.key}:')
        ..info('    cmd: ${c.cmd.join(" ")}')
        ..info('    pass_prompt: ${c.passPrompt.name}')
        ..info(
          '    pass_system: ${c.passSystem == null ? "<prepend>" : c.passSystem!.join(" ")}',
        )
        ..info('    timeout: ${c.timeout.inSeconds}s');
      if (c.notes != null) logger.info('    notes: ${c.notes}');
    }
    return ExitCode.success.code;
  }
}

class _ProviderEditCommand extends MasonexCommand {
  _ProviderEditCommand({super.logger});

  @override
  String get description => 'Open ~/.masonex/providers.yaml in \$EDITOR.';

  @override
  String get name => 'edit';

  @override
  Future<int> run() async {
    final path = ProvidersYaml.defaultPath();
    final editor = Platform.environment['EDITOR']
        ?? Platform.environment['VISUAL']
        ?? (Platform.isWindows ? 'notepad' : 'vi');
    try {
      final r = await Process.run(editor, [path], runInShell: true);
      return r.exitCode;
    } on ProcessException catch (e) {
      logger.err('Failed to launch $editor: ${e.message}');
      return ExitCode.unavailable.code;
    }
  }
}

class _ProviderTestCommand extends MasonexCommand {
  _ProviderTestCommand({super.logger});

  @override
  String get description =>
      'Send a trivial prompt to the configured provider and print the reply.';

  @override
  String get name => 'test';

  @override
  Future<int> run() async {
    final cfg = await ProvidersYaml.load();
    if (cfg == null) {
      logger.err('No providers configured.');
      return ExitCode.config.code;
    }
    final entry = cfg.providers[cfg.defaultProvider];
    if (entry == null) {
      logger.err('Default provider not found in config.');
      return ExitCode.config.code;
    }
    final adapter = buildAdapter(entry);
    logger.info('Testing provider "${entry.id}" ...');
    final invocation = AiInvocation(
      systemPrompt: aiSystemPrompt,
      userEnvelope: '<masonex_render_request version="1">'
          '<task><prompt><![CDATA[Respond with exactly the word: ok]]>'
          '</prompt><expected_shape>a single word</expected_shape>'
          '<constraints/><post_filters/><author_note/>'
          '</task></masonex_render_request>',
    );
    try {
      final result = await adapter.invoke(
        invocation,
        timeout: entry.timeout,
      );
      logger
        ..info('  reply: ${result.stdout.trim()}')
        ..info('  duration: ${result.duration.inMilliseconds}ms');
      return ExitCode.success.code;
    } on AiException catch (e) {
      logger.err('Test failed: ${e.message}');
      return ExitCode.unavailable.code;
    }
  }
}

class _ProviderResetCommand extends MasonexCommand {
  _ProviderResetCommand({super.logger});

  @override
  String get description => 'Delete ~/.masonex/providers.yaml after confirm.';

  @override
  String get name => 'reset';

  @override
  Future<int> run() async {
    final path = ProvidersYaml.defaultPath();
    final f = File(path);
    if (!f.existsSync()) {
      logger.info('Nothing to delete: $path does not exist.');
      return ExitCode.success.code;
    }
    final ok = logger.confirm(
      'Delete $path? This cannot be undone.',
    );
    if (!ok) return ExitCode.success.code;
    f.deleteSync();
    logger.info('Deleted $path');
    return ExitCode.success.code;
  }
}

class _ProviderSetupCommand extends MasonexCommand {
  _ProviderSetupCommand({super.logger});

  @override
  String get description => 'Run the interactive provider setup wizard.';

  @override
  String get name => 'setup';

  @override
  Future<int> run() async {
    final outcome = await runInteractiveSetup(logger: logger);
    if (outcome == null) {
      logger.warn('Setup aborted; no changes made.');
      return ExitCode.cantCreate.code;
    }
    logger.info('Default provider: ${outcome.providerId}');
    return ExitCode.success.code;
  }
}

