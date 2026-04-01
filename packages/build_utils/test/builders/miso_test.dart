import 'dart:async';

import 'package:build/build.dart';
import 'package:test/test.dart';
import 'package:build_test/build_test.dart';
import 'package:build_utils/build_utils.dart' show BuilderMISO;

class TestMISOBuilder extends BuilderMISO {
  TestMISOBuilder(
      Iterable<String> inputsGlobPaths, String outputPath, bool formatDart)
      : super(inputsGlobPaths, outputPath, formatDart);

  @override
  FutureOr<String> buildOutput(Set<AssetId> inputs) async {
    var ret = '';
    for (var assetId in inputs) {
      var contents = await getSource(assetId);
      // LibraryElement l = await getLibraryElement(assetId);
      // String varName = l?.topLevelElements?.single?.name ?? "FAIL";
      // ret += "//Asset $assetId declares $varName\n$contents\n";
      ret += '//Asset $assetId contains:\n$contents\n';
    }
    return ret;
  }
}

Map<String, String> inputAssets(String pkg) => {
      '$pkg|file1.dart': "String strVarF1='str1';",
      '$pkg|file2.dart': "String strVarF2='str2';",
      '$pkg|some/subdirs/path/file3.dart': "String strVarF3='str3';",
      '$pkg|configs.yaml': 'foo: bar',
      '$pkg|file.txt': "String strVarF4='str4';",
      '$pkg|some/subdirs/path/file.txt': "String strVarF5='str5';",
      '$pkg|some/longer/subdirs/path/file2.txt': "String strVarF6='str6';",
    };

TestMISOBuilder testedBuilder() =>
    TestMISOBuilder(['**.dart', '**file.txt'], 'lib/out.dart', true);

String get rootPkg => 'a';

void main() {
  group('MISOBuilder tests', () {
    late Map<AssetId, String> buildedOutputs;
    late String outputFile;
    setUpAll(() async {
      buildedOutputs = await _buildWithBuilder();
      try {
        outputFile = buildedOutputs.entries.single.value;
      } catch (e) {
        fail('There should be one, and only one output (Error: $e)');
      }
    });

    test('Builds the correct amount of assets', () {
      expect(buildedOutputs.length, equals(1));
    });

    test("Contains only .dart and 'file.txt' files", () {
      // List<String> lines = outputFile.split("\n");
      // expect(lines.length, equals(5));
      // var re = RegExp(r"^Asset .*file\d*\.[dart|txt]");
      // for (var line in lines) {
      //   expect(re.hasMatch(line), isTrue);
      // }
      expect(outputFile, isNot(contains('//Asset configs.yaml')));
      expect(outputFile, isNot(contains('//Asset file2.txt')));
    });
    // test('Gets the var names from the LibraryElement', () {
    //   RegExp re = RegExp(r"declares strVarF\d");
    //   List<Match> matches = re.allMatches(outputFile).toList();
    //   expect(matches.length, equals(5));
    //   for (var i = 1; i <= 5; i++) {
    //     expect(matches[i - 1].group(0), endsWith(i.toString()));
    //   }
    // });
    test('Formats the out.dart file', () {
      expect(outputFile, contains("String strVarF1 = 'str1';"));
      expect(outputFile, contains("String strVarF2 = 'str2';"));
      expect(outputFile, contains("String strVarF3 = 'str3';"));
      expect(outputFile, contains("String strVarF4 = 'str4';"));
      expect(outputFile, contains("String strVarF5 = 'str5';"));
      expect(outputFile, isNot(contains("String strVarF6 = 'str6';")));
    });
  });
}

Future<Map<AssetId, String>> _buildWithBuilder() async {
  var testMISOBuilder = testedBuilder();
  var writer = InMemoryAssetWriter();
  // var writerSpy = AssetWriterSpy(writer);
  await testBuilder(testMISOBuilder, inputAssets(rootPkg),
      rootPackage: rootPkg, writer: writer);
  var ret = <AssetId, String>{};
  writer.assets.forEach((AssetId asset, List<int> bytes) {
    ret[asset] = String.fromCharCodes(bytes);
  });
  return ret;
}
