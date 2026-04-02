import 'dart:async';

import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import 'package:test/test.dart';
import 'package:build_test/build_test.dart';
import 'package:build_utils/build_utils.dart';

class TestClassPartGenerator extends ClassPartGenerator {
  TestClassPartGenerator(ShouldGenerateForFuction checkingFn)
      : super(checkingFunction: checkingFn);

  @override
  FutureOr<String> partCode(ClassElement element) {
    return '//Found class: ${element.name}';
  }
}

Map<String, String> inputAssets(String pkg) => {
      '$pkg|file1.dart': '''
      part 'file1.g.dart';
      class _Clazz{
        int field1;
        _Clazz(this.field1);
        int method1() => field1;
      }''',
      '$pkg|file2.dart': '''
      part 'file2.g.dart';
      class _Claz{
        int field1;
        _Claz(this.field1);
        int method1() => field1;
      }
      class Claz{
        int? field1;
      }''',
      '$pkg|file3.dart': '''
      class Clazz{
        int? field1;
      }''',
    };

Builder testedBuilder() =>
    PartBuilder([TestClassPartGenerator((e) => e.isPrivate)], '.g.dart');

String get rootPkg => 'a';

void main() {
  group('TestClassPartGenerator tests', () {
    late Map<AssetId, String> buildedOutputs;
    setUpAll(() async {
      buildedOutputs = await _buildWithBuilder();
    });

    test('Builds the correct amount of assets', () {
      expect(buildedOutputs.length, equals(2));
    });

    test('Finds the private classes in the corresponding parts', () {
      String f1, f2;
      f1 = buildedOutputs.entries
          .singleWhere((e) => e.key.pathSegments.last == 'file1.g.dart')
          .value;
      f2 = buildedOutputs.entries
          .singleWhere((e) => e.key.pathSegments.last == 'file2.g.dart')
          .value;
      expect(RegExp(r'part of .*file1.dart').hasMatch(f1), isTrue);
      expect(f1, contains('Found class: _Clazz'));
      expect(RegExp(r'part of .*file2.dart').hasMatch(f2), isTrue);
      expect(f2, contains('Found class: _Claz'));
      expect(f2, isNot(contains('Found class: Claz')));
    });
  });
}

Future<Map<AssetId, String>> _buildWithBuilder() async {
  var testClassPartGenerator = testedBuilder();
  var writer = InMemoryAssetWriter();
  // var writerSpy = AssetWriterSpy(writer);
  await testBuilder(testClassPartGenerator, inputAssets(rootPkg),
      rootPackage: rootPkg, writer: writer);
  var ret = <AssetId, String>{};
  writer.assets.forEach((AssetId asset, List<int> bytes) {
    ret[asset] = String.fromCharCodes(bytes);
  });
  return ret;
}
