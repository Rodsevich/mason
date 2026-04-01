import 'dart:io';
import 'package:analysis_utils/analyzer_components.dart';
import 'package:analysis_utils/src/expression_handler.dart';
import 'package:analysis_utils/src/source_span.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/src/dart/ast/constant_evaluator.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:source_span/source_span.dart';

/// An analyzed Dart file/code
///
/// All what must be parsed with the analysis package should be done with this
class SourceAnalysis {
  /// Saves a cache that matches raw source code to SourceAnalysis
  static final Map<String, SourceAnalysis> _analysisCache = {};

  ///Saves a cache for naming the fictional paths of raw provided code
  static int _pathsCacheIndex = 1;

  /// The path in a String manner
  late String path;

  /// The analysis of the AST Structure of the source
  late CompilationUnit compilationUnit;

  String? _code;

  List<ClassAnalysis>? _classes;
  List<EnumAnalysis>? _enums;
  List<MixinAnalysis>? _mixins;
  List<TopLevelVarAnalysis>? _topLevelVariables;
  List<DirectiveAnalysis>? _directives;

  /// The code of the file
  String get code {
    if (_code == null) {
      File file = File(path);
      _code = file.readAsStringSync();
    }
    return _code!;
  }

  /// Entrypoint for static code. You can use it to analyze the declarations (TopLevelVariables
  /// and Classes) of the dart code provided in `contents`
  factory SourceAnalysis.forContents(String contents) {
    if (_analysisCache.containsKey(contents)) {
      return _analysisCache[contents]!;
    } else {
      final SourceAnalysis ret = SourceAnalysis._forContents(contents);
      _analysisCache[contents] = ret;
      return ret;
    }
  }

  factory SourceAnalysis.forFilePath(String path) {
    if (_analysisCache.containsKey(path)) {
      return _analysisCache[path]!;
    } else {
      final SourceAnalysis ret = SourceAnalysis._(path);
      _analysisCache[path] = ret;
      return ret;
    }
  }

  SourceAnalysis._(this.path) {
    if (path.endsWith(".dart")) {
      this.compilationUnit = getCompilationUnitForPath(path);
    } else {
      throw Exception("You can only parse .dart files");
    }
  }

  SourceAnalysis._forContents(String contents) {
    this._code = contents;
    this.path = "path${_pathsCacheIndex++}.dart";
    this.compilationUnit = getCompilationUnitForSource(contents);
  }

  List<DirectiveAnalysis> get directives {
    if (_directives != null) {
      return _directives!;
    } else {
      _directives = [];
      for (var d in compilationUnit.directives) {
        final directive = (d is ImportDirective)
            ? ImportDirectiveAnalysis(d, this)
            : (d is ExportDirective)
                ? ExportDirectiveAnalysis(d, this)
                : (d is LibraryDirective)
                    ? LibraryDirectiveAnalysis(d, this)
                    : (d is PartDirective)
                        ? PartDirectiveAnalysis(d, this)
                        : (d is PartOfDirective)
                            ? PartOfDirectiveAnalysis(d, this)
                            : throw UnsupportedError(
                                "What the heck is a ${d.runtimeType} directive??");
        _directives!.add(directive as DirectiveAnalysis);
      }
      return _directives!;
    }
  }

  LibraryDirectiveAnalysis? get library {
    try {
      return directives.whereType<LibraryDirectiveAnalysis>().single;
    } catch (_) {
      return null;
    }
  }

  List<ImportDirectiveAnalysis> get imports =>
      directives.whereType<ImportDirectiveAnalysis>().toList();
  List<ExportDirectiveAnalysis> get exports =>
      directives.whereType<ExportDirectiveAnalysis>().toList();
  List<PartOfDirectiveAnalysis> get partsOf =>
      directives.whereType<PartOfDirectiveAnalysis>().toList();
  List<PartDirectiveAnalysis> get parts =>
      directives.whereType<PartDirectiveAnalysis>().toList();

