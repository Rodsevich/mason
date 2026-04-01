import 'dart:async';
import 'dart:convert';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:build_utils/build_utils.dart';
import 'package:glob/glob.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/analysis/utilities.dart';

/// A function to implement for providing the analysis data
typedef AnalysisGatheringFunction = FutureOr<Map> Function(
    AssetId asset, LibraryElement inputLibrary, Resolver resolver);

/// A function to implement for providing the analysis data when the file can't be resolved
/// as a workaround to a know bug (unknowed cause yet, though)
typedef WorkaroundGatheringFunction = FutureOr<Map> Function(
    UnresolvableFileException exception);

/// An interface to implement for having analysis in the class specified
mixin AnalyzerAuxiliedClass implements MIBuilder {
  /// A function to implement for providing the analysis data when the file
  /// can't be resolved as a workaround to a know bug (the cause is unknown yet, though)
  WorkaroundGatheringFunction onUnresolvableFileException =
      (_) => {"unimplemented": true};

  /// Function delegated for being implemented to the builder. Here should
  /// be provided the logic for obtaining the analysis needed for generation
  /// in next building steps
  FutureOr<Map> analysisResultsFor(
      AssetId asset, LibraryElement library, Resolver resolver);

  /// The extension with which will be created the .info files with the
  /// encoded analysis results generated from `analysisResultsFor`
  String get auxiliarExtension;

  /// The globs with which will be obtained the multiple inputs for building
  Set<Glob> get inputGlobs;
}

late Zone currentZone;

///A builder that should execute for performing analysis and persisting
///its results for later gathering it for building with analysis data
abstract class AuxiliarAnalyzerBuilder<T extends AnalyzerAuxiliedClass>
    extends MIBuilder {
  final AnalysisGatheringFunction func;
  final WorkaroundGatheringFunction workaroundFunc;
  final String auxiliarExtension;
  final Set<Glob> legalInputs;
  T instance;
  final bool throwOnAnalysisError;

  AuxiliarAnalyzerBuilder(this.instance, {this.throwOnAnalysisError = true})
      : workaroundFunc = instance.onUnresolvableFileException,
        auxiliarExtension = instance.auxiliarExtension,
        func = instance.analysisResultsFor,
        legalInputs = instance.inputGlobs;

  @override
  Future<void> build(BuildStep buildStep) async {
    await super.build(buildStep);
    var asset = buildStep.inputId;
    if (!legalInputs.any((g) => g.matches(asset.path))) {
      log.finest('Discarting $asset from $runtimeType.build because '
          'of unmatching inputGlobs (modify globs in your build.yaml for omitting this message)');
      return;
    } else {
      log.fine('Analyzing $asset through $runtimeType');
    }
    if (!asset.path.endsWith('.dart')) {
      throw ArgumentError(
          "'$asset' given as input, only .dart files must be provided");
    }
    late LibraryElement inputLibrary;
    late Resolver resolver;
    Map? processedResolution;
    currentZone = Zone.current;
    //Para saber x q esta garcha... https://stackoverflow.com/questions/58335158/darts-runzoned-behaviour-on-async-modified-bodies
    var completer = Completer();
    var workaroundError;
    runZonedGuarded(() {
      Future.microtask(() async {
        try {
          inputLibrary = await buildStep.inputLibrary;
          resolver = await buildStep.resolver;
          MIBuilderBuildStepHandler.setBuildStep(instance, buildStep);
          MIBuilderBuildStepHandler.setBuildStep(this, buildStep);
          processedResolution = await func(asset, inputLibrary, resolver);
          completer.complete();
        } catch (e) {
          var err = AnalysisException(buildStep.inputId);
          if (throwOnAnalysisError) {
            completer.completeError(err);
          } else {
            throw err; //have it handled by onError of the runZoned
          }
        }
      });
    }, (e, s) {
      workaroundError = e;
      completer.complete();
    });

    await completer.future;

    if (workaroundError != null) {
      // var pkg = Packages().resolvePackageUri(asset.uri);
      // var resource = await pkg.resource;
      // var absoluteFilePath = resource.path;
      // var session = getCompleteSessionFor(absoluteFilePath);
      // await runZoned(() async {
      //   // var rLib = await session.getResolvedLibrary(absoluteFilePath);
      //   // inputLibrary = rLib.element;
      //   var path = session.uriConverter.uriToPath(asset.uri);
      //   session.getLibraryByUri(path);
      //   inputLibrary = await session.getLibraryByUri(path);
      // }, onError: (e) async {
      var source = await buildStep.readAsString(asset);
      var results = parseString(content: source);
      var err = UnresolvableFileException(
          workaroundError, results.unit, source, asset, T);
      var workaround;
      // }, zoneSpecification: executionRedirector);
      workaround = workaroundFunc(err);
      if (workaround is Future) {
        workaround = await workaround.catchError((e) {
          throw StateError(
              'The workaroundFunction throwed. This is the error: $e\n'
              'Wish u luck fixing it ;-)');
        });
      }
      if (workaround is Map && workaround['unimplemented'] == true) {
        throw err;
      }
      processedResolution = workaround;
      // });
    }
    var destination = AssetId(asset.package, asset.path + auxiliarExtension);
    String encodedJSON;
    try {
      encodedJSON = json.encode(processedResolution);
    } on JsonUnsupportedObjectError catch (e) {
      throw ArgumentError(
          'Error when trying to serialize to JSON the analysis Map provided ($e).\n'
          'Remember that the, by default, valid values are: '
          'number, boolean, String, null, List and Map<String,dynamic>\n'
          'When there are other types, those objects have .toJson() called on them.');
    }
    log.finer(
        'Analyzing $asset through $runtimeType finished. Now writing to $destination...');
    await buildStep.writeAsString(destination, encodedJSON);
    log.finest('$destination written');
  }

  @override
  Map<String, List<String>> get buildExtensions => {
        '.dart': ['.dart' + auxiliarExtension]
      };
}

