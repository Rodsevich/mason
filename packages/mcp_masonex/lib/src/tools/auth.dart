import 'package:mcp_dart/mcp_dart.dart';
import 'package:mcp_masonex/src/runner/masonex_runner.dart';
import 'package:mcp_masonex/src/schema/common.dart';

/// Registers brickhub.dev auth tools (logout). `login` is intentionally
/// NOT exposed: it requires interactive prompts for credentials, which is
/// hostile to autonomous agents and risks credentials leaking through
/// MCP. Users should run `masonex login` manually in their shell.
void register(McpServer server, MasonexRunner runner) {
  server.registerTool(
    'masonex_logout',
    description:
        'Log out of brickhub.dev. Requires `confirm: true` because it '
        'invalidates the local credentials.',
    inputSchema: JsonSchema.object(
      properties: <String, JsonSchema>{
        'confirm': JsonSchema.boolean(
          description: 'Must be true to actually log out.',
        ),
      },
      required: const <String>[],
    ),
    callback: (Map<String, dynamic> args, dynamic extra) async {
      final confirm = optionalBool(args, 'confirm');
      if (!confirm) {
        return validationError(
          'Logout requires `confirm: true`. Aborting.',
        );
      }
      final result = await runner.run(['logout']);
      return callToolResultFor(result);
    },
  );
}
