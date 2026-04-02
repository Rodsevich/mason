import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:glob/glob.dart';

/// Gets the assets created with `writer` in a map which keys contains a
/// packageName|filePath fomatted URI of a file which contents are stored in
/// it's respective value
Map<String, String> buildedAssets(InMemoryAssetWriter writer) {
  var ret = <String, String>{};
  writer.assets.forEach((AssetId asset, List<int> bytes) {
    ret[asset.toString()] = String.fromCharCodes(bytes);
  });
  return ret;
}

/// A class in charge of adapting the `sources:` and `generateFor:` configurations
/// of the package:build_config's `build.yaml` to the Dart code test style
class GenerateForProcessor {
  /* List<String>|Map<String, List<String>> */ var generateForSource;
  Map<String, List<String>> _generateFor;

  Iterable<Glob> _include;
  Iterable<Glob> _exclude = [];

  GenerateForProcessor([this.generateForSource]) {
    if (generateForSource != null) {
      if (generateForSource is List<String>) {
        _generateFor = {'include': generateForSource};
      } else if (generateForSource is Map<String, List<String>> &&
          generateForSource.keys.length <= 2 &&
          generateForSource.keys
              .every((key) => RegExp(r'^(ex|in)clude$').hasMatch(key))) {
        _generateFor = generateForSource;
      } else {
        throw ArgumentError.value(
            generateForSource,
            'generateForSource',
            "must provide a List<String> with the 'include' inputs "
                "or a Map<String, List<String>> with only the 'include' "
                "an 'exclude' lists");
      }
      if (generateForSource.containsKey('exclude')) {
        _include = _generateFor['include']?.map((g) => Glob(g));
        _exclude = _generateFor['exclude']?.map((g) => Glob(g));
      } else {
        _include = _generateFor['include']?.map((g) => Glob(g));
      }
    }
  }

  /// The function that checks if `path` should be considered an input from
  /// the `generateForSource` provided in the construction of this class
  bool isInputFunc(String assetIdPath) {
    var path = assetIdPath.split('|').last;
    if (_exclude?.any((g) => g.matches(path)) ?? false) {
      return false;
    } else {
      if (_include?.any((g) => g.matches(path)) ?? true) {
        return true;
      } else {
        return false;
      }
    }
  }
}
