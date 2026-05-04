import 'dart:convert';

import 'package:mcp_dart/mcp_dart.dart';
import 'package:mcp_masonex/src/runner/masonex_runner.dart';

/// Empty JSON schema object — no properties, nothing required.
JsonSchema emptyObjectSchema() => JsonSchema.object(
      properties: <String, JsonSchema>{},
      required: const <String>[],
    );

/// Schema for an optional `workspace` argument used by most tools.
JsonSchema workspaceSchema() => JsonSchema.string(
      description: 'Absolute path to the directory that contains '
          '`masonex.yaml` (or where it should be initialized). '
          'When omitted, the runner uses its default working directory.',
    );

/// Schema for an optional `timeoutSeconds` argument.
JsonSchema timeoutSchema({int defaultSeconds = 120}) => JsonSchema.integer(
      description:
          'Maximum seconds to wait for the underlying masonex process. '
          'Defaults to $defaultSeconds.',
      minimum: 1,
      maximum: 1800,
    );

/// Builds a JSON-serialised text content block with the runner result —
/// the canonical "process tool" output shape we hand back to agents.
List<Content> processResultContent(
  MasonexResult result, {
  String? note,
  Map<String, Object?> extra = const {},
}) {
  final summary = StringBuffer();
  if (note != null) summary.writeln(note);
  summary
    ..writeln('command: ${result.command.join(' ')}')
    ..writeln('exitCode: ${result.exitCode}'
        '${result.timedOut ? ' (timed out)' : ''}')
    ..writeln('duration: ${result.durationMs}ms');
  if (result.stdout.trim().isNotEmpty) {
    summary
      ..writeln('--- stdout ---')
      ..writeln(result.stdout.trimRight());
  }
  if (result.stderr.trim().isNotEmpty) {
    summary
      ..writeln('--- stderr ---')
      ..writeln(result.stderr.trimRight());
  }

  final structured = <String, Object?>{
    ...result.toJson(),
    ...extra,
  };
  return [
    TextContent(text: summary.toString().trimRight()),
    TextContent(text: jsonEncode(structured)),
  ];
}

/// Convenience: build a `CallToolResult` from a [MasonexResult]. `isError`
/// follows the process exit code unless overridden.
CallToolResult callToolResultFor(
  MasonexResult result, {
  String? note,
  bool? isError,
  Map<String, Object?> extra = const {},
}) {
  return CallToolResult.fromContent(
    processResultContent(result, note: note, extra: extra),
    isError: isError ?? !result.success,
  );
}

/// Exception raised by argument validators in this package. Plain
/// [Exception] (not [Error]) so callbacks can catch it without
/// triggering the `avoid_catching_errors` lint.
class ToolArgumentException implements Exception {
  ToolArgumentException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Validates a non-empty string argument and returns its trimmed value.
String requireString(Map<String, dynamic> args, String key) {
  final raw = args[key];
  if (raw is! String || raw.trim().isEmpty) {
    throw ToolArgumentException('`$key` must be a non-empty string');
  }
  return raw.trim();
}

/// Optional non-empty string.
String? optionalString(Map<String, dynamic> args, String key) {
  final raw = args[key];
  if (raw == null) return null;
  if (raw is! String) {
    throw ToolArgumentException('`$key` must be a string');
  }
  final trimmed = raw.trim();
  return trimmed.isEmpty ? null : trimmed;
}

/// Optional bool with default.
bool optionalBool(
  Map<String, dynamic> args,
  String key, {
  bool fallback = false,
}) {
  final raw = args[key];
  if (raw == null) return fallback;
  if (raw is bool) return raw;
  if (raw is String) {
    if (raw == 'true') return true;
    if (raw == 'false') return false;
  }
  throw ToolArgumentException('`$key` must be a boolean');
}

Duration? timeoutFromArgs(Map<String, dynamic> args) {
  final raw = args['timeoutSeconds'];
  if (raw == null) return null;
  if (raw is num) return Duration(seconds: raw.toInt());
  if (raw is String) {
    final parsed = int.tryParse(raw);
    if (parsed != null) return Duration(seconds: parsed);
  }
  throw ToolArgumentException('`timeoutSeconds` must be an integer');
}

/// Builds an error CallToolResult with [message]. Used for validation
/// problems that happen before we even invoke masonex.
CallToolResult validationError(String message) {
  return CallToolResult.fromContent(
    [TextContent(text: 'Validation error: $message')],
    isError: true,
  );
}
