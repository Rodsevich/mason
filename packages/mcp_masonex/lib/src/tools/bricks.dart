import 'dart:io';

import 'package:mcp_dart/mcp_dart.dart';
import 'package:mcp_masonex/src/runner/masonex_runner.dart';
import 'package:mcp_masonex/src/schema/common.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart' as yaml;

/// Registers brick-discovery and lifecycle tools (init/list/search/add/
/// remove/get/describe).
void register(McpServer server, MasonexRunner runner) {
  _registerInit(server, runner);
  _registerList(server, runner);
  _registerSearch(server, runner);
  _registerAdd(server, runner);
  _registerRemove(server, runner);
  _registerGet(server, runner);
  _registerDescribe(server);
}

void _registerInit(McpServer server, MasonexRunner runner) {
  server.registerTool(
    'masonex_init',
    description:
        'Initialize a new `masonex.yaml` in the given workspace. Use this '
        'when the workspace does not already have a `masonex.yaml`.',
    inputSchema: JsonSchema.object(
      properties: <String, JsonSchema>{
        'workspace': workspaceSchema(),
      },
      required: const <String>[],
    ),
    callback: (Map<String, dynamic> args, dynamic extra) async {
      final workspace = optionalString(args, 'workspace');
      final result = await runner.run(
        ['init'],
        workingDirectory: workspace,
      );
      return callToolResultFor(result);
    },
  );
}

void _registerList(McpServer server, MasonexRunner runner) {
  server.registerTool(
    'masonex_list_bricks',
    description:
        'List bricks installed in a masonex workspace. Set `global` to '
        'true to list bricks installed globally (`~/.masonex`). Returns '
        'name, version and source for each brick.',
    inputSchema: JsonSchema.object(
      properties: <String, JsonSchema>{
        'workspace': workspaceSchema(),
        'global': JsonSchema.boolean(
          description: 'If true, list globally installed bricks instead of '
              'the workspace ones.',
        ),
      },
      required: const <String>[],
    ),
    callback: (Map<String, dynamic> args, dynamic extra) async {
      final workspace = optionalString(args, 'workspace');
      final isGlobal = optionalBool(args, 'global');
      final cmd = <String>['list', if (isGlobal) '-g'];
      final result = await runner.run(cmd, workingDirectory: workspace);
      return callToolResultFor(result);
    },
  );
}

void _registerSearch(McpServer server, MasonexRunner runner) {
  server.registerTool(
    'masonex_search_bricks',
    description:
        'Search published bricks on https://brickhub.dev for a given '
        'query string. Network call.',
    inputSchema: JsonSchema.object(
      properties: <String, JsonSchema>{
        'query': JsonSchema.string(
          description: 'Free-form search query, e.g. "flutter widget", '
              '"cli", "package".',
        ),
        'timeoutSeconds': timeoutSchema(defaultSeconds: 60),
      },
      required: const <String>['query'],
    ),
    callback: (Map<String, dynamic> args, dynamic extra) async {
      final String query;
      try {
        query = requireString(args, 'query');
      } on ToolArgumentException catch (e) {
        return validationError(e.message);
      }
      final result = await runner.run(
        ['search', query],
        timeout: timeoutFromArgs(args),
      );
      return callToolResultFor(result);
    },
  );
}

