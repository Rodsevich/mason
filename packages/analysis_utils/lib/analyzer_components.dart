///The pertinent to handling the resolution of the analyzer package
///in a simplified way
library analyzer_primitives;

import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/session.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import "package:analyzer/src/dart/analysis/analysis_context_collection.dart";
import 'package:analyzer/file_system/memory_file_system.dart';
import 'package:glob/glob.dart';
import 'package:glob/list_local_fs.dart';
import 'package:path/path.dart' as p;
import 'package:cli_util/cli_util.dart';

export 'package:analyzer/dart/analysis/session.dart';

Directory _getPackageRoot(path) {
  if (!p.isAbsolute(path)) {
    throw ArgumentError.value(path, "path", "Must be absolute");
  }
  Directory dir = Directory(p.dirname(path));
  try {
    while (
        dir.listSync().any((f) => f.path.endsWith("pubspec.yaml")) == false &&
            dir.path != "/") dir = dir.parent;
  } catch (e) {
    throw Exception(
        "Error while trying to find pubspec.yaml from ${dir.path}:\n$e");
  }
  return dir;
}

Future<SomeErrorsResult> getErrorsFor(String path) async {
  var session = getCompleteSessionFor(path);
  return session.getErrors(path);
}

/// Provided a path. compute it's package files and return its [AnalysisSession]
AnalysisSession getCompleteSessionFor(String path) {
  if (!p.isAbsolute(path)) {
    throw ArgumentError.value(path, "path", "Must be absolute");
  }
  var root = _getPackageRoot(path).path;
  List<String> includedPaths =
      Glob(root + p.separator + "**.dart", recursive: true)
          .listSync(root: root)
          .map((e) => e.path)
          .toList();
  AnalysisContextCollection collection =
      AnalysisContextCollection(includedPaths: includedPaths);
  return collection.contextFor(path).currentSession;
}

CompilationUnit getCompilationUnitForPath(String path) {
  path = p.normalize(p.absolute(path));
  AnalysisContextCollection col =
      AnalysisContextCollection(includedPaths: [path]);
  AnalysisSession ses = col.contextFor(path).currentSession;
  final ret = ses.getParsedUnit(path);
  if (ret is ParsedUnitResult) {
    return ret.unit;
  } else {
    throw UnimplementedError("Not implemented for ${ret.runtimeType}");
  }
}

/// Provide a source and get its AST CompilationUnit, throws the errors if some
CompilationUnit getCompilationUnitForSource(String source
// , {String path, bool throwOnErrors: true}) {
    ) {
  var parsed = parseString(content: source, throwIfDiagnostics: true);
  return parsed.unit;
  // parsed.path ??= "/path.dart";
  // path = p.normalize(p.absolute(path));
  // ParsedUnitResult unitResult;
  // AnalysisSession session;
  // try {
  //   session = getAnalysisSessionForSource(source, path: path);
  //   unitResult = session.getParsedUnit(path);
  // } catch (e) {
  //   File f = File(Directory.systemTemp.path + p.separator + "file.dart");
  //   f.createSync(recursive: true);
  //   f.writeAsStringSync(source);
  //   unitResult = parseFile(path: f.path);
  //   f.deleteSync(recursive: true);
  // }
  // if (throwOnErrors && unitResult.errors.isNotEmpty) {
  //   throw unitResult.errors;
  // } else {
  //   return unitResult.unit;
  // }
}

AnalysisSession getAnalysisSessionForSource(String source,
    {String path = "/path.dart"}) {
  path = p.normalize(p.absolute(path));
  AnalysisContextCollection col =
      getAnalysisContextCollectionForSource(source, path: path);
  AnalysisContext ctx = col.contextFor(path);
  return ctx.currentSession;
}

AnalysisContextCollection getAnalysisContextCollectionForSource(String source,
    {String path = "/path.dart"}) {
  path = p.normalize(p.absolute(path));
  MemoryResourceProvider resourceProvider =
      MemoryResourceProvider(context: p.context);
  //Como me aseguro q es único porque en el forContents se fija si el codigo
  //ya está cacheado o no, no compruebo nada y le pongo un path distinto y fue
  resourceProvider.newFile(path, source);
  AnalysisContextCollection col = AnalysisContextCollectionImpl(
      includedPaths: [path],
      resourceProvider: resourceProvider,
      sdkPath: getSdkPath());
  return col;
}
