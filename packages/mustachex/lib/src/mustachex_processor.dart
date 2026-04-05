import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart' show IterableExtension;
import 'package:mustache_recase/mustache_recase.dart' as mustache_recase;
import 'package:mustachex/mustache.dart';
import 'package:mustachex/src/variables_resolver.dart';
import 'package:quiver/collection.dart';
import 'package:recase/recase.dart';

import 'mustache_template/template_exception.dart';
import 'mustachex_exceptions.dart';

typedef FulfillmentFunction = FutureOr<String> Function(
    MissingVariableException variable);

typedef PartialResolverFunction = FutureOr<String>? Function(
    MissingPartialException missingPartial);

typedef _PartialsResolver = Template Function(String partialName);

class MustachexProcessor {
  FulfillmentFunction? missingVarFulfiller;
  PartialResolverFunction? partialsResolver;
  late VariablesResolver variablesResolver;

  /// Acá guardas una cache para hacer más eficiente las ejecuciones del
  /// processMustacheThrowingIfAbsent que se ejecuta con lo mismo varias veces
  final Map<String, Map> _sourceCache = {};

  MustachexProcessor(
      {Map? initialVariables,
      this.missingVarFulfiller,
      this.partialsResolver,
      VariablesResolver? variablesResolver})
      : variablesResolver =
            variablesResolver ?? VariablesResolver(initialVariables);

  @Deprecated(' Will be removed on version 2.0.0'
      'Use processBytes instead (maybe with String.fromList(await processBytes(source), encoding: utf8)).')
  Future<String> process(String source) async {
    return await _processMustacheThrowingIfAbsent(
        source, variablesResolver.getAll,
        partialsResolver: _partialsResolverAdapted);
  }

  /// Processes the template and returns raw bytes (List<int>).
  /// Binary values (Uint8List / List<int>) are written directly without
  /// string conversion. Text portions are UTF-8 encoded.
  Future<List<int>> processBytes(String source) async {
    return await _processMustacheThrowingIfAbsentBytes(
        source, variablesResolver.getAll,
        partialsResolver: _partialsResolverAdapted);
  }

  Template _partialsResolverAdapted(String name) {
    if (partialsResolver == null) {
      throw MissingPartialsResolverFunction();
    }
    //procesa el source del template o throwea si falta el partial
    var e = MissingPartialException(partialName: name);
    var templateSource = partialsResolver!(e) as String?;
    if (templateSource is! String) throw e;
    return Template(templateSource, partialResolver: _partialsResolverAdapted);
  }

  Map<String?, dynamic> _mustacheVars(String source) {
    var template = Template(source, partialResolver: _partialsResolverAdapted);
    return _gatherTemplateRequiredVars(template);
  }

  Map<String?, dynamic> _gatherTemplateRequiredVars(Template template,
      [Map<String, dynamic>? variables]) {
    Map<String?, dynamic> vars = variables ?? <String, dynamic>{};
    var nameRegExp = RegExp(r': (.*).$');
    while (true) {
      var error = _failing_gathering(template, vars);
      // , printMessage: true, printReturn: true);
      if (error == null) {
        return vars;
      } else if (error.message.startsWith('Partial not found')) {
        throw MissingPartialException(templateException: error);
      } else {
        var e = error.message;
        var nameStr = nameRegExp.firstMatch(e)!.group(1)!;
        var name = nameStr.split('|').first.trim();
        if (e.contains('for variable tag')) {
          if (name.contains('.')) {
            var parts = name.split('.');
            var current = vars;
            for (var i = 0; i < parts.length - 1; i++) {
              var p = parts[i];
              if (current[p] is! Map) current[p] = <String, dynamic>{};
              current = current[p];
            }
            current[parts.last] = '%ValueOf$nameStr%';
          } else {
            vars[name] = '%ValueOf$name%';
          }
        } else {
          //up to this version, if not a variable, only a Section is possible
          var inSectionSrc = RegExp('{{([#^])$name}}([\\s\\S]*?){{/$name}}');
          List<Match> matches = inSectionSrc.allMatches(error.source!).toList();
          for (var i = 0; i < matches.length; i++) {
            // ignore: unused_local_variable
            var type = matches[i].group(1);
            var contents = matches[i].group(2)!;
            var sectionSourceTemplate =
                Template(contents, partialResolver: _partialsResolverAdapted);
            // if (e.contains("for inverse section")) {
            // } else if (e.contains("for section")) {
            // if (type == '^') {
            //   //inverse section
            //   vars['^$name'] ??= {};
            //   vars['^$name']
            //       .addAll(_gatherTemplateRequiredVars(sectionSourceTemplate));
            // } else {
            vars[name] ??= {};
            vars[name]
                .addAll(_gatherTemplateRequiredVars(sectionSourceTemplate));
            // }
          }
        }
      }
    }
  }