  List<ClassAnalysis> get classes {
    if (_classes != null) {
      return _classes!;
    } else {
      _classes = [];
      for (var declaration in compilationUnit.declarations) {
        if (declaration is ClassDeclaration) {
          _classes!.add(ClassAnalysis.fromAnalysis(declaration, source: this));
        }
      }
      return _classes!;
    }
  }

  List<MixinAnalysis> get mixins {
    if (_mixins != null) {
      return _mixins!;
    } else {
      _mixins = [];
      for (var declaration in compilationUnit.declarations) {
        if (declaration is MixinDeclaration) {
          _mixins!.add(MixinAnalysis.fromAnalysis(declaration, source: this));
        }
      }
      return _mixins!;
    }
  }

  List<TopLevelVarAnalysis> get topLevelVariables {
    if (_topLevelVariables != null) {
      return _topLevelVariables!;
    } else {
      _topLevelVariables = [];
      for (var declaration in compilationUnit.declarations) {
        if (declaration is TopLevelVariableDeclaration) {
          for (var v in declaration.variables.variables) {
            _topLevelVariables!.add(TopLevelVarAnalysis.fromAnalysis(declaration, v, this));
          }
        }
      }
      return _topLevelVariables!;
    }
  }

  List<EnumAnalysis> get enums {
    if (_enums != null) {
      return _enums!;
    } else {
      _enums = [];
      for (var declaration in compilationUnit.declarations) {
        if (declaration is EnumDeclaration) {
          _enums!.add(EnumAnalysis.fromAnalysis(declaration, sourceAnalysis: this));
        }
      }
      return _enums!;
    }
  }

  Map toMap() => {
        "classes": this.classes.map((c) => c.toMap()).toList(),
        "topLevelVariables":
            this.topLevelVariables.map((c) => c.toMap()).toList(),
        "directives": {
          "library": this.library?.toString() ?? "",
          "imports": this.imports.map((d) => d.toString()).toList(),
          "exports": this.exports.map((d) => d.toString()).toList(),
          "parts": this.parts.map((d) => d.toString()).toList(),
          "partsof": this.partsOf.map((d) => d.toString()).toList()
        }
      };
}

/// base class used for traversing Analysis nodes in order to find the needed
/// ones (allocated in `found`)
abstract class Finder<D> extends SimpleAstVisitor {
  final String name;
  D? found;
  Finder(this.name);
}

class ParameterFinder extends Finder<FormalParameterList> {
  ParameterFinder(String name) : super(name);

  @override
  void visitFormalParameterList(FormalParameterList node) {
    if (found != null) throw Exception("There can't be 2 parametersList, WTF?");
    this.found = node;
  }
}

class ClassFinder extends Finder<ClassDeclaration> {
  ClassFinder(String name) : super(name);

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    if (node.name.toString() == name) {
      this.found = node;
    }
    return super.visitClassDeclaration(node);
  }
}

class FieldFinder extends Finder<FieldDeclaration> {
  FieldFinder(String name) : super(name);
  @override
  void visitFieldDeclaration(FieldDeclaration node) {
    if (node.fields.variables
        .any((VariableDeclaration v) => v.name.toString() == name)) {
      this.found = node;
    }
    return super.visitFieldDeclaration(node);
  }
}

class ConstructorFinder extends Finder<ConstructorDeclaration> {
  ConstructorFinder(String name)
      : super(name.startsWith(".") ? name.substring(1) : name);
  @override
  void visitConstructorDeclaration(ConstructorDeclaration node) {
    if ((node.name?.toString() ?? "") == name) {
      this.found = node;
    }
    return super.visitConstructorDeclaration(node);
  }
}

class MethodFinder extends Finder<MethodDeclaration> {
  MethodFinder(String name) : super(name);
  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    if (node.name.toString() == name) this.found = node;
    return super.visitMethodDeclaration(node);
  }
}

class TopLevelVariableFinder extends Finder<TopLevelVariableDeclaration> {
  TopLevelVariableFinder(String name) : super(name);
  @override
  void visitTopLevelVariableDeclaration(TopLevelVariableDeclaration node) {
    if (node.variables.variables
        .any((VariableDeclaration d) => d.name.value().toString() == this.name)) {
      this.found = node;
      return super.visitTopLevelVariableDeclaration(node);
    }
  }
}

