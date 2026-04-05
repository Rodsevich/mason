import 'package:collection/collection.dart';
import 'package:mustachex/src/variable_recase_decomposer.dart';

import 'mustache_template/template_exception.dart';

class MissingPartialsResolverFunction implements Exception {
  @override
  String toString() => 'No partial resolver function provided';
}

class MissingPartialException implements Exception {
  String? partialName;
  final TemplateException? templateException;
  MissingPartialException({this.templateException, this.partialName}) {
    partialName ??= templateException!.message
        .substring(19, templateException!.message.length - 1);
  }

  @override
  String toString() => "Missing partial: Partial '$partialName' not found";
}

/// Indicates that the `request` value wasn't provided
/// Note that `request` is automatically decomposed from `varName`(_`recasing`)?
class MissingVariableException extends MustacheMissingException {
  @override
  VariableRecaseDecomposer? _d;
  @override
  List<String?>? _parentCollections;

  MissingVariableException(TemplateException e, Map? sourceVariables)
      : super(e.message.substring(36, e.message.length - 1), e,
            sourceVariables ?? {});

  @override
  String toString() => 'Should process {{${_d!.request}}} but lacks both '
      'the value for "${_d!.varName}" and the function to fulfill missing values.';
}

/// Indicates that the `request` value wasn't provided
class MissingSectionTagException extends MustacheMissingException {
  @override
  VariableRecaseDecomposer? _d;
  @override
  List<String?>? _parentCollections;

  MissingSectionTagException(TemplateException e, Map? sourceVariables)
      : super(e.message.substring(35, e.message.length - 1), e,
            sourceVariables ?? {});

  @override
  String toString() {
    var ret = 'Missing section tag "{{#$request}}"';
    if (parentCollections!.isEmpty) {
      ret += ', from $humanReadableVariable';
    }
    return ret;
  }
}

/// Indicates that the `request` value wasn't provided in a {{^foo}} tag
class MissingInverseSectionTagException extends MustacheMissingException {
  @override
  VariableRecaseDecomposer? _d;
  @override
  List<String?>? _parentCollections;

  MissingInverseSectionTagException(TemplateException e, Map? sourceVariables)
      : super(e.message.substring(39, e.message.length - 1), e,
            sourceVariables ?? {});

  @override
  String toString() {
    var ret = 'Missing inverse section tag "{{^$request}}"';
    if (parentCollections!.isEmpty) {
      ret += ', from $humanReadableVariable';
    }
    return ret;
  }
}

/// The parent class that does the computations
class MustacheMissingException {
  VariableRecaseDecomposer? _d;
  List<String?>? _parentCollections;

  MustacheMissingException(
      String missing, TemplateException e, Map sourceVariables) {
    _d = VariableRecaseDecomposer(missing);
    var sourceBefore = e.source!.substring(0, e.offset);
    //cambiar las variables si estás en un {{#mapa|lista}}
    _parentCollections = _processParentMaps(sourceBefore);
    if (_parentCollections!.isNotEmpty) {
      _parentCollections!.forEach((pc) {
        if (sourceVariables[pc] is Map) {
          sourceVariables = sourceVariables[pc];
        } else if (sourceVariables[pc] is List) {
          sourceVariables = sourceVariables[pc].toMap();
        }
      });
      final val = sourceVariables[varName];
      if (val != null && val is Map) {
        var ret = val.entries.firstWhereOrNull((e) => e.value == null);
        if (ret != null) {
          _parentCollections!.add(ret.key.toString());
        }
      }
    }

    // this._parentCollections = _processParentMaps(_d.varName, sourceVariables) ?? [];
  }

  /// The complete requested variable string, like varName_constantCase
  String get request => _d!.request;

  /// The variable part of the request, like varName
  String? get varName => _d!.varName;

  /// The eventual recasing part of the request, like camelCase
  String? get recasing => _d!.recasing;

  /// The maps that contains the missing value. For example, \[a,b\] means that
  /// the missing variable with `varName` 'missing' should be stored in
  /// variablesResolver\["a"\]\["b"\]\["missing"\]
  List<String?>? get parentCollections => _parentCollections;

  /// Same as `parentCollections` but with the varName added at the end
  List<String?> get parentCollectionsWithVarName {
    var vals = List<String?>.from(_parentCollections!);
    vals.add(_d!.varName);
    return vals;
  }

  /// for logging or informing the user which variable is missing beneath maps
  String get humanReadableVariable {
    var ret = parentCollectionsWithVarName.join("'],['");
    if (parentCollectionsWithVarName.length > 1) {
      ret = "['$ret']";
    }
    return ret;
  }

  /// Same as `parentCollections` but with the request added at the end
  List<String> get parentCollectionsWithRequest {
    var vals = List<String>.from(_parentCollections!);
    vals.add(_d!.request);
    return vals;
  }

  /// usado para escanear el código mustache por tokens que nombren a los maps
  final _beginToken = RegExp(r'{{ ?# ?(.*?)}}'),
      _endToken = RegExp(r'{{ ?\/ ?(.*?)}}');

  /// Escanea el código mustache y devuelve una lista con los maps que quedaron
  /// abiertos. Ej: {{#uno}} {{#dos}}{{/dos}} {{#tres}} devuelve [uno,tres]
  List<String?>? _processParentMaps(String source) {
    var open = _beginToken.allMatches(source).map((m) => m.group(1)).toList(),
        close = _endToken.allMatches(source).map((m) => m.group(1)).toList();
    var ret = open.where((e) => !close.remove(e)).toList();
    return ret;
  }
}

///A wrapper for a [MissingVariableException] that alerts in a friendly manner
///the specific error it represents
class MissingNestedVariableException {
  final MissingVariableException missingVariableException;

  MissingNestedVariableException(this.missingVariableException);

  @override
  String toString() => "Can't recase "
      "${missingVariableException.parentCollectionsWithRequest.join('->')} "
      "because there is no '${missingVariableException.varName}' value to "
      'recase. Maybe a typo?';
}
