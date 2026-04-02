import 'dart:async';
import 'dart:convert';

import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:build_utils/src/builders/mimo.dart';
import 'package:glob/glob.dart';

import '../common.dart';
import 'analyzer_auxiliar.dart';

/// A more complex [BuilderMIMO] (Aggregator builder) that is able to
/// use the resolver
//TODO: analizar cómo hacer que salga de una misma clase el analisis y el build a traves de
//un singleton (con factory) q devuelva la misma instancia, es muy probable q asi se pueda
//evitar el tener que escribir el .info con el json, pasandose las variables directamente
abstract class BuilderAnalyzerMIMO extends BuilderMIMO
    with AnalyzerMIBuilder, AnalyzerAuxiliedClass {
  BuilderAnalyzerMIMO.forAuxiliarConstructor() : super({}, false);

  BuilderAnalyzerMIMO(Map<String, Set<String>> generations, bool formatDart)
      : super(generations, formatDart);

  AnalysisGatheringFunction get analysisGatheringFunction => analysisResultsFor;

  @override
  FutureOr<Map> analysisResultsFor(
      AssetId asset, LibraryElement library, Resolver resolver);

  @override
  FutureOr<String> buildOutputFor(
      String outputPath, Set<AssetId> inputs) async {
    var inputsWithAnalysis = <AssetId, Map<String, dynamic>>{};
    for (var input in inputs) {
      String source;
      var asset = AssetId(input.package, input.path + auxiliarExtension);
      try {
        source = await getSource(asset);
        inputsWithAnalysis[input] = json.decode(source) as Map<String, dynamic>;
      } catch (e) {
        log.warning(
            'Skipping analysis of $asset ($e).\nYou can omit this warning by '
            "managing the inputs of this '$runtimeType' builder in build.yaml");
        continue;
      }
    }
    return await buildOutputWithAnalysisFor(outputPath, inputsWithAnalysis);
  }

  /// The function to implement for building the output file specified
  /// You can use the inputs provided for processing the output contents
  /// that will be saved in the provided `outputPath`
  FutureOr<String> buildOutputWithAnalysisFor(
      String outputPath, Map<AssetId, Map<String, dynamic>> inputsWithAnalysis);

  @override
  Map<String, List<String>> get buildExtensions => {
        r'lib/$lib$': generations.keys.toList(),
      };

  @override
  String get auxiliarExtension => '.$runtimeType.auxiliarAnalyzerMIMO.info';

  @override
  Set<Glob> get inputGlobs =>
      generations.values.fold(<Glob>{}, (s1, s2) => s1..addAll(s2));
}
