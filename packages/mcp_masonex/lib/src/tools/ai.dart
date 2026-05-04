import 'package:mcp_dart/mcp_dart.dart';
import 'package:mcp_masonex/src/runner/masonex_runner.dart';
import 'package:mcp_masonex/src/schema/common.dart';

/// Registers AI-related tools (audit-ai, validate, ai-budget, ai-context-preview,
/// ai-trace, ai-cache, provider).
void register(McpServer server, MasonexRunner runner) {
  _registerAuditAi(server, runner);
  _registerValidate(server, runner);
  _registerAiBudget(server, runner);
  _registerAiContextPreview(server, runner);
  _registerAiTrace(server, runner);
  _registerAiCache(server, runner);
  _registerProviderShow(server, runner);
  _registerProviderTest(server, runner);
}

void _registerAuditAi(McpServer server, MasonexRunner runner) {
  server.registerTool(
    'masonex_audit_ai',
    description:
        'List every `| ai` tag found inside a brick along with its '
        'pre-rendered prompt and parameters. Does not contact any '
        'provider. Useful for reviewing what a brick will ask the AI to '
        'produce.',
    inputSchema: JsonSchema.object(
      properties: <String, JsonSchema>{
        'brick': JsonSchema.string(
          description: 'Path to the brick directory (must contain '
              '`__brick__/`). Defaults to the workspace.',
        ),
        'workspace': workspaceSchema(),
      },
      required: const <String>[],
    ),
    callback: (Map<String, dynamic> args, dynamic extra) async {
      final brick = optionalString(args, 'brick');
      final workspace = optionalString(args, 'workspace');
      final cmd = <String>['audit-ai', if (brick != null) ...['-b', brick]];
      final result = await runner.run(cmd, workingDirectory: workspace);
      return callToolResultFor(result);
    },
  );
}

void _registerValidate(McpServer server, MasonexRunner runner) {
  server.registerTool(
    'masonex_validate',
    description:
        'Statically validate AI pipeline syntax inside a brick (offline). '
        'Reports parse errors and AI filters used in filenames (which are '
        'forbidden).',
    inputSchema: JsonSchema.object(
      properties: <String, JsonSchema>{
        'brick': JsonSchema.string(
          description: 'Path to the brick directory. Defaults to the '
              'workspace.',
        ),
        'workspace': workspaceSchema(),
      },
      required: const <String>[],
    ),
    callback: (Map<String, dynamic> args, dynamic extra) async {
      final brick = optionalString(args, 'brick');
      final workspace = optionalString(args, 'workspace');
      final cmd = <String>['validate', if (brick != null) ...['-b', brick]];
      final result = await runner.run(cmd, workingDirectory: workspace);
      return callToolResultFor(result);
    },
  );
}

void _registerAiBudget(McpServer server, MasonexRunner runner) {
  server.registerTool(
    'masonex_ai_budget',
    description:
        'Estimate input tokens for each `| ai` tag in a brick. '
        'Heuristic (chars/4). Use `budget` to flag tags above a '
        'per-tag token threshold.',
    inputSchema: JsonSchema.object(
      properties: <String, JsonSchema>{
        'brick': JsonSchema.string(
          description: 'Path to the brick directory.',
        ),
        'workspace': workspaceSchema(),
        'budget': JsonSchema.integer(
          description: 'Per-tag token budget. Tags above this are flagged. '
              'Defaults to 8000.',
          minimum: 1,
        ),
      },
      required: const <String>[],
    ),
    callback: (Map<String, dynamic> args, dynamic extra) async {
      final brick = optionalString(args, 'brick');
      final workspace = optionalString(args, 'workspace');
      final budgetRaw = args['budget'];
      String? budgetStr;
      if (budgetRaw is num) budgetStr = budgetRaw.toInt().toString();
      if (budgetRaw is String) budgetStr = budgetRaw;
      final cmd = <String>[
        'ai-budget',
        if (brick != null) ...['-b', brick],
        if (budgetStr != null) ...['--budget', budgetStr],
      ];
      final result = await runner.run(cmd, workingDirectory: workspace);
      return callToolResultFor(result);
    },
  );
}

