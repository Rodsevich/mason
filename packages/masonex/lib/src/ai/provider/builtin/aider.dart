// ignore_for_file: public_member_api_docs, lines_longer_than_80_chars

import 'dart:io';

import 'package:masonex/src/ai/provider/adapter.dart';
import 'package:masonex/src/ai/provider/builtin/cli_runner.dart';
import 'package:masonex/src/ai/provider/config_yaml.dart';
import 'package:masonex/src/ai/provider/descriptor.dart';
import 'package:masonex/src/ai/provider/invocation.dart';

/// Adapter for `aider` running in non-interactive `--message-file` mode.
///
/// Aider does not have a system-prompt flag in non-interactive mode, so
/// masonex prepends the system instructions to the user envelope.
class AiderProviderAdapter implements AiProviderAdapter {
  AiderProviderAdapter({ProviderConfig? config})
      : config = config ?? defaultConfig;

  static final ProviderConfig defaultConfig = ProviderConfig(
    id: 'aider',
    cmd: const ['aider', '--no-stream', '--yes-always', '--message-file'],
    passPrompt: PassMode.arg,
    timeout: const Duration(seconds: 180),
    notes: 'Aider (non-interactive --message-file mode)',
  );

  static const AiProviderDescriptor staticDescriptor = AiProviderDescriptor(
    id: 'aider',
    displayName: 'Aider',
    requiredCommand: 'aider',
    helpUrl: 'https://aider.chat',
  );

  final ProviderConfig config;

  @override
  AiProviderDescriptor get descriptor => staticDescriptor;

  @override
  Future<bool> isAvailable() async {
    try {
      final result = await Process.run(config.cmd.first, ['--version']);
      return result.exitCode == 0;
    } on ProcessException {
      return false;
    }
  }

  @override
  Future<AiInvocationResult> invoke(
    AiInvocation request, {
    required Duration timeout,
  }) {
    return CliProviderRunner(config: config).run(request, timeout: timeout);
  }
}
