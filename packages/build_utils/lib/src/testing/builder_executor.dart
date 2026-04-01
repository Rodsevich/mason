import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:build_utils/src/testing/utils.dart';

/// Executes the given `builder` in the given `inputAssets` and returns the builded files
/// in a map which keys contains a packageName|filePath fomatted URI of a file which contents
/// are stored in it's respective value
Future<Map<String, String>> executeBuilder(
    Builder builder, Map<String, String> inputAssets,
    {/* List<String>|Map<String, List<String>> */ generateForSource,
    String rootPkgName = 'a'}) async {
  var generateForProcessor = GenerateForProcessor(generateForSource);
  var writer = InMemoryAssetWriter();
  await testBuilder(builder, inputAssets,
      rootPackage: rootPkgName,
      writer: writer,
      isInput: generateForProcessor?.isInputFunc);
  return await buildedAssets(writer);
}
