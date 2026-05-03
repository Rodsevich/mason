// ignore_for_file: public_member_api_docs, lines_longer_than_80_chars

import 'dart:io';

import 'package:masonex/src/ai/provider/adapter.dart';
import 'package:masonex/src/ai/provider/builtin/cli_runner.dart';
import 'package:masonex/src/ai/provider/config_yaml.dart';
import 'package:masonex/src/ai/provider/descriptor.dart';
import 'package:masonex/src/ai/provider/invocation.dart';

/// Adapter for OpenAI's `codex` CLI (when installed).
///
/// The CLI is invoked in print/single-shot mode and the user envelope
/// is piped via stdin. masonex prepends the system prompt with a
/// machine-readable marker when [ProviderConfig.passSystem] is null.
class CodexProviderAdapter implements AiProviderAdapter {
  CodexProviderAdapter({ProviderConfig? config})
      : config = config ?? defaultConfig;

  static final ProviderConfig defaultConfig = ProviderConfig(
    id: 'codex',
    cmd: const ['codex', '-p'],
    passPrompt: PassMode.stdin,
    timeout: const Duration(seconds: 120),
    notes: 'OpenAI Codex CLI (when installed)',
  );

  static const AiProviderDescriptor staticDescriptor = AiProviderDescriptor(
    id: 'codex',
    displayName: 'Codex (OpenAI CLI)',
    requiredCommand: 'codex',
    helpUrl: 'https://github.com/openai/codex',
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
