import 'dart:async';
import 'dart:convert';

import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:build_utils/build_utils.dart';

/// A more complex [BuilderMISO] (Aggregator builder) that is able to
/// use the resolver
abstract class BuilderAnalyzerMISO extends BuilderMISO
    with AnalyzerMIBuilder, AnalyzerAuxiliedClass {
  BuilderAnalyzerMISO(
      Iterable<String> inputsGlobPaths, String outputPath, bool formatDart)
      : super(inputsGlobPaths, outputPath, formatDart);

  AnalysisGatheringFunction get analysisGatheringFunction => analysisResultsFor;

  @override
  FutureOr<Map> analysisResultsFor(
      AssetId asset, LibraryElement library, Resolver resolver);

  @override
  FutureOr<String> buildOutput(Set<AssetId> inputs) async {
    var inputsWithAnalysis = <AssetId, Map<String, dynamic>>{};
    for (var input in inputs) {
      inputsWithAnalysis[input] = json.decode(await getSource(
              AssetId(input.package, input.path + auxiliarExtension)))
          as Map<String, dynamic>;
    }
    return await buildOutputWithAnalysis(inputsWithAnalysis);
  }

  @override
  String get auxiliarExtension => '.$runtimeType.auxiliarAnalyzerMISO.info';

  /// The function to implement for building the output file specified
  /// You can use the inputs provided for processing the output contents
  /// that will be saved in the provided `outputPath`
  FutureOr<String> buildOutputWithAnalysis(
      Map<AssetId, Map<String, dynamic>> inputsWithAnalysis);
}
