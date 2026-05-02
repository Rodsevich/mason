// ignore_for_file: public_member_api_docs, lines_longer_than_80_chars

import 'dart:io';

import 'package:masonex/src/ai/errors.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// How a provider expects to receive its prompt and system instructions.
enum PassMode { stdin, tmpfile, arg }

PassMode _parsePassMode(String? raw, {required String fieldName}) {
  switch (raw) {
    case 'stdin':
      return PassMode.stdin;
    case 'tmpfile':
      return PassMode.tmpfile;
    case 'arg':
      return PassMode.arg;
    default:
      throw AiException(
        'Invalid value for $fieldName: "$raw". '
        'Expected one of: stdin, tmpfile, arg.',
      );
  }
}

class ProviderConfig {
  ProviderConfig({
    required this.id,
    required this.cmd,
    required this.passPrompt,
    required this.timeout,
    this.passSystem,
    this.notes,
  });

  final String id;
  final List<String> cmd;
  final PassMode passPrompt;
  final List<String>? passSystem;
  final Duration timeout;
  final String? notes;

  Map<String, dynamic> toYamlMap() => {
        'cmd': cmd,
        'pass_prompt': _modeToYaml(passPrompt),
        if (passSystem != null) 'pass_system': passSystem,
        'timeout': '${timeout.inSeconds}s',
        if (notes != null) 'notes': notes,
      };

  static String _modeToYaml(PassMode m) => m.name;
}

class ProvidersYaml {
  ProvidersYaml({
    required this.defaultProvider,
    required this.providers,
  });

  String defaultProvider;
  final Map<String, ProviderConfig> providers;

  static String defaultPath() {
    final home = Platform.environment['HOME']
        ?? Platform.environment['USERPROFILE']
        ?? '.';
    return p.join(home, '.masonex', 'providers.yaml');
  }

  static Future<ProvidersYaml?> load([String? path]) async {
    final f = File(path ?? defaultPath());
    if (!f.existsSync()) return null;
    final raw = await f.readAsString();
    final doc = loadYaml(raw);
    if (doc is! YamlMap) {
      throw const AiException(
        'Invalid providers.yaml: top-level must be a map.',
      );
    }
    final defaultProvider = doc['default']?.toString();
    if (defaultProvider == null) {
      throw const AiException(
        'Invalid providers.yaml: missing required `default` key.',
      );
    }
    final providersNode = doc['providers'];
    if (providersNode is! YamlMap) {
      throw const AiException(
        'Invalid providers.yaml: missing or malformed `providers` map.',
      );
    }
    final parsed = <String, ProviderConfig>{};
    providersNode.forEach((key, value) {
      final id = key.toString();
      if (value is! YamlMap) {
        throw AiException(
          'Invalid providers.yaml: provider "$id" must be a map.',
        );
      }
      parsed[id] = _parseProvider(id, value);
    });
    if (!parsed.containsKey(defaultProvider)) {
      throw AiException(
        'Invalid providers.yaml: default "$defaultProvider" '
        'is not in providers list.',
      );
    }
    return ProvidersYaml(
      defaultProvider: defaultProvider,
      providers: parsed,
    );
  }

  Future<void> save([String? path]) async {
    final f = File(path ?? defaultPath());
    await f.parent.create(recursive: true);
    final buf = StringBuffer()
      ..writeln('default: $defaultProvider')
      ..writeln('providers:');
    providers.forEach((id, cfg) {
      buf
        ..writeln('  $id:')
        ..writeln('    cmd: ${_quoteList(cfg.cmd)}')
        ..writeln('    pass_prompt: ${cfg.passPrompt.name}');
      if (cfg.passSystem != null) {
        buf.writeln('    pass_system: ${_quoteList(cfg.passSystem!)}');
      } else {
        buf.writeln('    pass_system: null');
      }
      buf.writeln('    timeout: ${cfg.timeout.inSeconds}s');
      if (cfg.notes != null) {
        buf.writeln('    notes: ${_quoteScalar(cfg.notes!)}');
      }
    });
    await f.writeAsString(buf.toString());
  }

  static String _quoteList(List<String> items) =>
      '[${items.map(_quoteScalar).join(', ')}]';

  static String _quoteScalar(String s) {
    if (s.contains(RegExp(r'[:#\[\]\{\}\?\*\&\!\|\>\<\"\,\%\@\`]'))
        || s.startsWith('-')
        || s.contains('\n')) {
      final escaped = s.replaceAll('\\', r'\\').replaceAll('"', r'\"');
      return '"$escaped"';
    }
    return s;
  }

  static ProviderConfig _parseProvider(String id, YamlMap node) {
    final cmdNode = node['cmd'];
    if (cmdNode is! YamlList || cmdNode.isEmpty) {
      throw AiException(
        'Invalid providers.yaml: provider "$id" needs a non-empty `cmd` list.',
      );
    }
    final cmd = cmdNode.map((e) => e.toString()).toList();
    final passPrompt = _parsePassMode(
      node['pass_prompt']?.toString(),
      fieldName: '$id.pass_prompt',
    );
    final passSysNode = node['pass_system'];
    final passSystem = passSysNode == null
        ? null
        : passSysNode is YamlList
            ? passSysNode.map((e) => e.toString()).toList()
            : null;
    final timeout = _parseDuration(
      node['timeout']?.toString() ?? '60s',
      providerId: id,
    );
    return ProviderConfig(
      id: id,
      cmd: cmd,
      passPrompt: passPrompt,
      passSystem: passSystem,
      timeout: timeout,
      notes: node['notes']?.toString(),
    );
  }

  static Duration _parseDuration(String raw, {required String providerId}) {
    final m = RegExp(r'^(\d+)\s*([smh])$').firstMatch(raw);
    if (m == null) {
      throw AiException(
        'Invalid timeout for provider "$providerId": "$raw". '
        'Expected `<n>s`, `<n>m` or `<n>h`.',
      );
    }
    final n = int.parse(m.group(1)!);
    final unit = m.group(2)!;
    switch (unit) {
      case 's':
        return Duration(seconds: n);
      case 'm':
        return Duration(minutes: n);
      case 'h':
        return Duration(hours: n);
      default:
        return Duration(seconds: n);
    }
  }
}