  /// Processes a mustache formatted source with the given variables and throws
  /// [_MustacheMissingException] whenever any of them is missing
  Future<String> _processMustacheThrowingIfAbsent(
      String source, Map resolverVars,
      {_PartialsResolver? partialsResolver}) async {
    if (_sourceCache[source] == null) {
      _sourceCache[source] = {
        'template': Template(source,
            lenient: false,
            partialResolver: partialsResolver,
            htmlEscapeValues: false),
        'variables': _mustacheVars(source)
      };
    }
    Template template = _sourceCache[source]!['template'];
    Map variables = _sourceCache[source]!['variables'];
    var vars = Map.from(resolverVars);
    vars.addAll(mustache_recase.cases);
    Future<String> _tryRender() async {
      try {
        final updatedVars = Map.from(variablesResolver.getAll)
          ..addAll(mustache_recase.cases);
        return template.renderString(updatedVars);
      } on TemplateException catch (e) {
        // print(
        //     "There is a missing value for '${ex.humanReadableVariable}' mustache "
        //     'section tag. Trying to solve this...');
        Future<String> handleMissingSection(
            String variable, MustacheMissingException ex) {
          if (variable.startsWith('has')) {
            var recasedName = ReCase(variable.substring(3)).camelCase;
            var iterations = _getMustacheIterations(ex, recasedName);
            if (iterations.isNotEmpty) {
              var mapToReplace =
                  iterations.first.variablesResolverPosition.first;
              var assign =
                  _recursivelyProcessHasX(iterations, variable, recasedName);
              variablesResolver[mapToReplace] = assign;
              // print('Problem solved by setting all intances of '
              //     "the last submap with a '$variable' field saying wether "
              //     "the field '$recasedName' is set or not.");
            } else {
              var request = ex.parentCollections!;
              var storeLocation = List.from(request);
              request.add(recasedName);
              storeLocation.add(variable);
              var storedVar = variablesResolver.get(request);
              variablesResolver[storeLocation] =
                  _processHasXStoringValue(storedVar);
              // print('Problem solved by defining '
              //     "'$variable' to ${variablesResolver[storeLocation]}");
            }
            return _tryRender();
          } else {
            //No es del tipo hasXxxYyy. Le falta la lista directamente
            throw ex;
          }
        }

        if (e.message.contains('inverse section')) {
          //Primero nos fijamos si es una guarda tipo hasXxxYyyyyyZzzz
          var ex = MissingInverseSectionTagException(e, variables);
          var variable = ex.request;
          return handleMissingSection(variable, ex);
        } else if (e.message.contains('section tag')) {
          var ex = MissingSectionTagException(e, variables);
          var variable = ex.request;
          return handleMissingSection(variable, ex);
        } else if (e.message.contains('variable tag')) {
          var ex = MissingVariableException(e, variables);
          // print(
          //     "There is a missing value for '${ex.humanReadableVariable}' mustache "
          //     'variable. Trying to solve this...');
          //Primero nos fijamos si falta el valor o sólo hay que recasearlo
          dynamic preExistentVar;
          try {
            preExistentVar =
                variablesResolver.get(ex.parentCollectionsWithVarName);
          } on VarFromListRequestException catch (listException) {
            // //recasea cada item (si está) y vuelve a guardar con el cambio
            // List parent = variablesResolver[listException.parentCollections];
            // parent.forEach((items) {
            //   var variable = items[ex.varName];
            //   if (variable is StringVariable) {
            //     items[ex.request] = variable[ex.recasing];
            //   } else {
            //     throw UnsupportedError(
            //         'You are trying to recase a ${variable.runtimeType} type.\n'
            //         '"${ex.parentCollectionsWithRequest.join('.')}" should be a String instead.');
            //   }
            // });
            // variablesResolver[listException.parentCollections] = parent;
            // return _tryRender();
            //recasea cada item (si está) y vuelve a guardar con el cambio
            var iteration =
                _getPrimigenicMustacheIteration(ex, listException.request.last);
            var mapToReplace = iteration.variablesResolverPosition.first;
            var replacement = _recursivelyProcessRecasing(iteration, ex);
            if (listsEqual(variablesResolver[mapToReplace], replacement) &&
                jsonEncode(variablesResolver[mapToReplace]) ==
                    jsonEncode(replacement)) {
              throw ex;
            } else {
              variablesResolver[mapToReplace] = replacement;
              return _tryRender();
            }
          }
          if (preExistentVar != null) {
            // guardamos el valor recaseado
            variablesResolver[ex.parentCollectionsWithRequest] =
                variablesResolver.get(ex.parentCollectionsWithRequest);
            // print("Problem solved by recasing it to '$recasingAttempt'");
          } else {
            if (missingVarFulfiller == null) throw ex;
            var value = await missingVarFulfiller!(ex);
            variablesResolver[ex.parentCollectionsWithVarName] = value;
            // print("Problem solved by asking user ('$value' answered)");
          }
          return _tryRender();
        } else {
          throw UnsupportedError(
              "Don't know how to process this mustache exception: $e");
        }
      }
    }

    return _tryRender();
  }