abstract class EntityAnalysis<A extends AstNode, F extends Finder> {
  late String name;
  String docs = '';
  late SourceSpan location;
  List<MetadataAnalysis> metadata = [];
  SourceAnalysis source;
  A analyzerDeclaration;

  List<MetadataAnalysis> _computeMetadata() {
    NodeList<Annotation> annotations =
        (analyzerDeclaration as AnnotatedNode).metadata;
    List<MetadataAnalysis> ret = [];
    for (int i = 0; i < annotations.length; i++) {
      Annotation a = annotations[i];
      ret.add(MetadataAnalysis.fromAnalysis(a));
    }
    return ret;
  }

  EntityAnalysis.fromAnalysis(this.analyzerDeclaration, this.source) {
    _computeAnalysis();
    this.location = computeLocationFromNode(this.analyzerDeclaration, source);
  }

  @override
  String toString() => name;

  void _computeAnalysis() {
    if (analyzerDeclaration is AnnotatedNode) {
      this.docs = _computeDocs(analyzerDeclaration as AnnotatedNode);
      this.metadata = _computeMetadata();
    }
  }

  String _computeDocs(AnnotatedNode declaration) {
    List<Token> tokens = declaration.documentationComment?.tokens ?? [];
    if (tokens.isEmpty) return "";
    if (tokens.length == 1) {
      String doc = tokens.first.toString();
      if (doc.startsWith("/**")) {
        return _computeComplexDocsComment(doc);
      } else if (doc.startsWith("///")) {
        return _computeNormalDocsComment(tokens);
      } else {
        throw UnsupportedError(
            "Don't know what to do here. Please make me an issue in analysis_utils package showing the documentation of '$name' entity");
      }
    } else {
      return _computeNormalDocsComment(tokens);
    }
  }

  String _computeComplexDocsComment(String docLine) {
    RegExp formatter = RegExp("\n[ *]*");
    return docLine
        .substring(3, docLine.length - 3) //removes the /** and */
        .replaceAll(formatter, " ")
        .trim();
  }

  String _computeNormalDocsComment(List<Token> tokens) {
    return tokens
        .map((Token t) => t.toString().substring(3).trim())
        .join(" ")
        .trim();
  }
}

class MetadataAnalysis {
  late String name;
  Annotation node;
  ArgumentsResolution? arguments;

  MetadataAnalysis.fromAnalysis(this.node) {
    _processGenerics();
  }

  void _processGenerics() {
    this.name = node.name.name;
    if (node.arguments != null) {
      this.arguments = ArgumentsResolution.fromArgumentList(node.arguments!);
    }
  }

  Map toMap() => {
        "name": this.name,
        "arguments": this.arguments?.all,
        "toString": this.toString()
      };

  @override
  String toString() => node.toString();
}

abstract class DirectiveAnalysis<T extends Directive> {
  final T directive;
  late SourceSpan location;
  DirectiveAnalysis(this.directive, SourceAnalysis source) {
    this.location = computeLocationFromNode(directive, source);
  }

  @override
  String toString() => this.directive.toString();
}

abstract class UriBasedDirectiveAnalysis<T extends UriBasedDirective>
    extends DirectiveAnalysis<T> {
  late String? uri;
  UriBasedDirectiveAnalysis(T directive, SourceAnalysis source)
      : super(directive, source) {
    this.uri = directive.uri.stringValue;
  }
}

abstract class NamespaceBasedDirectiveAnalysis<T extends NamespaceDirective>
    extends UriBasedDirectiveAnalysis<T> {
  List<String> shows = [], hides = [];
  NamespaceBasedDirectiveAnalysis(T directive, SourceAnalysis source)
      : super(directive, source) {
    for (var c in directive.combinators) {
      if (c is HideCombinator) {
        for (var h in c.hiddenNames) {
          hides.add(h.name);
        }
      } else if (c is ShowCombinator) {
        for (var s in c.shownNames) {
          shows.add(s.name);
        }
      }
    }
  }
}

