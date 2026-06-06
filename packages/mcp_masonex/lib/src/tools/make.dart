import 'dart:convert';
import 'dart:io';

import 'package:mcp_dart/mcp_dart.dart';
import 'package:mcp_masonex/src/runner/masonex_runner.dart';
import 'package:mcp_masonex/src/schema/common.dart';
import 'package:path/path.dart' as p;

/// Registers `masonex_make` and `masonex_new_brick`.
void register(McpServer server, MasonexRunner runner) {
  _registerMake(server, runner);
  _registerNew(server, runner);
}

void _registerMake(McpServer server, MasonexRunner runner) {
  server.registerTool(
    'masonex_make',
    description:
        'Generate code from a brick that is already registered in the '
        'workspace `masonex.yaml` (or globally). If the brick is not yet '
        'registered, call `masonex_add_brick` first. Pass `vars` as a '
        'JSON object whose keys match the variables declared in '
        '`brick.yaml` (call `masonex_describe_brick` first if unsure). '
        'Use `dryRunAi: true` to preview AI-pre-resolution without '
        'writing files. Use `onConflict: "skip"` for non-interactive '
        'runs.',
    inputSchema: JsonSchema.object(
      properties: <String, JsonSchema>{
        'brickName': JsonSchema.string(
          description: 'Name of the brick as registered in '
              '`masonex.yaml` (workspace or global). Required.',
        ),
        'workspace': workspaceSchema(),
        'outputDir': JsonSchema.string(
          description: 'Directory where the generated files should land. '
              'Defaults to the current workspace.',
        ),
        'vars': JsonSchema.object(
          description: 'Variables to pass to the brick, as a JSON object. '
              "Keys must match the brick's declared variables.",
          properties: <String, JsonSchema>{},
          required: const <String>[],
        ),
        'onConflict': JsonSchema.string(
          description: 'File-conflict resolution policy. Defaults to '
              '"skip" so the tool never blocks waiting for a prompt.',
          enumValues: const ['prompt', 'overwrite', 'append', 'skip'],
        ),
        'noHooks': JsonSchema.boolean(
          description: 'If true, skip `pre_gen` and `post_gen` hooks.',
        ),
        'quiet': JsonSchema.boolean(
          description: 'If true, run with reduced verbosity. '
              'Defaults to true.',
        ),
        'dryRunAi': JsonSchema.boolean(
          description: 'Preview AI pre-resolution without writing files.',
        ),
        'noAi': JsonSchema.boolean(
          description: 'Skip AI pre-resolution; `| ai` filters survive '
              'into the output verbatim.',
        ),
        'useMockAi': JsonSchema.boolean(
          description: 'Use the mock AI provider (reads '
              '`brick_test/ai_fixtures.yaml`).',
        ),
        'aiProvider': JsonSchema.string(
          description: 'Override the active AI provider id for this run.',
        ),
        'timeoutSeconds': timeoutSchema(defaultSeconds: 600),
      },
      required: const <String>['brickName'],
    ),
    callback: (Map<String, dynamic> args, dynamic extra) async {
      final String brickName;
      try {
        brickName = requireString(args, 'brickName');
      } on ToolArgumentException catch (e) {
        return validationError(e.message);
      }
      final workspace = optionalString(args, 'workspace');
      final outputDir = optionalString(args, 'outputDir');
      final onConflict = optionalString(args, 'onConflict') ?? 'skip';
      final noHooks = optionalBool(args, 'noHooks');
      final quiet = optionalBool(args, 'quiet', fallback: true);
      final dryRunAi = optionalBool(args, 'dryRunAi');
      final noAi = optionalBool(args, 'noAi');
      final useMockAi = optionalBool(args, 'useMockAi');
      final aiProvider = optionalString(args, 'aiProvider');
      final varsRaw = args['vars'];
      Map<String, dynamic>? vars;
      if (varsRaw is Map) {
        vars = <String, dynamic>{
          for (final entry in varsRaw.entries)
            entry.key.toString(): entry.value,
        };
      } else if (varsRaw != null) {
        return validationError('`vars` must be a JSON object.');
      }

      // Materialise vars to a temp config file (-c) so we never have to
      // shell-escape complex values and never trigger interactive prompts.
      File? configFile;
      if (vars != null && vars.isNotEmpty) {
        configFile = await File(
          p.join(
            Directory.systemTemp.path,
            'mcp_masonex_vars_'
                '${DateTime.now().microsecondsSinceEpoch}.json',
          ),
        ).create(recursive: true);
        await configFile.writeAsString(jsonEncode(vars));
      }

      final cmd = <String>[
        'make',
        brickName,
        if (configFile != null) ...['-c', configFile.path],
        if (outputDir != null) ...['-o', outputDir],
        '--on-conflict',
        onConflict,
        if (noHooks) '--no-hooks',
        if (quiet) '-q',
        if (dryRunAi) '--dry-run-ai',
        if (noAi) '--no-ai',
        if (useMockAi) '--use-mock-ai',
        if (aiProvider != null) ...['--ai-provider', aiProvider],
      ];
      try {
        final result = await runner.run(
          cmd,
          workingDirectory: workspace,
          timeout: timeoutFromArgs(args),
        );
        return callToolResultFor(result);
      } finally {
        if (configFile != null && configFile.existsSync()) {
          try {
            configFile.deleteSync();
          } on FileSystemException {
            // best-effort cleanup
          }
        }
      }
    },
  );
}

void _registerNew(McpServer server, MasonexRunner runner) {
  server.registerTool(
    'masonex_new_brick',
    description:
        'Scaffold a new brick template (`masonex new`). Creates '
        'brick.yaml, README, CHANGELOG, LICENSE and an example '
        '`__brick__/HELLO.md`. Optionally also generates `hooks/`.',
    inputSchema: JsonSchema.object(
      properties: <String, JsonSchema>{
        'name': JsonSchema.string(
          description: 'Name of the new brick (snake_case recommended).',
        ),
        'workspace': workspaceSchema(),
        'description': JsonSchema.string(
          description: 'Description for the new brick.',
        ),
        'outputDir': JsonSchema.string(
          description: 'Directory where to create the brick. Defaults to '
              'the workspace.',
        ),
        'hooks': JsonSchema.boolean(
          description: 'If true, generate the hooks scaffolding.',
        ),
      },
      required: const <String>['name'],
    ),
    callback: (Map<String, dynamic> args, dynamic extra) async {
      final String name;
      try {
        name = requireString(args, 'name');
      } on ToolArgumentException catch (e) {
        return validationError(e.message);
      }
      final workspace = optionalString(args, 'workspace');
      final description = optionalString(args, 'description');
      final outputDir = optionalString(args, 'outputDir');
      final withHooks = optionalBool(args, 'hooks');
      final cmd = <String>[
        'new',
        name,
        if (description != null) ...['-d', description],
        if (outputDir != null) ...['-o', outputDir],
        if (withHooks) '--hooks',
      ];
      final result = await runner.run(cmd, workingDirectory: workspace);
      return callToolResultFor(result);
    },
  );
}
