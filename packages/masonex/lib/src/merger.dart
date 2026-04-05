import 'dart:convert';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:collection/collection.dart';
import 'package:masonex/src/yaml_encode.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

/// {@template merger}
/// A class which helps merge two files.
/// {@endtemplate}
abstract class Merger {
  /// Merges the [newContent] with the [existingContent].
  List<int> merge(List<int> existingContent, List<int> newContent);

  /// Returns a [Merger] based on the [path].
  static Merger fromPath(String path) {
    final extension = p.extension(path).toLowerCase();
    switch (extension) {
      case '.dart':
        return DartRecursiveMerger();
      case '.json':
        return JsonMerger();
      case '.yaml':
      case '.yml':
        return YamlMerger();
      default:
        return AppendMerger();
    }
  }
}

/// {@template append_merger}
/// A [Merger] which appends the new content to the existing content.
/// {@endtemplate}
class AppendMerger extends Merger {
  @override
  List<int> merge(List<int> existingContent, List<int> newContent) {
    return [...existingContent, ...newContent];
  }
}

/// {@template json_merger}
/// A [Merger] which merges two JSON files.
/// {@endtemplate}
class JsonMerger extends Merger {
  @override
  List<int> merge(List<int> existingContent, List<int> newContent) {
    final existingSource = utf8.decode(existingContent);
    final existingJson = existingSource.isEmpty
        ? <String, dynamic>{}
        : json.decode(existingSource);
    final newJson = json.decode(utf8.decode(newContent));

    final mergedJson = _merge(existingJson, newJson);
    return utf8.encode(json.encode(mergedJson));
  }

  dynamic _merge(dynamic existing, dynamic incoming) {
    if (existing is Map && incoming is Map) {
      final merged = Map<String, dynamic>.from(existing);
      for (final entry in incoming.entries) {
        final key = entry.key;
        final value = entry.value;
        merged[key.toString()] = _merge(existing[key], value);
      }
      return merged;
    }
    if (existing is List && incoming is List) {
      return [...existing, ...incoming];
    }
    return incoming;
  }
}

/// {@template yaml_merger}
/// A [Merger] which merges two YAML files using [YamlEditor]
/// to preserve formatting.
/// {@endtemplate}
class YamlMerger extends Merger {
  @override
  List<int> merge(List<int> existingContent, List<int> newContent) {
    final existingSource = utf8.decode(existingContent);
    final newSource = utf8.decode(newContent);

    if (existingSource.isEmpty) {
      return newContent;
    }

    try {
      final sourceYaml = loadYaml(newSource);
      if (sourceYaml is! YamlMap) {
        // If not a map, fallback to simple merge or overwrite
        return newContent;
      }

      final editor = YamlEditor(existingSource);
      _deepMerge(editor, sourceYaml, []);
      return utf8.encode(editor.toString());
    } catch (_) {
      // Fallback to simple merge if YamlEditor fails
      final existingYaml = loadYaml(existingSource);
      final newYaml = loadYaml(newSource);
      final mergedYaml = _merge(existingYaml, newYaml);

      if (mergedYaml is Map) {
        return utf8.encode(
          MasonexYamlEncoder.encode(mergedYaml.cast<dynamic, dynamic>()),
        );
      }
      return newContent;
    }
  }

  void _deepMerge(YamlEditor editor, YamlMap sourceMap, List<Object> path) {
    for (final key in sourceMap.nodes.keys) {
      final valueNode = sourceMap.nodes[key];
      final keyString = (key as YamlScalar).value as Object;
      final currentPath = [...path, keyString];

      if (valueNode is YamlMap) {
        try {
          final existing = _getNestedValue(editor, currentPath);
          if (existing is YamlMap) {
            _deepMerge(editor, valueNode, currentPath);
            continue;
          }
        } catch (_) {
          // Key doesn't exist, will be updated below
        }
      }

      editor.update(currentPath, _toYamlNode(valueNode));
    }
  }

  dynamic _getNestedValue(YamlEditor editor, List<Object> path) {
    dynamic current = loadYaml(editor.toString());
    for (final key in path) {
      if (current is YamlMap && current.containsKey(key)) {
        current = current.nodes[key];
      } else if (current is Map && current.containsKey(key)) {
        current = current[key];
      } else {
        throw StateError('Key $key not found');
      }
    }
    return current;
  }