abstract class LibraryBasedDirectiveAnalysis<T extends Directive>
    extends DirectiveAnalysis<T> {
  final LibraryIdentifier? libraryIdentifier;
  LibraryBasedDirectiveAnalysis(
      T directive, SourceAnalysis source, this.libraryIdentifier)
      : super(directive, source);
  String? get name => this.libraryIdentifier?.name;
}

class ExportDirectiveAnalysis
    extends NamespaceBasedDirectiveAnalysis<ExportDirective> {
  ExportDirectiveAnalysis(ExportDirective directive, SourceAnalysis source)
      : super(directive, source);
}

class ImportDirectiveAnalysis
    extends NamespaceBasedDirectiveAnalysis<ImportDirective> {
  late String prefix;
  ImportDirectiveAnalysis(ImportDirective directive, SourceAnalysis source)
      : super(directive, source) {
    this.prefix = directive.prefix?.name ?? "";
  }
}

class PartDirectiveAnalysis extends UriBasedDirectiveAnalysis<PartDirective> {
  PartDirectiveAnalysis(PartDirective directive, SourceAnalysis source)
      : super(directive, source);
}

class PartOfDirectiveAnalysis
    extends LibraryBasedDirectiveAnalysis<PartOfDirective> {
  PartOfDirectiveAnalysis(PartOfDirective directive, SourceAnalysis source)
      : super(directive, source, directive.libraryName);
}

class LibraryDirectiveAnalysis
    extends LibraryBasedDirectiveAnalysis<LibraryDirective> {
  LibraryDirectiveAnalysis(LibraryDirective directive, SourceAnalysis source)
      : super(directive, source, directive.name2);
}

class TopLevelVarAnalysis extends EntityAnalysis<TopLevelVariableDeclaration,
    TopLevelVariableFinder> {
  dynamic defaultValue;
  String? typeString;
  VariableDeclaration variableDeclaration;
  TypeAnnotation? typeAnalysis;

  TopLevelVarAnalysis.fromAnalysis(TopLevelVariableDeclaration topLevelVariable,
      this.variableDeclaration, SourceAnalysis source)
      : super.fromAnalysis(topLevelVariable, source) {
    this.name = variableDeclaration.name.value().toString();
    this.defaultValue =
        variableDeclaration.initializer?.accept(ConstantEvaluator());
    this.typeAnalysis = topLevelVariable.variables.type;
    if (typeAnalysis != null) {
      this.typeString = typeAnalysis?.type
              ?.getDisplayString(withNullability: false) ??
          (typeAnalysis.toString().isEmpty ? "var" : typeAnalysis.toString());
      if (typeAnalysis is NamedType &&
          (typeAnalysis as NamedType).typeArguments != null &&
          !typeString!.contains("<")) {
        this.typeString =
            "$typeString<${(typeAnalysis as NamedType).typeArguments?.arguments.join(",")}>";
      }
    } else {
      this.typeString = "var";
    }
  }

  Map toMap() => {
        "name": this.name,
        "docs": this.docs.isEmpty ? "" : "///$docs",
        "type": this.typeString,
        "typeString": this.typeString,
        "defaultValue": this.defaultValue,
        "metadata": this.metadata.map((m) => m.toMap()).toList(),
        "toString": this.toString()
      };

  @override
  String toString() => analyzerDeclaration.toString();
}

class MixinAnalysis {
  MixinDeclaration declaration;
  late SourceSpan location;

  MixinAnalysis.fromAnalysis(this.declaration,
      {required SourceAnalysis source}) {
    this.location = computeLocationFromNode(declaration, source);
  }

  String get name => declaration.name.value().toString();
}

class EnumAnalysis {
  EnumDeclaration declaration;
  late SourceSpan location;

  EnumAnalysis.fromAnalysis(this.declaration,
      {required SourceAnalysis sourceAnalysis}) {
    this.location = computeLocationFromNode(declaration, sourceAnalysis);
  }

  String get name => declaration.name.value().toString();
  List<String> get simpleConstants =>
      declaration.constants.map((c) => c.name.value().toString()).toList();
}

