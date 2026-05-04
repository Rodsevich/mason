import 'package:mcp_dart/mcp_dart.dart';
import 'package:mcp_masonex/src/runner/masonex_runner.dart';
import 'package:mcp_masonex/src/schema/common.dart';

/// Registers `masonex_build` (in-file generation via build_runner).
void register(McpServer server, MasonexRunner runner) {
  server.registerTool(
    'masonex_build',
    description:
        'Run masonex build (delegates to `dart pub run build_runner '
        'build --delete-conflicting-outputs`) in the given workspace. '
        'This is what powers the `@GenerateBefore`, `@GenerateAfter` and '
        '`@GenerationMerge` annotations from masonex bricks.',
    inputSchema: JsonSchema.object(
      properties: <String, JsonSchema>{
        'workspace': workspaceSchema(),
        'timeoutSeconds': timeoutSchema(defaultSeconds: 600),
      },
      required: const <String>[],
    ),
    callback: (Map<String, dynamic> args, dynamic extra) async {
      final workspace = optionalString(args, 'workspace');
      final result = await runner.run(
        ['build'],
        workingDirectory: workspace,
        timeout: timeoutFromArgs(args),
      );
      return callToolResultFor(result);
    },
  );
}
