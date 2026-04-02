import 'package:analysis_utils/analysis.dart';
import 'package:build/build.dart';
import 'package:path/path.dart' as p;

/// Creates an import directive for importing the given asset in the provided source file
String getImport(
        AssetId asset, String sourcePackageName, String sourceFilePath) =>
    "import '${getUri(asset, sourcePackageName, sourceFilePath)}';";

/// Creates an export directive for importing the given asset in the provided source file
String getExport(
        AssetId asset, String sourcePackageName, String sourceFilePath) =>
    "export '${getUri(asset, sourcePackageName, sourceFilePath)}';";

/// Procceses an URI for the given asset relative to the provided source file
String getUri(AssetId asset, String sourcePackageName, String sourceFilePath) {
  if (asset.path.startsWith('lib')) {
    //The path with the "lib/" part removed
    return 'package:${asset.package}${asset.path.substring(3)}';
  } else {
    if (p.split(asset.path).first == 'tool') {
      if (p.split(sourceFilePath).first == 'tool') {
        if (asset.package == sourcePackageName) {
          return p.relative(asset.path, from: p.dirname(sourceFilePath));
        } else {
          throw UnsupportedError(
              'There is no Dart-legal way of referencing to the tool/ dir of another package ($sourcePackageName|$sourceFilePath -/-> $asset)');
        }
      } else {
        throw UnsupportedError(
            'You should reference the file by a relative path being both files in the same dir ($sourcePackageName|$sourceFilePath -/-> $asset)');
      }
    } else {
      throw UnimplementedError(
          'WTF? How do I get the URI of $asset (not located in lib nor tool)? Which is your use case? ($sourcePackageName|$sourceFilePath -/-> $asset)');
    }
  }
}

String getMixin(SourceAnalysis analysis) {
  return analysis.mixins.single.name;
}