  YamlNode _toYamlNode(dynamic value) {
    if (value is YamlScalar) {
      var v = value.value;
      var style = value.style;

      if (v is String && style == ScalarStyle.LITERAL) {
        if (v.endsWith('\n')) {
          v = v.replaceAll(RegExp(r'\n+$'), '');
        }
      } else if (v is String && v.contains('\n') && style == ScalarStyle.ANY) {
        style = ScalarStyle.LITERAL;
        if (v.endsWith('\n')) {
          v = v.replaceAll(RegExp(r'\n+$'), '');
        }
      }
      return wrapAsYamlNode(v, scalarStyle: style);
    }
    if (value is String && value.contains('\n')) {
      var v = value.endsWith('\n')
          ? value.replaceAll(RegExp(r'\n+$'), '')
          : value;
      return wrapAsYamlNode(v, scalarStyle: ScalarStyle.LITERAL);
    }
    if (value is YamlMap) {
      final map = {
        for (final k in value.nodes.keys)
          (k as YamlScalar).value: _toYamlNode(value.nodes[k]),
      };
      final style = value.style != CollectionStyle.ANY
          ? value.style
          : CollectionStyle.BLOCK;
      return wrapAsYamlNode(map, collectionStyle: style);
    }
    if (value is YamlList) {
      final list = value.nodes.map(_toYamlNode).toList();
      final style = value.style != CollectionStyle.ANY
          ? value.style
          : CollectionStyle.BLOCK;
      return wrapAsYamlNode(list, collectionStyle: style);
    }
    return wrapAsYamlNode(value);
  }

  dynamic _merge(dynamic existing, dynamic incoming) {
    if (existing is Map && incoming is Map) {
      final merged = Map<dynamic, dynamic>.from(existing);
      for (final entry in incoming.entries) {
        merged[entry.key] = _merge(existing[entry.key], entry.value);
      }
      return merged;
    }
    if (existing is List && incoming is List) {
      return [...existing, ...incoming];
    }
    return incoming;
  }
}

/// {@template dart_merger}
/// A [Merger] which merges two Dart files.
/// {@endtemplate}
abstract class DartMerger extends Merger {
  Map<String, CompilationUnitMember> _getTopLevelDeclarations(
    CompilationUnit unit,
  ) {
    final declarations = <String, CompilationUnitMember>{};
    for (final declaration in unit.declarations) {
      final names = _getDeclarationNames(declaration);
      for (final name in names) {
        declarations[name] = declaration;
      }
    }
    return declarations;
  }

  List<String> _getDeclarationNames(CompilationUnitMember declaration) {
    Token? nameToken;
    if (declaration is ClassDeclaration) {
      nameToken = declaration.name;
    } else if (declaration is FunctionDeclaration) {
      nameToken = declaration.name;
    } else if (declaration is EnumDeclaration) {
      nameToken = declaration.name;
    } else if (declaration is MixinDeclaration) {
      nameToken = declaration.name;
    } else if (declaration is ExtensionDeclaration) {
      nameToken = declaration.name;
    }

    if (nameToken != null) {
      return [nameToken.lexeme];
    }

    if (declaration is TopLevelVariableDeclaration) {
      return declaration.variables.variables.map((v) => v.name.lexeme).toList();
    }
    return [];
  }

  String? _getDeclarationName(CompilationUnitMember declaration) {
    return _getDeclarationNames(declaration).firstOrNull;
  }

  String? _mergeValues(
    VariableDeclaration existing,
    VariableDeclaration incoming,
  ) {
    final existingInit = existing.initializer;
    final incomingInit = incoming.initializer;

    if (existingInit is ListLiteral && incomingInit is ListLiteral) {
      final existingElements = existingInit.elements
          .map((e) => e.toSource())
          .toList();
      final incomingElements = incomingInit.elements
          .map((e) => e.toSource())
          .toList();
      final mergedElements = [...existingElements, ...incomingElements];
      return '${existing.name.lexeme} = [${mergedElements.join(', ')}]';
    }

    if (existingInit is SetOrMapLiteral && incomingInit is SetOrMapLiteral) {
      if (existingInit.isSet && incomingInit.isSet) {
        final existingElements = existingInit.elements
            .map((e) => e.toSource())
            .toSet();
        final incomingElements = incomingInit.elements
            .map((e) => e.toSource())
            .toSet();
        final mergedElements = {...existingElements, ...incomingElements};
        return '${existing.name.lexeme} = {${mergedElements.join(', ')}}';
      }
      if (!existingInit.isSet && !incomingInit.isSet) {
        final existingElements = {
          for (final e in existingInit.elements.whereType<MapLiteralEntry>())
            e.key.toSource(): e.value.toSource(),
        };
        final incomingElements = {
          for (final e in incomingInit.elements.whereType<MapLiteralEntry>())
            e.key.toSource(): e.value.toSource(),
        };
        final mergedElements = {...existingElements, ...incomingElements};
        final mergedSource = mergedElements.entries
            .map((e) => '${e.key}: ${e.value}')
            .join(', ');
        return '${existing.name.lexeme} = {$mergedSource}';
      }
    }

    throw Exception(
      'Cannot merge variables with name "${existing.name.lexeme}" because their types mismatch or are not supported for merging.',
    );
  }
}