  /// Binary version: resolves all variables via the string pipeline first,
  /// then renders the final result as raw bytes.
  Future<List<int>> _processMustacheThrowingIfAbsentBytes(
      String source, Map resolverVars,
      {_PartialsResolver? partialsResolver}) async {
    // First, resolve all missing variables via the normal string pipeline.
    // This handles hasX guards, recasing, and missing var fulfillment.
    await _processMustacheThrowingIfAbsent(source, resolverVars,
        partialsResolver: partialsResolver);

    // Now all variables are resolved. Render as bytes using BinaryRenderer.
    Template template = _sourceCache[source]!['template'];
    final updatedVars = Map.from(variablesResolver.getAll)
      ..addAll(mustache_recase.cases);
    return template.renderBytes(updatedVars);
  }

  _MustacheIteration _getPrimigenicMustacheIteration(
      MustacheMissingException e, String recasedName) {
    var collection = e.parentCollections!.first;
    var resolvedVar = variablesResolver[collection];
    return _MustacheIteration(resolvedVar.cast<Map>(), [collection!]);
    // if (resolvedVar is List) {
    //   if (resolvedVar.every((e) => e is Map)) {
    //     return _MustacheIteration(resolvedVar.cast<Map>(), [collection]);
    //   } else {
    //     _throwImpossibleState();
    //   }
    // }
  }

  /// procesa las _MustacheIterations que encuentra según la excepción
  List<_MustacheIteration> _getMustacheIterations(
      MustacheMissingException e, String recasedName) {
    var iterations = <_MustacheIteration>[];
    var request = <String>[];
    var elements = List<String>.from(e.parentCollections!);
    // elements.add(recasedName);
    var resolvedVar;
    for (var collection in elements) {
      request.add(collection);
      try {
        resolvedVar = variablesResolver[request];
      } on VarFromListRequestException {
        try {
          resolvedVar = iterations.last.iteration!
              .firstWhere((elem) => elem.containsKey(collection))[collection];
        } catch (e) {
          break;
        }
      }
      if (resolvedVar is List) {
        //No se para q estaba esto, pero no servía para
        // if (resolvedVar.isEmpty) {
        //   break;
        // } else
        if (resolvedVar.every((e) => e is Map)) {
          iterations.add(
              _MustacheIteration(resolvedVar.cast<Map>(), List.from(request)));
        } else {
          _throwImpossibleState();
        }
      }
    }
    return iterations;
  }
}