class ClassAnalysis extends EntityAnalysis<ClassDeclaration, ClassFinder> {
  ClassAnalysis? superclassAnalysis;
  String? superclassName;
  Map<String, FieldAnalysis> fields = {};
  Map<String, MethodAnalysis> methods = {};
  Map<String, ConstructorAnalysis> constructors = {};

  ClassAnalysis.fromAnalysis(ClassDeclaration classDeclaration,
      {required SourceAnalysis source})
      : super.fromAnalysis(classDeclaration, source) {
    this.name = classDeclaration.name.value().toString();
    this.superclassName =
        classDeclaration.extendsClause?.superclass.name2.value().toString();
    for (var member in classDeclaration.members) {
      if (member is FieldDeclaration) {
        for (var declaration in member.fields.variables) {
          FieldAnalysis field =
              FieldAnalysis.fromAnalysis(this, member, declaration);
          this.fields[field.name] = field;
        }
      } else if (member is ConstructorDeclaration) {
        ConstructorAnalysis analysis =
            ConstructorAnalysis.fromAnalysis(this, member);
        this.constructors[analysis.name] = analysis;
      } else if (member is MethodDeclaration) {
        MethodAnalysis analysis = MethodAnalysis.fromAnalysis(this, member);
        this.methods[analysis.name] = analysis;
      }
    }
  }

  String? get extend =>
      superclassAnalysis?.name ??
      analyzerDeclaration.extendsClause?.superclass.name2.value().toString();

  List<String> get interfaces =>
      analyzerDeclaration.implementsClause?.interfaces
          .map<String>((i) => i.name2.value().toString())
          .toList() ??
      [];

  List<String> get mixins =>
      analyzerDeclaration.withClause?.mixinTypes
          .map<String>((m) => m.name2.value().toString())
          .toList() ??
      [];

  Map<String, MethodAnalysis> get regularMethods =>
      Map.fromEntries(methods.entries.where((m) =>
          (m.value.analyzerDeclaration.isSetter ||
              m.value.analyzerDeclaration.isGetter) ==
          false));

  Map<String, MethodAnalysis> get getters => Map.fromEntries(
      methods.entries.where((m) => m.value.analyzerDeclaration.isGetter));

  Map<String, MethodAnalysis> get setters => Map.fromEntries(
      methods.entries.where((m) => m.value.analyzerDeclaration.isSetter));

  Map<String, MethodAnalysis> get staticMethods => Map.fromEntries(
      methods.entries.where((m) => m.value.analyzerDeclaration.isStatic));

  Map toMap() => {
        "name": this.name,
        "docs": this.docs.isEmpty ? "" : "///$docs",
        "metadata": this.metadata.map((m) => m.toMap()).toList(),
        "fields": this.fields.values.map((v) => v.toMap()).toList(),
        "getters": this.getters.values.map((v) => v.toMap()).toList(),
        "setters": this.setters.values.map((v) => v.toMap()).toList(),
        "methods": this.regularMethods.values.map((v) => v.toMap()).toList(),
        "constructors": this.constructors.values.map((v) => v.toMap()).toList(),
      };
}

class ClassMemberAnalysis<D extends ClassMember, F extends Finder>
    extends EntityAnalysis<D, F> {
  ClassAnalysis container;

  ClassMemberAnalysis.fromAnalysis(
      D declaration, this.container, SourceAnalysis sourceAnalysis)
      : super.fromAnalysis(declaration, sourceAnalysis);
}

class FieldAnalysis extends ClassMemberAnalysis<FieldDeclaration, FieldFinder> {
  TypeAnalysis? type;
  VariableDeclaration variableDeclaration;

  bool get isFinal => this.variableDeclaration.isFinal;
  bool get isConst => this.variableDeclaration.isConst;
  bool get isPrivate => this.name.startsWith("_");

  FieldAnalysis.fromAnalysis(ClassAnalysis container,
      FieldDeclaration fieldDeclaration, this.variableDeclaration)
      : super.fromAnalysis(fieldDeclaration, container, container.source) {
    this.name = variableDeclaration.name.value().toString();
    if (analyzerDeclaration.fields.type != null) {
      this.type = TypeAnalysis.fromAnalyzer(analyzerDeclaration.fields.type!);
    }
  }

