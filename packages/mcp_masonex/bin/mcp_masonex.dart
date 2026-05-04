import 'dart:io';

import 'package:mcp_dart/mcp_dart.dart';
import 'package:mcp_masonex/mcp_masonex.dart';

/// Entrypoint for the `mcp_masonex` MCP server. Listens on stdio.
///
/// Optional flags:
///   `--masonex-bin <path>`   Path to the masonex binary (default: looks
///                            up `masonex` on PATH).
///   `--workspace <dir>`      Default working directory used by tools when
///                            they do not receive an explicit `workspace`.
///   `--verbose`              Print extra diagnostics to STDERR.
///
/// IMPORTANT: this server uses stdio for the MCP protocol — STDOUT must
/// only contain MCP frames. All diagnostic output goes to STDERR.
Future<void> main(List<String> args) async {
  final options = _parseArgs(args);
  if (options.verbose) {
    stderr.writeln(
      'mcp_masonex: starting (binary=${options.masonexBin ?? 'masonex'}, '
      'workspace=${options.workspace ?? '<cwd>'})',
    );
  }

  final runner = MasonexRunner(
    executable: options.masonexBin,
    defaultWorkingDirectory: options.workspace,
  );
  final server = buildServer(runner: runner);
  await server.connect(StdioServerTransport());
}

class _CliOptions {
  const _CliOptions({
    this.masonexBin,
    this.workspace,
    this.verbose = false,
  });

  final String? masonexBin;
  final String? workspace;
  final bool verbose;
}

_CliOptions _parseArgs(List<String> args) {
  String? bin;
  String? workspace;
  var verbose = false;
  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    String? value() => i + 1 < args.length ? args[++i] : null;
    switch (a) {
      case '--masonex-bin':
        bin = value();
      case '--workspace':
        workspace = value();
      case '-v':
      case '--verbose':
        verbose = true;
      case '-h':
      case '--help':
        stderr.writeln(
          'Usage: mcp_masonex [--masonex-bin <path>] '
          '[--workspace <dir>] [--verbose]',
        );
        exit(0);
      default:
        stderr.writeln('mcp_masonex: ignoring unknown flag "$a"');
    }
  }
  return _CliOptions(
    masonexBin: bin,
    workspace: workspace,
    verbose: verbose,
  );
}
