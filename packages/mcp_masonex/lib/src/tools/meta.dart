import 'package:mcp_dart/mcp_dart.dart';
import 'package:mcp_masonex/src/runner/masonex_runner.dart';
import 'package:mcp_masonex/src/schema/common.dart';

/// Registers metadata-style tools: version + plain help passthrough.
void register(McpServer server, MasonexRunner runner) {
  server.registerTool(
    'masonex_version',
    description:
        'Returns the version of the underlying masonex CLI. Use this first '
        'when starting work to confirm masonex is installed and to record '
        'which version generated the output.',
    inputSchema: emptyObjectSchema(),
    callback: (Map<String, dynamic> args, dynamic extra) async {
      final result = await runner.run(['--version']);
      return callToolResultFor(result, note: 'masonex --version');
    },
  );

  server.registerTool(
    'masonex_help',
    description:
        'Returns the top-level masonex CLI help (or for a specific '
        'subcommand). Useful when an agent is unsure which flag to pass to '
        'a tool that wraps the CLI.',
    inputSchema: JsonSchema.object(
      properties: <String, JsonSchema>{
        'subcommand': JsonSchema.string(
          description:
              'Optional subcommand to fetch help for, e.g. "make", "add", '
              '"audit-ai".',
        ),
      },
      required: const <String>[],
    ),
    callback: (Map<String, dynamic> args, dynamic extra) async {
      final sub = optionalString(args, 'subcommand');
      final cmd = <String>['help', if (sub != null) sub];
      final result = await runner.run(cmd);
      return callToolResultFor(result);
    },
  );
}
