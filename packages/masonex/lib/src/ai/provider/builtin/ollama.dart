// ignore_for_file: public_member_api_docs, lines_longer_than_80_chars

import 'dart:io';

import 'package:masonex/src/ai/provider/adapter.dart';
import 'package:masonex/src/ai/provider/builtin/cli_runner.dart';
import 'package:masonex/src/ai/provider/config_yaml.dart';
import 'package:masonex/src/ai/provider/descriptor.dart';
import 'package:masonex/src/ai/provider/invocation.dart';

/// Adapter for the local `ollama` CLI.
///
/// `ollama run <model>` reads the user prompt from stdin and writes the
/// response to stdout. The system prompt is injected via the model's
/// `--system` flag when supported; otherwise masonex prepends it to the
/// user envelope.
///
/// Customise the model by editing the `cmd` list in
/// `~/.masonex/providers.yaml` (e.g., replace `llama3.1` with
/// `qwen2.5-coder:14b`).
class OllamaProviderAdapter implements AiProviderAdapter {
  OllamaProviderAdapter({ProviderConfig? config})
      : config = config ?? defaultConfig;

  static final ProviderConfig defaultConfig = ProviderConfig(
    id: 'ollama',
    cmd: const ['ollama', 'run', 'llama3.1'],
    passPrompt: PassMode.stdin,
    timeout: const Duration(seconds: 240),
    notes: 'Local Ollama runtime; edit cmd to change the model.',
  );

  static const AiProviderDescriptor staticDescriptor = AiProviderDescriptor(
    id: 'ollama',
    displayName: 'Ollama (local)',
    requiredCommand: 'ollama',
    helpUrl: 'https://ollama.com',
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