/// {@template dart_recursive_merger}
/// A [Merger] which merges two Dart files recursively.
/// {@endtemplate}
class DartRecursiveMerger extends DartMerger {
  @override
  List<int> merge(List<int> existingContent, List<int> newContent) {
    final existingSource = utf8.decode(existingContent);
    final newSource = utf8.decode(newContent);

    final existingUnit = parseString(
      content: existingSource,
      throwIfDiagnostics: false,
    ).unit;
    final newUnit = parseString(
      content: newSource,
      throwIfDiagnostics: false,
    ).unit;

    final existingVariables = _getAllVariables(existingUnit);
    final existingDeclarations = _getTopLevelDeclarations(existingUnit);

    var mergedSource = existingSource;

    // Handle imports
    final brickImports = newUnit.directives.whereType<ImportDirective>();
    final targetImports = existingUnit.directives
        .whereType<ImportDirective>()
        .toList();
    for (final brickImport in brickImports) {
      final exists = targetImports.any(
        (targetImport) =>
            targetImport.uri.toSource() == brickImport.uri.toSource(),
      );
      if (!exists) {
        mergedSource = '${brickImport.toSource()}\n$mergedSource';
      }
    }

    final handledBrickDeclarations = <CompilationUnitMember>{};

    // First, handle top-level declarations that are not variables
    for (final declaration in newUnit.declarations) {
      if (declaration is! TopLevelVariableDeclaration) {
        final name = _getDeclarationName(declaration);
        if (name != null && !existingDeclarations.containsKey(name)) {
          mergedSource += '\n${declaration.toSource()}';
          handledBrickDeclarations.add(declaration);
        }
      }
    }

    // Then, handle variables
    final newVariables = _getAllVariables(newUnit);
    final newDeclarations = _getTopLevelDeclarations(newUnit);

    for (final entry in newVariables.entries) {
      final qualifiedName = entry.key;
      final newVariable = entry.value;

      if (existingVariables.containsKey(qualifiedName)) {
        final existingVariable = existingVariables[qualifiedName]!;
        final mergedValue = _mergeValues(existingVariable, newVariable);
        if (mergedValue != null) {
          final updatedUnit = parseString(content: mergedSource).unit;
          final currentVariables = _getAllVariables(updatedUnit);
          final currentVariable = currentVariables[qualifiedName]!;

          mergedSource = mergedSource.replaceRange(
            currentVariable.beginToken.offset,
            currentVariable.endToken.end,
            mergedValue,
          );
        }
      } else {
        final variableName = qualifiedName.contains('.')
            ? qualifiedName.split('.').last
            : qualifiedName;

        if (newDeclarations.containsKey(variableName)) {
          final declaration = newDeclarations[variableName]!;
          if (!handledBrickDeclarations.contains(declaration)) {
            mergedSource += '\n${declaration.toSource()}';
            handledBrickDeclarations.add(declaration);
          }
        }
      }
    }

    return utf8.encode(mergedSource);
  }

  Map<String, VariableDeclaration> _getAllVariables(CompilationUnit unit) {
    final visitor = _VariableVisitor();
    unit.accept(visitor);
    return visitor.variables;
  }
}

class _VariableVisitor extends RecursiveAstVisitor<void> {
  final variables = <String, VariableDeclaration>{};
  String? _currentClass;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final previousClass = _currentClass;
    _currentClass = node.name.lexeme;
    super.visitClassDeclaration(node);
    _currentClass = previousClass;
  }

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    final qualifiedName = _currentClass != null
        ? '$_currentClass.${node.name.lexeme}'
        : node.name.lexeme;
    if (!variables.containsKey(qualifiedName)) {
      variables[qualifiedName] = node;
    }
    super.visitVariableDeclaration(node);
  }
}
