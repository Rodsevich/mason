import 'dart:async';

import 'package:build/build.dart';
import 'package:glob/glob.dart';
import 'package:path/path.dart' as path;
import 'package:dart_style/dart_style.dart';

import '../common.dart';

/// A `Multiple Input, Single Output` [Builder] that traverses
/// over all the inputs provided (in [Glob] patterns format) in
/// the `inputsGlobPaths` variable and produces a single output
/// file in `outputPath` path
abstract class BuilderMISO extends MIBuilder {
  late Set<Glob> inputGlobs;
  final String outputPath;
  final bool formatDart;

  BuilderMISO(
      Iterable<String> inputsGlobPaths, this.outputPath, this.formatDart) {
    inputGlobs = inputsGlobPaths.map((s) => Glob(s)).toSet();
  }

  String get outputFileName => path.basename(outputPath);

  @override
  FutureOr<void> build(BuildStep buildStep) async {
    await super.build(buildStep);
    log.fine('Gathering inputs for building this '
        '[$runtimeType] MISO Builder');
    var inputs = <AssetId>{};
    for (var glob in inputGlobs) {
      log.finer("Gathering inputs for glob '$glob'...");
      var inputAssets = buildStep.findAssets(glob);
      await for (AssetId asset in inputAssets) {
        log.finest("Found input '$asset' derivated from glob '$glob'"
            ' for this [$runtimeType] MISO Builder');
        inputs.add(asset);
      }
    }
    log.fine("Building output '$outputPath'...");
    // Map<AssetId, String> computedInputs =
    //     Map.fromIterable(inputs, key: (i) => i, value: (_) => "");
    // for (var entry in computedInputs.entries) {
    //   computedInputs[entry.key] = await buildStep.readAsString(entry.key);
    // }
    var output = await buildOutput(inputs);
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

  /// The function to implement for building the output file specified
  /// You can use the inputs provided for processing the output contents
  /// that will be saved in the provided `outputPath`
  FutureOr<String> buildOutput(Set<AssetId> inputs);

  @override
  Map<String, List<String>> get buildExtensions => {
        r'lib/$lib$': [outputPath],
      };
}
