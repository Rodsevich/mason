import 'dart:async';

import 'package:build/build.dart';
import 'package:meta/meta.dart' show mustCallSuper;

/// "Multiple Input" Builder (a.k.a. Aggregator Builder) is a
/// common functionality implementation for aggregator builders
abstract class MIBuilder extends Builder {
  late BuildStep _buildStep;

  @override
  @mustCallSuper
  FutureOr<void> build(BuildStep buildStep) async {
    _buildStep = buildStep;
  }

  /// Get the package name in which the builder is executing
  String get packageName => _buildStep.inputId.package;

  /// Whether the `asset` can be read or not
  Future<bool> canRead(AssetId asset) => _buildStep.canRead(asset);

//  /// Tries to read the source of the given `asset` and returns it.
//  /// If the source can't be read, if the solicitant is an AuxiliarBuilder
//  /// rethrows the error, because the programmer should fix the issue.
//  /// But if it's not, it's surely because the builder depends on a not
//  /// analyzed source, so better returning an empty string and keep the
//  /// execution going without that as if the file didn't existed
  Future<String> getSource(AssetId asset) async {
    return await _buildStep.readAsString(asset);
  }
  //   String ret;
  //   try {
  //     throw "sorp";
  //     ret = await _buildStep.readAsString(asset);
  //   } catch (e) {
  //     if (this is AuxiliarAnalyzerBuilder) {
  //       rethrow;
  //     } else {
  //       ret = "";
  //     }
  //   }
  //   return ret;
  // }

  ///The way of getting Resource(s), through buildStep#fetchResource call
  Future<T> fetchResource<T>(Resource<T> res) => _buildStep.fetchResource(res);

  /// The BuildStep with which to build (it's not recommended to use)
  @Deprecated('Use _buildStep directly or relevant methods')
  BuildStep getBuildStep() => _buildStep;
}

/// Mixin with common functionality for analysis dependant MIBuilders
mixin AnalyzerMIBuilder on MIBuilder {
  /// Unifies analysis from several assets into a single one
  Map<String, Set<T>> unifyAnalysis<T>(
          Iterable<Map<String, dynamic>> analysisOfAssets) =>
      analysisOfAssets.expand((m) => m.entries).fold(
          <String, Set<T>>{},
          (result, entry) => result
            ..putIfAbsent(entry.key, () => <T>{})
                .addAll(entry.value is Iterable ? entry.value : [entry.value]));
}

/// A class made for handling the hidden _buildStep attribute of [MIBuilder]s
class MIBuilderBuildStepHandler {
  static void setBuildStep(MIBuilder instance, BuildStep step) {
    instance._buildStep = step;
  }

  static bool hasBuildStep(MIBuilder instance) => true;

  static BuildStep getBuildStep(MIBuilder instance) => instance._buildStep;
}
