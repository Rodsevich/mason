import 'package:analysis_utils/analysis.dart';
import 'package:test/test.dart';

String _source = '''library lib.name;
import "package:path/path.dart" as p hide equals;
export './analysis_utils_test.dart' show ChildClass;
part 'part.dart';
///docs
@ClassUno
var var1;
@ClassUno
@ClassDos
///docs
List<int> var2 = [4, 3, 2, 1];
@ClassUno
String var3 = "sorp", var4 = "longa";

class ClassUno{
  int? field1;
  String field2 = "default2";

  String method1() => field2 + field1.toString();
}

class ClassDos{
  @ClassUno
  final List<String> field1;
  ClassDos(this.field1, String simple, {List<int> named = const [2]});

  void method1(int arg1, [arg2, String arg3 = "sorp"]){}
}''';

void main() {
  late SourceAnalysis sourceAnalysis;
  setUpAll(() {
    sourceAnalysis = SourceAnalysis.forContents(_source);
  });

  group("SourceAnalysis:", () {
    test("classes found", () {
       expect(sourceAnalysis.classes.map((c) => c.name), containsAll(["ClassUno", "ClassDos"]));
    });

    group("maps", () {
      test("topLevelVariables", () {
        Map mapa = sourceAnalysis.toMap();
        expect(mapa["topLevelVariables"], isNotEmpty);
        expect(mapa["topLevelVariables"].length, equals(4));
        expect(mapa["topLevelVariables"][0]["docs"], equals("///docs"));
        expect(mapa["topLevelVariables"][0]["metadata"][0]["name"],
            equals("ClassUno"));
      });
      test("class", () {
        Map mapa = sourceAnalysis.toMap();
        expect(mapa["classes"], isNotNull);
        expect(mapa["classes"][1]["fields"], isNotEmpty);
        expect(
            mapa["classes"][1]["fields"][0]["name"], equals("field1"));
        expect(mapa["classes"][1]["fields"][0]["typeString"],
            equals("List<String>"));
        expect(mapa["classes"][1]["methods"], isNotEmpty);
        expect(mapa["classes"][1]["methods"][0]["name"],
            equals("method1"));
        expect(mapa["classes"][1]["methods"][0]["parameters"],
            hasLength(3));
        expect(
            mapa["classes"][1]["methods"][0]["parameters"][0]["name"],
            equals("arg1"));
        expect(
            mapa["classes"][1]["methods"][0]["parameters"][1]["name"],
            equals("arg2"));
        expect(
            mapa["classes"][1]["methods"][0]["parameters"][2]["name"],
            equals("arg3"));
      });
    });
    group("SourceLocations:", () {
      test('Directives', () {
        var libraryDirective = sourceAnalysis.library!;
        var importDirective = sourceAnalysis.imports.single;
        var exportDirective = sourceAnalysis.exports.single;
        var partDirective = sourceAnalysis.parts.single;

        expect(libraryDirective.location.start.line, equals(0));
        expect(libraryDirective.location.start.offset, equals(0));
        expect(libraryDirective.location.text, equals("library lib.name;"));
        expect(libraryDirective.location.end.offset,
            equals(libraryDirective.location.length));
        expect(libraryDirective.location.end.line, equals(0));
        expect(importDirective.location.start.offset,
            equals(libraryDirective.location.length + 1));
        expect(importDirective.location.text,
            equals('import "package:path/path.dart" as p hide equals;'));
        expect(
            importDirective.location.end.offset,
            equals(libraryDirective.location.length +
                importDirective.location.length +
                1));
        expect(exportDirective.location.start.offset,
            equals(importDirective.location.end.offset + 1));
        expect(exportDirective.location.text,
            equals("export './analysis_utils_test.dart' show ChildClass;"));
        expect(partDirective.location.start.offset,
            equals(exportDirective.location.end.offset + 1));
        expect(partDirective.location.text, equals("part 'part.dart';"));
      });
      test("TopLevelVariables", () {
        var v1 = sourceAnalysis.topLevelVariables.first;
        var v2 = sourceAnalysis.topLevelVariables[1];
        var v3 = sourceAnalysis.topLevelVariables[2];
        var v4 = sourceAnalysis.topLevelVariables.last;

        expect(v1.location.start.offset,
            equals(sourceAnalysis.code.indexOf("///docs")));
        expect(v1.location.text, equals("///docs\n@ClassUno\nvar var1;"));
        expect(
            v2.location.text,
            equals(
                "@ClassUno\n@ClassDos\n///docs\nList<int> var2 = [4, 3, 2, 1];"));
        expect(v3.location.text, startsWith("@ClassUno"));
        expect(v4.location.text, startsWith("@ClassUno"));
        expect(
            _source.substring(v1.location.start.offset, v1.location.end.offset),
            equals(v1.location.text));
        expect(
            _source.substring(v3.location.start.offset, v3.location.end.offset),
            equals(v3.location.text));
      });
      test("Classes", () {
        var c1 = sourceAnalysis.classes.singleWhere((c) => c.name == "ClassUno");
        var c2 = sourceAnalysis.classes.singleWhere((c) => c.name == "ClassDos");

        expect(c1.location.text, startsWith("class ClassUno{"));
        expect(c1.location.text, contains(".toString();\n}"));
        expect(c2.location.text, startsWith("class ClassDos{"));
        expect(c2.location.text, contains("){}\n}"));
        expect(
            _source.substring(c1.location.start.offset, c1.location.end.offset),
            equals(c1.location.text));
        expect(
            _source.substring(c2.location.start.offset, c2.location.end.offset),
            equals(c2.location.text));
      });
    });
    group("Directives:", () {
      test('library', () {
        expect(sourceAnalysis.library!.name, equals("lib.name"));
      });
      test("import", () {
        var importDirective = sourceAnalysis.imports.single;
        expect(importDirective.uri, equals("package:path/path.dart"));
        expect(importDirective.prefix, equals("p"));
        expect(importDirective.hides.single, equals("equals"));
        expect(importDirective.shows, isEmpty);
      });
      test("export", () {
        var exportDirective = sourceAnalysis.exports.single;
        expect(exportDirective.uri, equals("./analysis_utils_test.dart"));
        expect(exportDirective.shows.single, equals("ChildClass"));
        expect(exportDirective.hides, isEmpty);
      });
      test("part", () {
        expect(sourceAnalysis.parts.single.uri, equals("part.dart"));
      });
    });
    group("TopLevelVariables:", () {
      test("names", () {
        expect(sourceAnalysis.topLevelVariables[0].name, equals("var1"));
        expect(sourceAnalysis.topLevelVariables[1].name, equals("var2"));
        expect(sourceAnalysis.topLevelVariables[2].name, equals("var3"));
        expect(sourceAnalysis.topLevelVariables[3].name, equals("var4"));
      });
      test("default values", () {
        expect(sourceAnalysis.topLevelVariables[0].defaultValue, isNull);
        expect(sourceAnalysis.topLevelVariables[1].defaultValue, equals([4, 3, 2, 1]));
        expect(sourceAnalysis.topLevelVariables[2].defaultValue, equals("sorp"));
        expect(sourceAnalysis.topLevelVariables[3].defaultValue, equals("longa"));
      });
      test("types", () {
        expect(sourceAnalysis.topLevelVariables[0].typeString, equals("var"));
        expect(sourceAnalysis.topLevelVariables[1].typeString, equals("List<int>"));
        expect(sourceAnalysis.topLevelVariables[2].typeString, equals("String"));
        expect(sourceAnalysis.topLevelVariables[3].typeString, equals("String"));
      });
      test("annotations & docs", () {
        expect(sourceAnalysis.topLevelVariables[0].docs, equals("docs"));
        expect(sourceAnalysis.topLevelVariables[1].docs, equals("docs"));
        expect(sourceAnalysis.topLevelVariables[2].docs, isEmpty);
        expect(sourceAnalysis.topLevelVariables[3].docs, isEmpty);
        expect(sourceAnalysis.topLevelVariables[0].metadata, isNotEmpty);
        expect(sourceAnalysis.topLevelVariables[0].metadata.length, equals(1));
        expect(sourceAnalysis.topLevelVariables[1].metadata, isNotEmpty);
        expect(sourceAnalysis.topLevelVariables[1].metadata.length, equals(2));
        expect(sourceAnalysis.topLevelVariables[2].metadata.single.name, equals("ClassUno"));
        expect(sourceAnalysis.topLevelVariables[3].metadata.single.name, equals("ClassUno"));
      });
    });
    group("Classes:", () {
      test("2 classes present", () {
        expect(sourceAnalysis.classes.length, equals(2));
      });
      test("fields", () {
        var c1 = sourceAnalysis.classes.singleWhere((c) => c.name == "ClassUno");
        var c2 = sourceAnalysis.classes.singleWhere((c) => c.name == "ClassDos");
        expect(c1.fields.keys, containsAll(["field1", "field2"]));
        expect(c2.fields.keys, contains("field1"));
        expect(c1.fields["field1"]!.type?.toString(), equals("int?"));
        expect(c1.fields["field2"]!.type?.toString(), equals("String"));
        expect(c1.fields["field1"]?.defaultValue, isNull);
        expect(c1.fields["field2"]!.defaultValue, equals("default2"));
        expect(c2.fields["field1"]!.type?.toString(), equals("List<String>"));
      });
      test("constructors", () {
        var c1 = sourceAnalysis.classes.singleWhere((c) => c.name == "ClassUno");
        var c2 = sourceAnalysis.classes.singleWhere((c) => c.name == "ClassDos");
        expect(c1.constructors.values, isEmpty);
        expect(c2.constructors.values.single.parameters?.required.first.name,
            equals("field1"));
        expect(
            c2.constructors.values.single.parameters?.required.first
                .isThisInitializer,
            isTrue);
        expect(
            c2.constructors.values.single.parameters?.required.first
                .defaultValue,
            isNull);
        expect(
            c2.constructors.values.single.parameters?.required.first.typeString,
            isNull);
        expect(c2.constructors.values.single.parameters?.required.last.name,
            equals("simple"));
        expect(
            c2.constructors.values.single.parameters?.required.last.typeString,
            equals("String"));
        expect(
            c2.constructors.values.single.parameters?.required.last
                .defaultValue,
            isNull);
        expect(c2.constructors.values.single.parameters?.named.single.name,
            equals("named"));
        expect(
            c2.constructors.values.single.parameters?.named.single.typeString,
            equals("List<int>"));
        expect(
            c2.constructors.values.single.parameters?.named.single.defaultValue,
            equals([2]));
      });
      test("methods", () {
        var c1 = sourceAnalysis.classes.singleWhere((c) => c.name == "ClassUno");
        var c2 = sourceAnalysis.classes.singleWhere((c) => c.name == "ClassDos");
        expect(c1.methods.values.first.name, equals("method1"));
        expect(c1.methods.values.first.parameters, isNotNull);
        expect(c1.methods.values.first.parameters!.all, isEmpty);
        expect(c2.methods.values.first.name, equals("method1"));
        expect(
            c2.methods.values.first.parameters?.positionalOptionals.first.name,
            equals("arg2"));
        expect(
            c2.methods.values.first.parameters?.positionalOptionals.first
                .defaultValue,
            isNull);
        expect(
            c2.methods.values.first.parameters?.positionalOptionals.first
                .typeString,
            isNull);
        expect(
            c2.methods.values.first.parameters?.positionalOptionals.last
                .typeString,
            equals("String"));
        expect(
            c2.methods.values.first.parameters?.positionalOptionals.last.name,
            equals("arg3"));
        expect(
            c2.methods.values.first.parameters?.positionalOptionals.last
                .defaultValue,
            equals("sorp"));
        expect(c2.methods.values.first.parameters?.required.first.typeString,
            equals("int"));
        expect(c2.methods.values.first.parameters?.required.first.name,
            equals("arg1"));
        expect(c2.methods.values.first.parameters?.required.first.defaultValue,
            isNull);
      });
    });
  });
}
