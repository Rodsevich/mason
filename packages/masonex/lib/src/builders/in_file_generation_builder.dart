import 'dart:async';
import 'dart:convert';
import 'package:build/build.dart';
import 'package:glob/glob.dart';

class InFileGenerationBuilder implements Builder {
  @override
  final buildExtensions = const {
    r'$lib$': ['inFileGenerations.json'],
  };

  @override
  Future<void> build(BuildStep buildStep) async {
    final inFileGenerations = <String, Map<String, String>>{};

    final assets = buildStep.findAssets(Glob('**/*.dart'));
    await for (final asset in assets) {
      final content = await buildStep.readAsString(asset);
      final lines = content.split('\n');

      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.contains('@GenerateBefore') ||
            line.contains('@GenerateAfter') ||
            line.contains('@GenerationMerge')) {
          final idMatch = RegExp(r"\((['\x22])(.+?)\1\)").firstMatch(line);
          if (idMatch != null) {
            final id = idMatch.group(2)!;
            final templateLine = line.substring(line.indexOf(':') + 1).trim();
            if (templateLine.isNotEmpty) {
              inFileGenerations[asset.path] ??= {};
              inFileGenerations[asset.path]![id] = templateLine;
            }
          }
        }
      }
    }

    if (inFileGenerations.isNotEmpty) {
      final outputAsset = buildStep.allowedOutputs.first;
      await buildStep.writeAsString(
        outputAsset,
        json.encode(inFileGenerations),
      );
    }
  }
}