  dynamic get defaultValue {
    return variableDeclaration.initializer?.accept(DefaultValueVisitor());
  }

  Map toMap() => {
        "name": this.name,
        "docs": this.docs.isEmpty ? "" : "///$docs",
        "defaultValue": this.defaultValue,
        "hasDefaultValue": this.defaultValue != null,
        "type": this.type?.toMap(),
        "typeString": this.type.toString(),
        "toString": this.toString()
      };

  @override
  String toString() => analyzerDeclaration.toString();
}

class DefaultValueVisitor extends ConstantEvaluator {
  @override
  String visitPrefixedIdentifier(PrefixedIdentifier node) {
    return node.prefix.name + "." + node.identifier.name;
  }
}

class TypeAnalysis {
  late String name;
  List<String> arguments = [];
  TypeAnnotation analyzerDeclaration;

  TypeAnalysis.fromAnalyzer(this.analyzerDeclaration) {
    if (analyzerDeclaration is NamedType) {
      this.name = (analyzerDeclaration as NamedType).name2.value().toString();
      this.arguments = (analyzerDeclaration as NamedType)
              .typeArguments
              ?.arguments
              .map<String>((a) => (a as NamedType).name2.value().toString())
              .toList() ??
          [];
    } else if (analyzerDeclaration is GenericFunctionType) {
      this.name = (analyzerDeclaration as GenericFunctionType)
              .returnType
              ?.type
              ?.getDisplayString(withNullability: true) ??
          "dynamic";
      this.arguments =
          ((analyzerDeclaration as GenericFunctionType).returnType as NamedType?)
                  ?.typeArguments
                  ?.arguments
                  .map((a) => (a as NamedType).name2.value().toString())
                  .toList() ??
              [];
    }
  }

  Map toMap() {
    Map ret = {"name": this.name, "toString": toString()};
    for (int i = 0; i < 4; i++) {
      ret["argument$i"] = (i < arguments.length) ? arguments[i] : "dynamic";
    }
    return ret;
  }

  @override
  String toString() => analyzerDeclaration.toString();
}

class ConstructorAnalysis
    extends ClassMemberAnalysis<ConstructorDeclaration, ConstructorFinder>
    with ParametersInterface {

  ConstructorAnalysis.fromAnalysis(
      ClassAnalysis classAnalysis, ConstructorDeclaration declaration)
      : super.fromAnalysis(declaration, classAnalysis, classAnalysis.source) {
    this.name = declaration.name?.value().toString() ?? "";
    if (analyzerDeclaration.parameters.parameters.isNotEmpty) {
      this.parameters =
          ParametersAnalysis.fromAnalysis(this, declaration.parameters);
    }
  }

  bool get isConst => analyzerDeclaration.constKeyword != null;
  bool get isExternal => analyzerDeclaration.externalKeyword != null;
  bool get isFactory => analyzerDeclaration.factoryKeyword != null;

  Map toMap() => {
        "name": this.name,
        "docs": this.docs.isEmpty ? "" : "///$docs",
        "parameters": this.parameters?.all.map((p) => p.toMap()).toList() ?? [],
        "metadata": this.metadata.map((m) => m.toMap()).toList(),
        "toString": this.toString()
      };

  @override
  String toString() => analyzerDeclaration.toString();
}

class MethodAnalysis
    extends ClassMemberAnalysis<MethodDeclaration, MethodFinder>
    with ParametersInterface {
  TypeAnalysis? returnType;

  MethodAnalysis.fromAnalysis(
      ClassAnalysis classAnalysis, MethodDeclaration member)
      : super.fromAnalysis(member, classAnalysis, classAnalysis.source) {
    this.name = member.name.value().toString();
    if (member.parameters != null) {
      this.parameters =
          ParametersAnalysis.fromAnalysis(this, member.parameters!);
    }
    if (analyzerDeclaration.returnType != null) {
      this.returnType =
          TypeAnalysis.fromAnalyzer(analyzerDeclaration.returnType!);
    }
  }

  bool get isPrivate => this.name.startsWith("_");

  String get returnTypeString => returnType?.toString() ?? "dynamic";

  Map toMap() => {
        "name": this.name,
        "docs": this.docs.isEmpty ? "" : "///$docs",
        "metadata": this.metadata.map((m) => m.toMap()).toList(),
        "parameters": this.parameters?.all.map((p) => p.toMap()).toList() ?? [],
        "returnType": this.returnType?.toMap(),
        "returnTypeString": this.returnTypeString,
        "toString": this.toString()
      };

  @override
  String toString() => analyzerDeclaration.toString();
}