TemplateException? _failing_gathering(Template template, Map vars,
    {bool printMessage = false, bool printReturn = false}) {
  try {
    var variables = Map.from(vars);
    variables.addAll(mustache_recase.cases);
    var ret = template.renderString(variables);
    if (printReturn) print(ret);
    return null;
  } on TemplateException catch (e) {
    if (printMessage) print(e.message);
    return e;
  }
}

void _throwImpossibleState() {
  //Sí o sí tienen que ser listas de Maps
  throw StateError('Impossible state: This is a bug, please report it.');
}

/// Determines whether the hasStoredValue is true or false
bool _processHasXStoringValue(storedVar) {
  if (storedVar == null) {
    return false;
  } else if (storedVar is bool) {
    return true;
  } else if (storedVar is String) {
    return storedVar.isNotEmpty;
  } else if (storedVar is Iterable) {
    return storedVar.isNotEmpty;
  } else if (storedVar != null) {
    return true;
  } else {
    throw UnsupportedError(
        "Don't known what to do with a '${storedVar.runtimeType}' type."
        ' Should hasXXX return true or false?');
  }
}

/// Devuelve un map sacado de la primera iteración con todos sus elementos
/// procesados para devolver sus últimas instancias con el `hasName` correctamente
/// seteado según el estado de su item `name`
List<Map> _recursivelyProcessHasX(
    List<_MustacheIteration> iterations, String hasName, String name,
    [Map? submap]) {
  var mapIdentifier = iterations.first.variablesResolverPosition.last;
  if (iterations.length > 1) {
    var ret = List<Map>.from(
        submap == null ? iterations.first.iteration! : submap[mapIdentifier]);
    for (var i = 0; i < ret.length; i++) {
      var processedName = iterations[1].variablesResolverPosition.last;
      var a =
          _recursivelyProcessHasX(iterations.sublist(1), hasName, name, ret[i]);
      ret[i][processedName] = a;
    }
    return ret;
  } else {
    var ret = <Map<String, dynamic>>[];
    var iteration = List.from(
        submap == null ? iterations.single.iteration! : submap[mapIdentifier]);
    for (var map in iteration) {
      var retMap = Map<String, dynamic>.from(map);
      retMap[hasName] = _processHasXStoringValue(map[name]);
      ret.add(retMap);
    }
    return ret;
  }
}

