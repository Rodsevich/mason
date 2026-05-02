// ignore_for_file: public_member_api_docs, lines_longer_than_80_chars

import 'dart:io';

import 'package:masonex/src/ai/provider/adapter.dart';
import 'package:masonex/src/ai/provider/builtin/cli_runner.dart';
import 'package:masonex/src/ai/provider/config_yaml.dart';
import 'package:masonex/src/ai/provider/descriptor.dart';
import 'package:masonex/src/ai/provider/invocation.dart';

/// Adapter that drives Anthropic's `claude` CLI (Claude Code) in print mode.
///
/// The default invocation uses `claude -p --output-format text` and passes
/// the system prompt via `--append-system-prompt`. The user prompt (envelope
/// XML) is passed via stdin to avoid shell-argument length limits.
class ClaudeProviderAdapter implements AiProviderAdapter {
  ClaudeProviderAdapter({ProviderConfig? config})
      : config = config ?? defaultConfig;

  static final ProviderConfig defaultConfig = ProviderConfig(
    id: 'claude',
    cmd: const ['claude', '-p', '--output-format', 'text'],
    passPrompt: PassMode.stdin,
    passSystem: const ['--append-system-prompt'],
    timeout: const Duration(seconds: 120),
    notes: 'Anthropic Claude Code CLI',
  );

  static const AiProviderDescriptor staticDescriptor = AiProviderDescriptor(
    id: 'claude',
    displayName: 'Claude (Anthropic CLI)',
    requiredCommand: 'claude',
    helpUrl: 'https://docs.claude.com/en/docs/claude-code',
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
