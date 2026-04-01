import 'dart:async';

import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:test/test.dart';
import 'package:build_test/build_test.dart';
import 'package:build_utils/build_utils.dart';

class AuxiliarTestAnalyzerMIMOBuilder extends AuxiliarAnalyzerBuilder {
  AuxiliarTestAnalyzerMIMOBuilder(AnalyzerAuxiliedClass instance)
      : super(instance);
}

/// A builder that creates .info files with the names of the variables that the analyzer
/// finds in the .dart files given, as well as .dart files with the sum of de declarations
/// of vars taken from those .dart input files
class TestAnalyzerMIMOBuilder extends BuilderAnalyzerMIMO {
  TestAnalyzerMIMOBuilder(Map<String, Set<String>> generations, bool formatDart)
      : super(generations, formatDart);

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
  FutureOr<String> buildOutputWithAnalysisFor(
      String outputPath, Map<AssetId, Map<String, dynamic>> inputsWithAnalysis) async {
    if (outputPath.endsWith('.info')) {
      //Return every name found separated by newlines
      var names = <String>[];
      inputsWithAnalysis.forEach((k, v) {
        assert(k.toString() == v['asset']);
        names.addAll((v['varNames'] as List).cast<String>());
      });
      return names.join('\n');
    } else if (outputPath.endsWith('.dart')) {
      //meter todo el codigo en un mismo file
      var code = <String>[];
      await Future.forEach(inputsWithAnalysis.entries, (e) async {
        code.add(await getSource(e.key));
      });
      return code.join('\n');
    } else {
      throw Error();
    }
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

TestAnalyzerMIMOBuilder testedBuilder() => TestAnalyzerMIMOBuilder({
      'out.info': {'**.dart'},
      'out.dart': {'**.dart'}
    }, true);

String get rootPkg => 'a';

void main() {
  group('MIMOBuilder tests', () {
    late Map<String, String> buildedOutputs;
    late String infoContents, dartUnifiedFile;
    setUpAll(() async {
      buildedOutputs = await _buildWithBuilders();
      infoContents = buildedOutputs['$rootPkg|out.info']!;
      dartUnifiedFile = buildedOutputs['$rootPkg|out.dart']!;
    });
    test('outputs only the topLevelVars names of the .dart files in the .info',
        () {
      expect(infoContents.split('\n').length, equals(3));
      expect(infoContents, contains('strVarF1'));
      expect(infoContents, contains('strVarF2'));
      expect(infoContents, contains('strVarF3'));
      expect(infoContents, isNot(contains('strVarF4')));
      expect(infoContents, isNot(contains('strVarF5')));
    });
    test('unifies all the dart contents in one file and formats it', () {
      expect(dartUnifiedFile, isNot(contains("String strVarF1='str1';")));
      expect(dartUnifiedFile, contains("String strVarF1 = 'str1';"));
      expect(dartUnifiedFile, isNot(contains("String strVarF2='str2';")));
      expect(dartUnifiedFile, contains("String strVarF2 = 'str2';"));
      expect(dartUnifiedFile, isNot(contains("String strVarF3='str3';")));
      expect(dartUnifiedFile, contains("String strVarF3 = 'str3';"));
    });
  });
}

Future<Map<String, String>> _buildWithBuilders() async {
  var testAnalyzerMIMOBuilder = testedBuilder();
  var testAuxiliarAnalyzerMIMOBuilder =
      AuxiliarTestAnalyzerMIMOBuilder(testAnalyzerMIMOBuilder);
  var writer = InMemoryAssetWriter();
  // var writerSpy = AssetWriterSpy(writer);
  await testBuilder(testAuxiliarAnalyzerMIMOBuilder, inputAssets(rootPkg),
      rootPackage: rootPkg, writer: writer);

  var builded = buildedAssets(writer);
  await testBuilder(
      testAnalyzerMIMOBuilder, Map<String, String>.from(inputAssets(rootPkg))..addAll(builded),
      rootPackage: rootPkg, writer: writer);
  var ret = buildedAssets(writer);
  return ret
    ..removeWhere(
        (k, v) => k.endsWith(testAnalyzerMIMOBuilder.auxiliarExtension));
}

Map<String, String> buildedAssets(InMemoryAssetWriter writer) {
  var ret = <String, String>{};
  writer.assets.forEach((AssetId asset, List<int> bytes) {
    ret[asset.toString()] = String.fromCharCodes(bytes);
  });
  return ret;
}
