import 'dart:async';

import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:test/test.dart';
import 'package:build_test/build_test.dart';
import 'package:build_utils/build_utils.dart';

class AuxiliarTestAnalyzerMISOBuilder extends AuxiliarAnalyzerBuilder {
  AuxiliarTestAnalyzerMISOBuilder(AnalyzerAuxiliedClass instance)
      : super(instance);
}

class TestAnalyzerMISOBuilder extends BuilderAnalyzerMISO {
  TestAnalyzerMISOBuilder(
      Iterable<String> inputsGlobPaths, String outputPath, bool formatDart)
      : super(inputsGlobPaths, outputPath, formatDart);

  @override
  FutureOr<Map> analysisResultsFor(
      AssetId asset, LibraryElement library, Resolver resolver) {
    // Map<String, List<String>> ret = {};
    var ret = {};
    ret['asset'] = asset.toString();
    ret['varNames'] = library.definingCompilationUnit.topLevelVariables
        .map<String>((t) => t.name)
        .toList();
    return ret;
  }

  @override
  FutureOr<String> buildOutputWithAnalysis(
      Map<AssetId, Map<String, dynamic>> inputsWithAnalysis) {
    //Return every name found separated by newlines
    var names = <String>[];
    inputsWithAnalysis.forEach((k, v) {
      assert(k.toString() == v['asset']);
      names.addAll((v['varNames'] as List).cast<String>());
    });
    return names.join('\n');
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

TestAnalyzerMISOBuilder testedBuilder() =>
    TestAnalyzerMISOBuilder(['**.dart'], 'lib/out.txt', true);

String get rootPkg => 'a';

void main() {
  group('MISOBuilder tests', () {
    late Map<String, String> buildedOutputs;
    late String outputFile;
    setUpAll(() async {
      buildedOutputs = await _buildWithBuilders();
      try {
        outputFile = buildedOutputs.entries.firstWhere((e) => !e.key.endsWith('.info')).value;
      } catch (e) {
        fail('There should be one, and only one output (Error: $e)');
      }
    });

    test('Builds the correct amount of assets', () {
      // 1 builded final output (and  3 .auxiliarAnalyzerMISO.info filtered out)
      expect(buildedOutputs.length, equals(1));
    });
    test('outputs only the topLevelVars names of the .dart files', () {
      expect(outputFile.split('\n').length, equals(3));
      expect(outputFile, contains('strVarF1'));
      expect(outputFile, contains('strVarF2'));
      expect(outputFile, contains('strVarF3'));
    });
  });
}

Future<Map<String, String>> _buildWithBuilders() async {
  var testAnalyzerMISOBuilder = testedBuilder();
  var testAuxiliarAnalyzerMISOBuilder =
      AuxiliarTestAnalyzerMISOBuilder(testAnalyzerMISOBuilder);
  var writer = InMemoryAssetWriter();
  // var writerSpy = AssetWriterSpy(writer);
  await testBuilder(testAuxiliarAnalyzerMISOBuilder, inputAssets(rootPkg),
      rootPackage: rootPkg, writer: writer);

  var builded = buildedAssets(writer);
  await testBuilder(
      testAnalyzerMISOBuilder, Map<String, String>.from(inputAssets(rootPkg))..addAll(builded),
      rootPackage: rootPkg, writer: writer);
  var ret = buildedAssets(writer);
  ret.removeWhere((k, v) => k.endsWith('.info'));
  return ret;
}

Map<String, String> buildedAssets(InMemoryAssetWriter writer) {
  var ret = <String, String>{};
  writer.assets.forEach((AssetId asset, List<int> bytes) {
    ret[asset.toString()] = String.fromCharCodes(bytes);
  });
  return ret;
}
