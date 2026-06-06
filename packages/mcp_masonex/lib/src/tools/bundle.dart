import 'package:mcp_dart/mcp_dart.dart';
import 'package:mcp_masonex/src/runner/masonex_runner.dart';
import 'package:mcp_masonex/src/schema/common.dart';

/// Registers `masonex_bundle`, `masonex_unbundle` and `masonex_publish`.
void register(McpServer server, MasonexRunner runner) {
  _registerBundle(server, runner);
  _registerUnbundle(server, runner);
  _registerPublish(server, runner);
}

void _registerBundle(McpServer server, MasonexRunner runner) {
  server.registerTool(
    'masonex_bundle',
    description:
        'Generate a bundle from a brick. `source` selects how the brick '
        'is located: "path" (local), "git" (remote), "hosted" (BrickHub).',
    inputSchema: JsonSchema.object(
      properties: <String, JsonSchema>{
        'sourceArg': JsonSchema.string(
          description: 'Positional source argument: a directory path, a '
              'git URL, or a hosted brick name (depends on `source`).',
        ),
        'source': JsonSchema.string(
          description: 'How to interpret `sourceArg`.',
          enumValues: const ['path', 'git', 'hosted'],
        ),
        'workspace': workspaceSchema(),
        'outputDir': JsonSchema.string(
          description: 'Where to drop the bundle file. Defaults to ".".',
        ),
        'type': JsonSchema.string(
          description: 'Bundle format.',
          enumValues: const ['universal', 'dart'],
        ),
        'gitRef': JsonSchema.string(
          description: 'Git ref (branch/tag/commit). Only valid when '
              'source is "git".',
        ),
        'gitPath': JsonSchema.string(
          description: 'Subpath inside the git repo. Only valid when '
              'source is "git".',
        ),
        'timeoutSeconds': timeoutSchema(defaultSeconds: 300),
      },
      required: const <String>['sourceArg'],
    ),
    callback: (Map<String, dynamic> args, dynamic extra) async {
      final String sourceArg;
      try {
        sourceArg = requireString(args, 'sourceArg');
      } on ToolArgumentException catch (e) {
        return validationError(e.message);
      }
      final source = optionalString(args, 'source') ?? 'path';
      final workspace = optionalString(args, 'workspace');
      final outputDir = optionalString(args, 'outputDir');
      final type = optionalString(args, 'type');
      final gitRef = optionalString(args, 'gitRef');
      final gitPath = optionalString(args, 'gitPath');
      final cmd = <String>[
        'bundle',
        '--source',
        source,
        if (outputDir != null) ...['-o', outputDir],
        if (type != null) ...['-t', type],
        if (gitRef != null) ...['--git-ref', gitRef],
        if (gitPath != null) ...['--git-path', gitPath],
        sourceArg,
      ];
      final result = await runner.run(
        cmd,
        workingDirectory: workspace,
        timeout: timeoutFromArgs(args),
      );
      return callToolResultFor(result);
    },
  );
}

void _registerUnbundle(McpServer server, MasonexRunner runner) {
  server.registerTool(
    'masonex_unbundle',
    description:
        'Expand a bundle file back into a brick directory. Destructive '
        'over the target dir: requires `confirm: true`.',
    inputSchema: JsonSchema.object(
      properties: <String, JsonSchema>{
        'bundlePath': JsonSchema.string(
          description: 'Absolute path to the bundle file (.bundle or '
              '*_bundle.dart).',
        ),
        'workspace': workspaceSchema(),
        'outputDir': JsonSchema.string(
          description: 'Directory where the brick should be expanded. '
              'Defaults to ".".',
        ),
        'type': JsonSchema.string(
          description: 'Bundle format.',
          enumValues: const ['universal', 'dart'],
        ),
        'confirm': JsonSchema.boolean(
          description: 'Must be true to actually run unbundle. Default '
              'false (dry-run).',
        ),
      },
      required: const <String>['bundlePath'],
    ),
    callback: (Map<String, dynamic> args, dynamic extra) async {
      final String bundlePath;
      try {
        bundlePath = requireString(args, 'bundlePath');
      } on ToolArgumentException catch (e) {
        return validationError(e.message);
      }
      final workspace = optionalString(args, 'workspace');
      final outputDir = optionalString(args, 'outputDir');
      final type = optionalString(args, 'type');
      final confirm = optionalBool(args, 'confirm');
      final cmd = <String>[
        'unbundle',
        if (outputDir != null) ...['-o', outputDir],
        if (type != null) ...['-t', type],
        bundlePath,
      ];
      if (!confirm) {
        return CallToolResult(
          content: [
            TextContent(
              text: 'Dry-run: would execute `${[
                runner.executable,
                ...cmd,
              ].join(' ')}`. Re-invoke with `confirm: true` to expand.',
            ),
          ],
        );
      }
      final result = await runner.run(cmd, workingDirectory: workspace);
      return callToolResultFor(result);
    },
  );
}

void _registerPublish(McpServer server, MasonexRunner runner) {
  server.registerTool(
    'masonex_publish',
    description:
        'Publish a brick to https://brickhub.dev. PUBLISHING IS '
        'PERMANENT — bricks cannot be unpublished. Defaults to '
        '`dryRun: true`. To actually publish, set `dryRun: false` AND '
        '`confirm: true`. Requires the user to be logged in (use '
        '`masonex_login` separately).',
    inputSchema: JsonSchema.object(
      properties: <String, JsonSchema>{
        'directory': JsonSchema.string(
          description: 'Path to the brick directory containing '
              '`brick.yaml`. Defaults to ".".',
        ),
        'workspace': workspaceSchema(),
        'dryRun': JsonSchema.boolean(
          description: 'Validate but do not publish. Default: true.',
        ),
        'confirm': JsonSchema.boolean(
          description: 'Must be true (in combination with `dryRun: false`) '
              'to actually publish.',
        ),
        'timeoutSeconds': timeoutSchema(defaultSeconds: 300),
      },
      required: const <String>[],
    ),
    callback: (Map<String, dynamic> args, dynamic extra) async {
      final directory = optionalString(args, 'directory') ?? '.';
      final workspace = optionalString(args, 'workspace');
      final dryRun = optionalBool(args, 'dryRun', fallback: true);
      final confirm = optionalBool(args, 'confirm');

      if (!dryRun && !confirm) {
        return validationError(
          'Refusing to publish without `confirm: true`. Set '
          '`dryRun: false` AND `confirm: true` to proceed; remember '
          'publishing is irreversible.',
        );
      }

      final cmd = <String>[
        'publish',
        '-C',
        directory,
        if (dryRun) '--dry-run' else '--force',
      ];
      final result = await runner.run(
        cmd,
        workingDirectory: workspace,
        timeout: timeoutFromArgs(args),
      );
      return callToolResultFor(
        result,
        note: dryRun
            ? 'publish dry-run: nothing was uploaded.'
            : 'publish: bundle uploaded (if exit code is 0).',
      );
    },
  );
}