mixin ParametersInterface {
  ParametersAnalysis? parameters;

  Set<Parameter> get namedParameters => parameters?.named ?? {};
  List<Parameter> get requiredParameters => parameters?.ordinary ?? [];
  List<Parameter> get optionalParameters => parameters?.optionals ?? [];
  List<Parameter> get ordinaryParameters => parameters?.ordinary ?? [];
  List<Parameter> get positionalParameters => parameters?.positionals ?? [];
  List<Parameter> get positionalOptionalParameters =>
      parameters?.positionalOptionals ?? [];
}

class Parameter {
  dynamic defaultValue;
  String? typeString;
  late String name;
  FormalParameter node;

  Parameter.fromAnalysis(this.node) {
    this.name = node.name?.value().toString() ?? "";
    if (node is DefaultFormalParameter) {
      this.defaultValue = (node as DefaultFormalParameter)
          .defaultValue
          ?.accept(ConstantEvaluator());
      if (defaultValue == NOT_A_CONSTANT) {
        this.defaultValue = null;
      }
      this.node = (node as DefaultFormalParameter).parameter;
    }
    if (node is SimpleFormalParameter) {
      this.typeString = (node as SimpleFormalParameter).type?.toString();
    } else if (node is FieldFormalParameter) {
      this.typeString = (node as FieldFormalParameter)
          .type
          ?.toString();
    } else {
      this.typeString = null;
    }
  }

  bool get isOptional => node.isOptional;
  bool get isNamed => node.isNamed;
  bool get isOrdinary => node.isRequired;
  bool get isPositionalOptional => node.isOptionalPositional;
  bool get isRequired =>
      node.isRequired || node.metadata.any((m) => m.name.name == "required");
  bool get isThisInitializer => node is FieldFormalParameter;

  String get docs {
    if (node is NormalFormalParameter) {
      return (node as NormalFormalParameter).documentationComment?.toString() ?? "";
    }
    return "";
  }

  List<Annotation> get metadata => node.metadata.toList();

  Map toMap() => {
        "name": this.name,
        "docs": this.docs.isEmpty ? "" : "///$docs",
        "type": this.typeString,
        "metadata": this.metadata.map((m) => m.toString()).toList(),
        "toString": this.toString()
      };

  @override
  String toString() => node.toString();
}

class ParametersAnalysis
    extends EntityAnalysis<FormalParameterList, ParameterFinder> {
  ClassMemberAnalysis container;
  List<Parameter> _parameters = [];

  ParametersAnalysis.fromAnalysis(
      this.container, FormalParameterList parameters)
      : super.fromAnalysis(parameters, container.source) {
    this.name = "parameters";
    for (var param in parameters.parameters) {
      this._parameters.add(Parameter.fromAnalysis(param));
    }
  }

  List<Parameter> get all => _parameters;
  List<Parameter> get required =>
      _parameters.where((p) => p.isOrdinary).toList();
  List<Parameter> get optionals =>
      _parameters.where((p) => p.isOptional).toList();
  Set<Parameter> get named => _parameters.where((p) => p.isNamed).toSet();
  List<Parameter> get ordinary =>
      _parameters.where((p) => p.isOrdinary).toList();
  List<Parameter> get positionals =>
      _parameters.where((p) => p.isOrdinary || p.isPositionalOptional).toList();
  List<Parameter> get positionalOptionals =>
      _parameters.where((p) => p.isPositionalOptional).toList();

  int get length => _parameters.length;

  Parameter? operator [](String name) {
    try {
      return _parameters.singleWhere((Parameter p) => p.name == name);
    } catch (_) {
      return null;
    }
  }
}
