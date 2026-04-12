import 'dart:convert';
import 'dart:io';
import 'package:masonex/masonex.dart';
import 'package:path/path.dart' as p;

Future<void> main() async {
  final masonexPath = Directory.current.path;
  final repoRoot = p.dirname(p.dirname(masonexPath));
  final bricksPath = p.join(repoRoot, 'bricks');

  final bundles = {
    'greeting': p.join(bricksPath, 'greeting'),
    'hooks': p.join(bricksPath, 'hooks'),
    'photos': p.join(bricksPath, 'photos'),
    'relative_imports': p.join(masonexPath, 'test', 'fixtures', 'relative_imports'),
  };

  for (final entry in bundles.entries) {
    final name = entry.key;
    final path = entry.value;
    print('Bundling $name from $path...');

    final bundle = await createBundle(Directory(path));
    // Use json encode/decode to get a deep Map<String, dynamic>
    final bundleJson = json.decode(json.encode(bundle.toJson())) as Map<String, dynamic>;
    final bundleName = '${name}_bundle';
    final outputFiles = [
      File(p.join(masonexPath, 'test', 'bundles', '$bundleName.dart')),
      File(p.join(masonexPath, 'test', 'cli', 'bundles', '$bundleName.dart')),
    ];

    final variableName = name == 'relative_imports' 
        ? 'relativeImportsBundle' 
        : name == 'greeting' 
            ? 'greetingBundle'
            : name == 'hooks'
                ? 'hooksBundle'
                : name == 'photos'
                    ? 'photosBundle'
                    : '${name}Bundle';

    // Inject absolute path overrides into pubspec if it has hooks
    if (bundleJson['hooks'] != null && (bundleJson['hooks'] as List).isNotEmpty) {
      final hooks = (bundleJson['hooks'] as List);
      final pubspecIndex = hooks.indexWhere((h) => (h as Map)['path'] == 'pubspec.yaml');
      if (pubspecIndex != -1) {
        final mustachexPath = p.join(repoRoot, 'packages', 'mustachex');
        final masonLoggerPath = p.join(repoRoot, 'packages', 'mason_logger');
        final currentMasonexPath = p.join(repoRoot, 'packages', 'masonex');
        
        final pubspecContent = '''
name: ${name}_hooks
environment:
  sdk: ">=3.0.0 <4.0.0"
dependencies:
  masonex: any
dependency_overrides:
  masonex:
    path: $currentMasonexPath
  mustachex:
    path: $mustachexPath
  mason_logger:
    path: $masonLoggerPath
''';
        (hooks[pubspecIndex] as Map)['data'] = base64.encode(utf8.encode(pubspecContent));
      }

      // Also ensure hook code imports masonex, not mason
      for (final hookObj in hooks) {
        final hook = hookObj as Map;
        final hookPath = hook['path'] as String;
        if (hookPath.endsWith('.dart')) {
          var hookCode = utf8.decode(base64.decode(hook['data'] as String));
          hookCode = hookCode.replaceAll("import 'package:mason/mason.dart';", "import 'package:masonex/masonex.dart';");
          hookCode = hookCode.replaceAll("import 'package:mason/src/generator.dart';", "import 'package:masonex/masonex.dart';");
          hook['data'] = base64.encode(utf8.encode(hookCode));
        }
      }
    }

    final content = '''
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, implicit_dynamic_list_literal, implicit_dynamic_map_literal, inference_failure_on_collection_literal

import 'package:masonex/masonex.dart';

final $variableName = MasonexBundle.fromJson(<String, dynamic>${_formatJson(bundleJson)});
''';

    for (final outputFile in outputFiles) {
      if (outputFile.parent.existsSync()) {
        await outputFile.writeAsString(content);
        print('Generated ${outputFile.path}');
      }
    }
  }
}

String _formatJson(Map<String, dynamic> jsonMap) {
  const encoder = JsonEncoder.withIndent('  ');
  return encoder.convert(jsonMap);
}
