// ignore_for_file: public_member_api_docs, lines_longer_than_80_chars

import 'dart:io';

import 'package:masonex/src/ai/provider/adapter.dart';
import 'package:masonex/src/ai/provider/builtin/cli_runner.dart';
import 'package:masonex/src/ai/provider/config_yaml.dart';
import 'package:masonex/src/ai/provider/descriptor.dart';
import 'package:masonex/src/ai/provider/invocation.dart';

/// Adapter for the `cursor-agent` CLI.
///
/// The CLI does not expose a dedicated system-prompt flag, so masonex
/// prepends the system instructions to the user envelope with a
/// `<<MASONEX_SYSTEM>>` marker (handled by [CliProviderRunner] when
/// [ProviderConfig.passSystem] is null).
class CursorAgentProviderAdapter implements AiProviderAdapter {
  CursorAgentProviderAdapter({ProviderConfig? config})
      : config = config ?? defaultConfig;

  static final ProviderConfig defaultConfig = ProviderConfig(
    id: 'cursor-agent',
    cmd: const ['cursor-agent', '--print'],
    passPrompt: PassMode.tmpfile,
    timeout: const Duration(seconds: 120),
    notes: 'Cursor agent CLI',
  );

  static const AiProviderDescriptor staticDescriptor = AiProviderDescriptor(
    id: 'cursor-agent',
    displayName: 'Cursor agent CLI',
    requiredCommand: 'cursor-agent',
    helpUrl: 'https://docs.cursor.com',
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