void _registerAdd(McpServer server, MasonexRunner runner) {
  server.registerTool(
    'masonex_add_brick',
    description:
        'Add a brick to a workspace. Source is one of: `path` (local '
        'directory containing `brick.yaml`), `git` (remote repository), or '
        '`hosted` (BrickHub registry by version). Tool fails if no source '
        'is provided.',
    inputSchema: JsonSchema.object(
      properties: <String, JsonSchema>{
        'name': JsonSchema.string(
          description: 'Name of the brick to add (must match the name '
              'declared in the brick\'s `brick.yaml`).',
        ),
        'workspace': workspaceSchema(),
        'global': JsonSchema.boolean(
          description: 'If true, install globally (~/.masonex).',
        ),
        'path': JsonSchema.string(
          description: 'Local path to the brick. Mutually exclusive with '
              '`gitUrl` and `version`.',
        ),
        'gitUrl': JsonSchema.string(
          description: 'Git URL of the brick. Mutually exclusive with '
              '`path` and `version`.',
        ),
        'gitRef': JsonSchema.string(
          description: 'Git branch, tag or commit SHA. Only used with '
              '`gitUrl`.',
        ),
        'gitPath': JsonSchema.string(
          description: 'Subpath inside the git repository. Only used with '
              '`gitUrl`.',
        ),
        'version': JsonSchema.string(
          description: 'Version constraint (e.g. "0.1.0", "^1.0.0", "any") '
              'when installing from BrickHub. Mutually exclusive with '
              '`path` and `gitUrl`.',
        ),
        'timeoutSeconds': timeoutSchema(defaultSeconds: 180),
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
      final isGlobal = optionalBool(args, 'global');
      final path = optionalString(args, 'path');
      final gitUrl = optionalString(args, 'gitUrl');
      final gitRef = optionalString(args, 'gitRef');
      final gitPath = optionalString(args, 'gitPath');
      final version = optionalString(args, 'version');

      final sources = [path, gitUrl, version].where((s) => s != null).length;
      if (sources > 1) {
        return validationError(
          'Provide at most one of `path`, `gitUrl`, `version`.',
        );
      }

      final cmd = <String>[
        'add',
        if (isGlobal) '-g',
        name,
        if (path != null) ...['--path', path],
        if (gitUrl != null) ...['--git-url', gitUrl],
        if (gitRef != null) ...['--git-ref', gitRef],
        if (gitPath != null) ...['--git-path', gitPath],
        if (version != null && path == null && gitUrl == null) version,
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

void _registerRemove(McpServer server, MasonexRunner runner) {
  server.registerTool(
    'masonex_remove_brick',
    description:
        'Remove a brick from a workspace (or globally). Destructive: '
        'requires `confirm: true`. When `confirm` is false, the tool '
        'returns the command it would have run without executing it.',
    inputSchema: JsonSchema.object(
      properties: <String, JsonSchema>{
        'name': JsonSchema.string(
          description: 'Name of the brick to remove.',
        ),
        'workspace': workspaceSchema(),
        'global': JsonSchema.boolean(
          description: 'If true, remove the brick from the global '
              'installation rather than the workspace.',
        ),
        'confirm': JsonSchema.boolean(
          description: 'Must be true for the removal to actually happen. '
              'Defaults to false (dry-run).',
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
      final isGlobal = optionalBool(args, 'global');
      final confirm = optionalBool(args, 'confirm');
      final cmd = <String>['remove', if (isGlobal) '-g', name];
      if (!confirm) {
        return CallToolResult.fromContent(
          [
            TextContent(
              text: 'Dry-run: would execute `${[
                runner.executable,
                ...cmd,
              ].join(' ')}` in '
                  '${workspace ?? runner.defaultWorkingDirectory ?? '<cwd>'}. '
                  'Re-invoke with `confirm: true` to actually remove.',
            ),
          ],
          isError: false,
        );
      }
      final result = await runner.run(cmd, workingDirectory: workspace);
      return callToolResultFor(result);
    },
  );
}

void _registerGet(McpServer server, MasonexRunner runner) {
  server.registerTool(
    'masonex_get',
    description:
        'Resolve and install all bricks declared in `masonex.yaml`. '
        'Equivalent to `masonex get`.',
    inputSchema: JsonSchema.object(
      properties: <String, JsonSchema>{
        'workspace': workspaceSchema(),
        'timeoutSeconds': timeoutSchema(defaultSeconds: 300),
      },
      required: const <String>[],
    ),
    callback: (Map<String, dynamic> args, dynamic extra) async {
      final workspace = optionalString(args, 'workspace');
      final result = await runner.run(
        ['get'],
        workingDirectory: workspace,
        timeout: timeoutFromArgs(args),
      );
      return callToolResultFor(result);
    },
  );
}

void _registerDescribe(McpServer server) {
  server.registerTool(
    'masonex_describe_brick',
    description:
        'Read a brick\'s `brick.yaml` from disk and return its metadata: '
        'name, version, description, environment requirements, declared '
        'variables (with type, default, prompt, allowed values), and the '
        '`in_file_generations` map. Use this BEFORE `masonex_make` to know '
        'which variables to pass.',
    inputSchema: JsonSchema.object(
      properties: <String, JsonSchema>{
        'brickPath': JsonSchema.string(
          description: 'Absolute path to the brick directory '
              '(the directory that contains `brick.yaml`).',
        ),
      },
      required: const <String>['brickPath'],
    ),
    callback: (Map<String, dynamic> args, dynamic extra) async {
      final String brickPath;
      try {
        brickPath = requireString(args, 'brickPath');
      } on ToolArgumentException catch (e) {
        return validationError(e.message);
      }
      final brickYamlFile = File(p.join(brickPath, 'brick.yaml'));
      if (!brickYamlFile.existsSync()) {
        return validationError(
          'No brick.yaml found at ${brickYamlFile.path}.',
        );
      }
      final raw = brickYamlFile.readAsStringSync();
      final dynamic parsed = yaml.loadYaml(raw);
      if (parsed is! Map) {
        return validationError(
          'brick.yaml at ${brickYamlFile.path} is not a YAML map.',
        );
      }
      final structured = _summarise(parsed, brickPath);
      return CallToolResult.fromContent([
        TextContent(text: _renderSummary(structured)),
        TextContent(text: structured.toString()),
      ]);
    },
  );
}

Map<String, Object?> _summarise(Map<dynamic, dynamic> brick, String path) {
  final dynamic varsRaw = brick['vars'];
  final vars = <Map<String, Object?>>[];
  if (varsRaw is Map) {
    varsRaw.forEach((dynamic name, dynamic props) {
      final entry = <String, Object?>{'name': name};
      if (props is Map) {
        for (final key in const [
          'type',
          'description',
          'default',
          'defaults',
          'prompt',
          'values',
          'separator',
        ]) {
          if (props.containsKey(key)) {
            entry[key] = _convert(props[key]);
          }
        }
      }
      vars.add(entry);
    });
  }
  final dynamic env = brick['environment'];
  return <String, Object?>{
    'path': path,
    'name': brick['name'],
    'version': brick['version'],
    'description': brick['description'],
    'repository': brick['repository'],
    'publish_to': brick['publish_to'],
    'environment': env is Map ? _convertMap(env) : env,
    'vars': vars,
    'in_file_generations': brick['in_file_generations'] is Map
        ? _convertMap(brick['in_file_generations'] as Map)
        : null,
  };
}

dynamic _convert(dynamic value) {
  if (value is Map) return _convertMap(value);
  if (value is List) return value.map<dynamic>(_convert).toList();
  return value;
}

Map<String, Object?> _convertMap(Map<dynamic, dynamic> source) {
  return <String, Object?>{
    for (final entry in source.entries)
      entry.key.toString(): _convert(entry.value),
  };
}

String _renderSummary(Map<String, Object?> brick) {
  final buffer = StringBuffer()
    ..writeln('brick: ${brick['name']} v${brick['version']}')
    ..writeln('description: ${brick['description']}')
    ..writeln('path: ${brick['path']}');
  final vars = brick['vars'];
  if (vars is List && vars.isNotEmpty) {
    buffer.writeln('variables:');
    for (final v in vars) {
      if (v is! Map) continue;
      buffer.writeln(
        '  - ${v['name']} (${v['type'] ?? 'string'})'
        '${v['default'] != null ? ' default=${v['default']}' : ''}'
        '${v['values'] != null ? ' values=${v['values']}' : ''}',
      );
    }
  } else {
    buffer.writeln('variables: <none>');
  }
  return buffer.toString().trimRight();
}
