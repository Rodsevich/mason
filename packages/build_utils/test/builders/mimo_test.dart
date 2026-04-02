import 'dart:async';

import 'package:build/build.dart';
import 'package:test/test.dart';
import 'package:build_test/build_test.dart';
import 'package:build_utils/build_utils.dart' show BuilderMIMO;

class TestMIMOBuilder extends BuilderMIMO {
  TestMIMOBuilder(Map<String, Set<String>> generations, bool formatDart)
      : super(generations, formatDart);

  @override
  FutureOr<String> buildOutputFor(String outputPath, Set<AssetId> inputs) {
    var ret = StringBuffer();
    if (outputPath.startsWith('darts')) {
      ret.writeln('Dart files:');
      for (var i in inputs) {
        ret.writeln(' - $i');
      }
    } else if (outputPath.startsWith('txts')) {
      ret.writeln('Txt files:');
      for (var i in inputs) {
        ret.writeln(' - $i');
      }
    } else {
      throw Error();
    }
    return ret.toString();
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
      '$pkg|some/archivo.txt': "String strVarF7='str7';",
    };

TestMIMOBuilder testedBuilder() => TestMIMOBuilder({
      'darts.info': {'**.dart'},
      'txts.info': {'**file.txt', '**file2.txt', '**archivo.txt'}
    }, true);

String get rootPkg => 'a';

void main() {
  group('MIMOBuilder tests', () {
    late Map<AssetId, String> buildedOutputs;
    late String dartsContents, txtsContents;
    setUpAll(() async {
      buildedOutputs = await _buildWithBuilder();
      try {
        dartsContents = buildedOutputs[AssetId(rootPkg, 'darts.info')]!;
        txtsContents = buildedOutputs[AssetId(rootPkg, 'txts.info')]!;
      } catch (e) {
        fail(
            'The is/are a/an error/s when producing the test outputs expected:\n$e');
      }
    });
    test('the files begins as spected', () {
      expect(dartsContents, startsWith('Dart files:'));
      expect(txtsContents, startsWith('Txt files:'));
    });

    test('Contains all the .dart files expected', () {
      expect(dartsContents, contains(' - $rootPkg|file1.dart'));
      expect(dartsContents, contains(' - $rootPkg|file2.dart'));
      //ponerlo asi para saltearse el path
      expect(dartsContents, contains('file3.dart'));
    });
    test('Contains all the .txt files expected', () {
      //tiene q tener 2 file.txt
      expect(txtsContents, stringContainsInOrder(['file.txt', 'file.txt']));
      expect(txtsContents, contains('file2.txt'));
      expect(txtsContents, contains('archivo.txt'));
    });
  });
}

Future<Map<AssetId, String>> _buildWithBuilder() async {
  var testMIMOBuilder = testedBuilder();
  var writer = InMemoryAssetWriter();
  // var writerSpy = AssetWriterSpy(writer);
  await testBuilder(testMIMOBuilder, inputAssets(rootPkg),
      rootPackage: rootPkg, writer: writer);
  var ret = <AssetId, String>{};
  writer.assets.forEach((AssetId asset, List<int> bytes) {
    ret[asset] = String.fromCharCodes(bytes);
  });
  return ret;
}
