import 'dart:async';

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

/// Gathers all classes indicated and executes `partCode` for getting
/// the code that will be generated in the part file for that class
abstract class ClassPartGenerator extends Generator {
  late ShouldGenerateForFuction checkingFunction;

  ClassPartGenerator(
      {String? superclassTypeName, ShouldGenerateForFuction? checkingFunction}) {
    if (checkingFunction != null) {
      if (superclassTypeName != null) {
        throw _bothArgumentsError();
      }
      this.checkingFunction = checkingFunction;
    } else if (superclassTypeName != null) {
      this.checkingFunction = (ClassElement element) => element.allSupertypes
          .any((InterfaceType t) =>
              t.element.thisType.getDisplayString(withNullability: false) == superclassTypeName);
    } else {
      throw _noneArgumentsError();
    }
  }

  @override
  Future<String?> generate(LibraryReader library, BuildStep buildStep) async {
    var c = library.classes.where((ClassElement c) => checkingFunction(c));
    if (c.isEmpty) return null;
    var ret = '';
    await Future.forEach(c, (ClassElement c) async {
      ret += await partCode(c);
    });
    return ret;
  }

  ArgumentError _noneArgumentsError() => ArgumentError(
      'Must provide one, and only one, of the named arguments '
      'for this $runtimeType constructor');

  ArgumentError _bothArgumentsError() {
    return ArgumentError(
        "Provided both a checkingFunction and a classType. That's useless");
  }

  ///The function to implement for having this generator working
  FutureOr<String> partCode(ClassElement element);
}

/// The format of the function that the user should implement for
/// filtering which classes generate part files for
typedef ShouldGenerateForFuction = bool Function(ClassElement element);
