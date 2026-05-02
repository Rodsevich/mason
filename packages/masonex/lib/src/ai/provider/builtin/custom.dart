// ignore_for_file: public_member_api_docs, lines_longer_than_80_chars

import 'dart:io';

import 'package:masonex/src/ai/provider/adapter.dart';
import 'package:masonex/src/ai/provider/builtin/cli_runner.dart';
import 'package:masonex/src/ai/provider/config_yaml.dart';
import 'package:masonex/src/ai/provider/descriptor.dart';
import 'package:masonex/src/ai/provider/invocation.dart';

/// User-defined provider, fully described by a [ProviderConfig] entry from
/// `~/.masonex/providers.yaml`. masonex does not assume anything about the
/// underlying CLI; the runner just executes whatever the config says.
class CustomProviderAdapter implements AiProviderAdapter {
  CustomProviderAdapter(this.config);

  final ProviderConfig config;

  @override
  AiProviderDescriptor get descriptor => AiProviderDescriptor(
        id: config.id,
        displayName: config.id,
        requiredCommand: config.cmd.first,
        notes: config.notes,
      );

  @override
  Future<bool> isAvailable() async {
    try {
      final result = await Process.run(config.cmd.first, const ['--version']);
      return result.exitCode == 0;
    } on ProcessException {
      // Some CLIs don't accept --version; treat as available iff the binary
      // resolved (Process.run threw only if not found).
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
