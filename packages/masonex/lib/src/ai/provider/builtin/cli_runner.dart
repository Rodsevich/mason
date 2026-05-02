// ignore_for_file: public_member_api_docs, lines_longer_than_80_chars

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:masonex/src/ai/errors.dart';
import 'package:masonex/src/ai/provider/config_yaml.dart';
import 'package:masonex/src/ai/provider/invocation.dart';
import 'package:path/path.dart' as p;

/// Generic runner that executes a configured CLI provider.
///
/// Handles three ways to pass the prompt (stdin / tmpfile / arg) and the
/// system instructions (via flag or prepended to the user prompt when the
/// CLI does not support a system role).
class CliProviderRunner {
  const CliProviderRunner({required this.config});

  final ProviderConfig config;

  Future<AiInvocationResult> run(
    AiInvocation invocation, {
    required Duration timeout,
  }) async {
    final stopwatch = Stopwatch()..start();
    final args = List<String>.from(config.cmd.skip(1));
    final exec = config.cmd.first;

    String? tmpPromptPath;
    File? tmpFile;
    var promptToWrite = invocation.userEnvelope;

    final passSystem = config.passSystem;
    if (passSystem != null && passSystem.isNotEmpty) {
      // System prompt passed as a flag value via the configured args.
      // Substitute `{system}` placeholder if present, otherwise append.
      var injected = false;
      for (var i = 0; i < passSystem.length; i++) {
        if (passSystem[i].contains('{system}')) {
          args.add(passSystem[i].replaceAll(
            '{system}',
            invocation.systemPrompt,
          ));
          injected = true;
        } else {
          args.add(passSystem[i]);
          if (i + 1 == passSystem.length) {
            args.add(invocation.systemPrompt);
            injected = true;
          }
        }
      }
      if (!injected) {
        args.add(invocation.systemPrompt);
      }
    } else {
      // Prepend system to user prompt with a clear marker.
      promptToWrite = '<<MASONEX_SYSTEM>>\n${invocation.systemPrompt}\n'
          '<<MASONEX_END_SYSTEM>>\n$promptToWrite';
    }

    switch (config.passPrompt) {
      case PassMode.tmpfile:
        tmpFile = await _writeTmp(promptToWrite);
        tmpPromptPath = tmpFile.path;
        args.add(tmpPromptPath);
      case PassMode.arg:
        args.add(promptToWrite);
      case PassMode.stdin:
        // handled below
        break;
    }

    Process process;
    try {
      process = await Process.start(exec, args);
    } on ProcessException {
      throw AiProviderUnavailableError(config.id, exec);
    }

    if (config.passPrompt == PassMode.stdin) {
      process.stdin.add(utf8.encode(promptToWrite));
      await process.stdin.close();
    }

    final stdoutF = process.stdout.transform(utf8.decoder).join();
    final stderrF = process.stderr.transform(utf8.decoder).join();

    int? exitCode;
    try {
      exitCode = await process.exitCode.timeout(timeout);
    } on TimeoutException {
      process.kill(ProcessSignal.sigkill);
      throw AiTimeoutError(config.id, timeout);
    }
    final out = await stdoutF;
    final err = await stderrF;

    if (tmpFile != null && tmpFile.existsSync()) {
      try {
        tmpFile.deleteSync();
      } on FileSystemException {
        // best-effort cleanup
      }
    }

    if (exitCode != 0) {
      final preview = _previewStderr(err);
      if (_looksLikeAuthFailure(err)) {
        throw AiAuthError(config.id, preview);
      }
      throw AiProviderInvocationError(config.id, exitCode, preview);
    }

    stopwatch.stop();
    return AiInvocationResult(
      stdout: out,
      duration: stopwatch.elapsed,
      stderrPreview: err,
    );
  }

  Future<File> _writeTmp(String content) async {
    final dir = await Directory.systemTemp.createTemp('masonex_ai_');
    final f = File(p.join(dir.path, 'prompt.xml'));
    await f.writeAsString(content);
    return f;
  }

  static String _previewStderr(String s) {
    final trimmed = s.trim();
    if (trimmed.length <= 400) return trimmed;
    return '${trimmed.substring(0, 400)}…';
  }

  static bool _looksLikeAuthFailure(String s) {
    final lower = s.toLowerCase();
    return lower.contains('not authenticated')
        || lower.contains('unauthorized')
        || lower.contains('login required')
        || lower.contains('please log in');
  }
}