/// Las `iteration`s son los valores de los primeros List<Map> del varsResolver
/// el exception, `e` es la data del recasing que falta hacer
/// Esta función devuelve el map más primigenio de las iterations con
/// los valores del recasing faltantes agregados en donde corresponde
/// (en los maps del menos primigenio)
List<Map> _recursivelyProcessRecasing(
    _MustacheIteration iteration, MissingVariableException e,
    // ignore: unused_element_parameter
    [Map? submap]) {
  //
  // función auxiliar para recasear los mapas recursivamente
  // se basa en ir llegando a los mapas más internos y recasear lo que haya sido solicitado
  List<Map>? _recursiveRecaseAssignment(List<Map>? mapas, List<String?> keys) {
    if (keys.isEmpty) {
      for (var map in mapas!) {
        //se guarda el recasing
        try {
          //puede ser que te pidan recasear algo que este guardeado con hasAlgo y el mapa no lo tenga definido
          //En ese caso no deberíamos recasear nada porque fallaría erróneamente
          final hasName = e.varName != null
              ? 'has${e.varName![0].toUpperCase()}${e.varName!.substring(1)}'
              : '###';
          final hasNameExpectedIndex =
              e.parentCollectionsWithVarName.indexOf(e.varName) - 1;
          if (hasNameExpectedIndex >
                  0 /* (a check for assuring that it contains the index, i.e. that it's not -1) */ &&
              e.parentCollectionsWithVarName[hasNameExpectedIndex] == hasName &&
              !map.containsKey(e.varName)) {
            continue;
          }
          map[e.request] = map[e.varName][e.recasing];
        } on NoSuchMethodError {
          //trató de recasear algo q dio null, debe faltar
          throw MissingNestedVariableException(e);
        }
      }
      return mapas;
    } else {
      for (var map in mapas!) {
        final processingMap = keys.first;
        if (map[processingMap] != null) {
          final fromMap = (map.containsKey(processingMap) &&
                  (map[processingMap] is Iterable))
              ? map[processingMap]
              : map;
          map[processingMap] = _recursiveRecaseAssignment(
              List<Map>.from(fromMap is List ? fromMap : [fromMap]),
              keys.sublist(1));
        }
      }
      return mapas;
    }
  }

  // los iterations tienen [{},{},{},...]
  var ret = <Map>[];
  //TODO: checkear que si las keys internas no son colecciones o las externas no son StringVariables los omita
  var parentCollectionsKeys = e.parentCollections!
      .sublist(1)
      // remove the hasXXX guards, because they are not maps
      .whereNot((collectionName) => collectionName?.startsWith('has') ?? false)
      // remove the xxx_case/xxxCase guards, because they are not maps
      .whereNot((collectionName) =>
          mustache_recase.cases.keys.any((recase) => recase == collectionName))
      .toList();
  var decoupledIteration = <Map>[];
  iteration.iteration?.forEach((map) => decoupledIteration.add(Map.from(map)));
  ret.addAll(
      _recursiveRecaseAssignment(decoupledIteration, parentCollectionsKeys)!);
  return ret;

  /// Devuelve un map sacado de la primera iteración con todos sus elementos
  /// procesados para devolver sus últimas instancias con un field `request`
  /// con el recaseo apropiado de `varName`
  // var mapIdentifier = iterations.first.variablesResolverPosition.last;
  // if (iterations.length > 1) {
  //   //ir al caso base
  //   var ret = List<Map>.from(
  //       submap == null ? iterations.first.iteration : submap[mapIdentifier]);
  //   for (var i = 0; i < ret.length; i++) {
  //     var processedName = iterations[1].variablesResolverPosition.last;
  //     var a = _recursivelyProcessRecasing(iterations.sublist(1), e, ret[i]);
  //     ret[i][processedName] = a;
  //   }
  //   return ret;
  // } else {
  //   var ret = <Map<String, dynamic>>[];
  //   var iteration = List.from(
  //       submap == null ? iterations.single.iteration : submap[mapIdentifier]);
  //   for (var map in iteration) {
  //     var retMap = Map<String, dynamic>.from(map);
  //     var variable = map[d.varName];
  //     if (variable != null) {
  //       retMap[d.request] = variable[d.recasing];
  //     } else
  //       debugger();
  //     ret.add(retMap);
  //   }
  //   return ret;
  // }
}

typedef ValueProcessFunc = dynamic Function(dynamic);

/// The mustache iterations are formed with a list of maps: e.g.:
/// {{#list}} {{mapItem}} {{#mapList}} {{element}} {{/mapList}} {{/list}}
/// represents a List list = \[ {"mapItem": item, "mapList": \[ {"element":1}, {"element":"2"} \]}, {"mapItem": item2, "mapList": \[ {"element":1}, {"element":"2"} \]}\]
/// Which means that there are several mapList lists, one in each list's map element
/// So this class is made to simplify the manipulation of those elements,
/// which consists of lists of maps that can be easily manipulated with the
/// methods here provided, if so needed
class _MustacheIteration {
  /// The iteration object
  List<Map>? iteration;

  /// A series of names that represents the mustache tags iterated
  /// to reach the List<Map> iteration object
  List<String> variablesResolverPosition;

  _MustacheIteration(this.iteration, this.variablesResolverPosition);

  /// Saves `value` in every element of iteration in the `key` position
  /// and returns the result of doing so
  List<Map> setAll(
      String assignmentKey, String valueKey, ValueProcessFunc func) {
    var ret = <Map>[];
    for (var e in iteration!) {
      e[assignmentKey] = func(e[valueKey]);
      ret.add(e);
    }
    return ret;
  }
}
