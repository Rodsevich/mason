// ignore_for_file: public_member_api_docs, lines_longer_than_80_chars

import 'dart:io';

import 'package:masonex/src/ai/provider/adapter.dart';
import 'package:masonex/src/ai/provider/builtin/cli_runner.dart';
import 'package:masonex/src/ai/provider/config_yaml.dart';
import 'package:masonex/src/ai/provider/descriptor.dart';
import 'package:masonex/src/ai/provider/invocation.dart';

/// Adapter for Google's `gemini` CLI.
///
/// Uses non-interactive mode (`--prompt-file` for the user envelope and a
/// `--system-instruction` flag for the system prompt). Falls back to
/// prepending the system prompt to the user envelope when the installed
/// CLI does not understand the system flag (the [CliProviderRunner]
/// handles this transparently when `pass_system: null`).
class GeminiProviderAdapter implements AiProviderAdapter {
  GeminiProviderAdapter({ProviderConfig? config})
      : config = config ?? defaultConfig;

  static final ProviderConfig defaultConfig = ProviderConfig(
    id: 'gemini',
    cmd: const ['gemini', '--non-interactive'],
    passPrompt: PassMode.tmpfile,
    passSystem: const ['--system-instruction', '{system}'],
    timeout: const Duration(seconds: 120),
    notes: 'Google Gemini CLI',
  );

  static const AiProviderDescriptor staticDescriptor = AiProviderDescriptor(
    id: 'gemini',
    displayName: 'Gemini (Google CLI)',
    requiredCommand: 'gemini',
    helpUrl: 'https://github.com/google-gemini/gemini-cli',
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