/// Creado para ver si podía reemplazar con esto el estado de la ejecución
/// de func. Al final parece andar bien con reemplazar el buildStep asi q no se
/// está usando actualmente, pero lo dejamo' acá x las dudas
var executionRedirector = ZoneSpecification(
  run: <R>(self, parent, zone, function) => parent.run(currentZone, function),
  runUnary: <R, T>(self, parent, zone, function, T arg) =>
      parent.runUnary(currentZone, function, arg),
  runBinary: <R, T1, T2>(self, parent, zone, function, T1 arg1, T2 arg2) =>
      parent.runBinary(currentZone, function, arg1, arg2),
  registerCallback: <R>(self, parent, zone, function) =>
      parent.registerCallback(currentZone, function),
  registerUnaryCallback: <R, T>(self, parent, zone, function) =>
      parent.registerUnaryCallback(currentZone, function),
  registerBinaryCallback: <R, T1, T2>(self, parent, zone, function) =>
      parent.registerBinaryCallback(currentZone, function),
);

class UnresolvableFileException extends Error {
  final dynamic error;
  final AssetId asset;
  final String source;
  final CompilationUnit unit;
  @override
  final Type runtimeType;

  UnresolvableFileException(
      this.error, this.unit, this.source, this.asset, this.runtimeType);

  @override
  String toString() =>
      'Error while trying to get library/resolver for $asset ($error).\n'
      'This commonly happens, not always though, when trying to analyze a file with code that'
      ' needs generated code for being complete (normally .g.dart parts). Make sure \n'
      '$asset is well formed at this point of generation (set a breakpoint to check).\n'
      "Maybe as a workaround you could work with the unresolved AST 'unit' or raw 'source' "
      'parameters provided in this throwed UnresolvableFileException. Do that by implementing '
      'the $runtimeType.onUnresolvableFileException field function of the builder.\n'
      'See https://github.com/dart-lang/build/tree/master/build_config#adjusting-builder-ordering'
      ' for rearranging building ordering.';
}

class AnalysisException extends Error {
  final AssetId inputId;

  AnalysisException(this.inputId);

  @override
  String toString() => "Couldn't analyze $inputId input.";
}
