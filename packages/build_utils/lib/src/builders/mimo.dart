import 'dart:async';

import 'package:build/build.dart';
import 'package:glob/glob.dart';
import 'package:dart_style/dart_style.dart';

import '../common.dart';

/// A `Multiple Input, Multiple Output` [Builder] that produces an
/// output file in the path taken from the key in
/// the `generations` constructor parameter by traversing
/// over all the inputs provided (taken as [Glob] patterns format)
/// in its respective value
abstract class BuilderMIMO extends MIBuilder {
  final Map<String, Set<Glob>> generations;
  final bool formatDart;

  BuilderMIMO(Map<String, Set<String>> generations, this.formatDart)
      : generations = generations
            .map((k, v) => MapEntry(k, v.map((v) => Glob(v)).toSet()));

  @override
  FutureOr<void> build(BuildStep buildStep) async {
    await super.build(buildStep);
    await Future.forEach(generations.entries, (e) async {
      String outputPath = e.key;
      Set<Glob> inputPaths = e.value;
      await _buildForOutput(buildStep, outputPath, inputPaths);
    });
  }

  Future<void> _buildForOutput(
      BuildStep buildStep, String outputPath, Set<Glob> inputGlobs) async {
    log.fine('Gathering inputs for building $outputPath in this '
        '[$runtimeType] MIMO Builder');
    var inputs = <AssetId>{};
    for (var glob in inputGlobs) {
      log.finer("Gathering inputs for glob '$glob'...");
      var inputAssets = buildStep.findAssets(glob);
      await for (AssetId asset in inputAssets) {
        log.finest("Found input '$asset' derivated from glob '$glob'"
            ' for this [$runtimeType] MIMO Builder');
        inputs.add(asset);
      }
    }
    if (inputs.isEmpty) {
      log.warning("No inputs found derived from the '${inputGlobs.join(', ')}' "
          "input globs for producing '$outputPath'");
    }
    log.fine("Building output '$outputPath'...");
    // Map<AssetId, String> computedInputs =
    //     Map.fromIterable(inputs, key: (i) => i, value: (_) => "");
    // for (var entry in computedInputs.entries) {
    //   computedInputs[entry.key] = await buildStep.readAsString(entry.key);
    // }
    var output = await buildOutputFor(outputPath, inputs);
    if (output.isEmpty) {
      throw StateError('buildOutput must always return a String');
    }
    var destination = AssetId(buildStep.inputId.package, outputPath);
    if (outputPath.endsWith('.dart') && formatDart) {
      log.finer('Formatting output');
      var fmt = DartFormatter();
      output = fmt.format(output);
    }
    log.fine("Saving output in '$outputPath'");
    await buildStep.writeAsString(destination, output);
    log.finest('$runtimeType build ended.');
  }

  /// The function to implement for building the output files specified (in the `outputPath` parameter)
  /// You can use the inputs provided for processing the output contents
  /// that will be saved in the given `outputPath`
  FutureOr<String> buildOutputFor(String outputPath, Set<AssetId> inputs);

  @override
  Map<String, List<String>> get buildExtensions => {
        r'lib/$lib$': generations.keys.toList(),
      };
}