void _registerAiContextPreview(McpServer server, MasonexRunner runner) {
  server.registerTool(
    'masonex_ai_context_preview',
    description:
        'Print the XML envelope that would be sent to the AI for each '
        '`| ai` tag in a brick. Does NOT contact any provider. Useful '
        'when an agent wants to inspect the exact context the model '
        'will see.',
    inputSchema: JsonSchema.object(
      properties: <String, JsonSchema>{
        'brick': JsonSchema.string(
          description: 'Path to the brick directory.',
        ),
        'workspace': workspaceSchema(),
        'tag': JsonSchema.string(
          description: 'Optional tag id substring filter (e.g. '
              '"task.dart#L4"). Default: print all tags.',
        ),
      },
      required: const <String>[],
    ),
    callback: (Map<String, dynamic> args, dynamic extra) async {
      final brick = optionalString(args, 'brick');
      final workspace = optionalString(args, 'workspace');
      final tag = optionalString(args, 'tag');
      final cmd = <String>[
        'ai-context-preview',
        if (brick != null) ...['-b', brick],
        if (tag != null) ...['--tag', tag],
      ];
      final result = await runner.run(cmd, workingDirectory: workspace);
      return callToolResultFor(result);
    },
  );
}

void _registerAiTrace(McpServer server, MasonexRunner runner) {
  server.registerTool(
    'masonex_ai_trace',
    description:
        'Inspect recent AI invocation entries from '
        '`.masonex/cache/ai/trace.jsonl`. Use `last` to limit and `tag` '
        'to filter by tag id substring.',
    inputSchema: JsonSchema.object(
      properties: <String, JsonSchema>{
        'workspace': workspaceSchema(),
        'last': JsonSchema.integer(
          description: 'Show only the last N entries.',
          minimum: 1,
        ),
        'tag': JsonSchema.string(
          description: 'Filter by tag id substring.',
        ),
      },
      required: const <String>[],
    ),
    callback: (Map<String, dynamic> args, dynamic extra) async {
      final workspace = optionalString(args, 'workspace');
      final lastRaw = args['last'];
      String? lastStr;
      if (lastRaw is num) lastStr = lastRaw.toInt().toString();
      if (lastRaw is String) lastStr = lastRaw;
      final tag = optionalString(args, 'tag');
      final cmd = <String>[
        'ai-trace',
        if (lastStr != null) ...['-n', lastStr],
        if (tag != null) ...['--tag', tag],
      ];
      final result = await runner.run(cmd, workingDirectory: workspace);
      return callToolResultFor(result);
    },
  );
}

void _registerAiCache(McpServer server, MasonexRunner runner) {
  server.registerTool(
    'masonex_ai_cache',
    description:
        'Inspect or clear the AI output cache at '
        '`.masonex/cache/ai/`. `action: "stats"` is read-only; '
        '`action: "clear"` deletes the cache and requires '
        '`confirm: true`.',
    inputSchema: JsonSchema.object(
      properties: <String, JsonSchema>{
        'workspace': workspaceSchema(),
        'action': JsonSchema.string(
          description: 'Either "stats" (default) or "clear".',
          enumValues: const ['stats', 'clear'],
        ),
        'confirm': JsonSchema.boolean(
          description: 'Required to actually clear the cache.',
        ),
      },
      required: const <String>[],
    ),
    callback: (Map<String, dynamic> args, dynamic extra) async {
      final action = optionalString(args, 'action') ?? 'stats';
      final workspace = optionalString(args, 'workspace');
      if (action == 'clear' && !optionalBool(args, 'confirm')) {
        return validationError(
          'Clearing the AI cache requires `confirm: true`.',
        );
      }
      final result = await runner.run(
        ['ai-cache', action],
        workingDirectory: workspace,
      );
      return callToolResultFor(result);
    },
  );
}

void _registerProviderShow(McpServer server, MasonexRunner runner) {
  server.registerTool(
    'masonex_provider_show',
    description:
        'Print the current AI provider configuration loaded from '
        '`~/.masonex/providers.yaml` (no secrets). Useful before running '
        'AI-enabled `make` to confirm which provider will be used.',
    inputSchema: emptyObjectSchema(),
    callback: (Map<String, dynamic> args, dynamic extra) async {
      final result = await runner.run(['provider', 'show']);
      return callToolResultFor(result);
    },
  );
}

void _registerProviderTest(McpServer server, MasonexRunner runner) {
  server.registerTool(
    'masonex_provider_test',
    description:
        'Send a trivial prompt to the configured default AI provider and '
        'return the reply. Network call, may consume tokens.',
    inputSchema: JsonSchema.object(
      properties: <String, JsonSchema>{
        'timeoutSeconds': timeoutSchema(defaultSeconds: 120),
      },
      required: const <String>[],
    ),
    callback: (Map<String, dynamic> args, dynamic extra) async {
      final result = await runner.run(
        ['provider', 'test'],
        timeout: timeoutFromArgs(args),
      );
      return callToolResultFor(result);
    },
  );
}
