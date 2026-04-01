import 'package:analysis_utils/analyzer_components.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/src/dart/ast/constant_evaluator.dart';

/// Class used to resolve the parameters in compile time. i.e. 1 + 2 will be
/// resolved to 3, without having to execute code. ConstantEvaluator handles it.
class _ArgumentsResolver extends ConstantEvaluator {
  /// resolves the (name: "expression") arguments kind
  NamedExpression visitNamedExpression(NamedExpression node) {
    node.setProperty("resolution", node.expression.accept(this));
    return node;
  }
}

Object NOT_A_CONSTANT = Object();

/// Resolves the default value for a named expression
///
/// Made to be used with:
/// var bar = "foo"; //A [VariableDeclaration]
/// [VariableDeclaration].initializer = "foo"
/// getDefaultValue([VariableDeclaration]) -> "foo"
///
/// If it's not possible to get the compile-time value, [NOT_A_CONSTANT] is returned
dynamic getDefaultValue(VariableDeclaration declaration) {
  if (declaration.initializer == null)
    throw ArgumentError("VariableDeclaration must have an initializer");
  Expression expression = declaration.initializer!;
  ConstantEvaluator constantEvaluator = ConstantEvaluator();
  var ret = expression.accept(constantEvaluator);
  if (ret == ConstantEvaluator.NOT_A_CONSTANT) return NOT_A_CONSTANT;
  return ret;
}

/// Class intended to provide an analysis of analyzed [ArgumentList] or string
/// "(arg1,arg2,argN)" formatted arguments in a way suitable for instantiating
/// from mirrors
class ArgumentsResolution {
  List<dynamic> positional = [];
  Map<Symbol, dynamic> named = {};
  ArgumentsResolution.fromArgumentList(ArgumentList list) {
    _processArgs(list);
  }

  /// Must be provided a `source` in a "(arg1,arg2,argN)" format
  ArgumentsResolution.fromSourceConstants(String source) {
    String funcSrc = "var q = a$source;";
    CompilationUnit c = getCompilationUnitForSource(funcSrc);
    var t = c.declarations.single as TopLevelVariableDeclaration;
    final list = t.childEntities.first as VariableDeclarationList;
    VariableDeclaration de = list.variables.first;
    Expression expression = de.initializer!;
    ArgumentList args = (expression as MethodInvocation).argumentList;
    _processArgs(args);
  }
  _processArgs(ArgumentList list) {
    _ArgumentsResolver resolver = _ArgumentsResolver();
    for (AstNode arg in list.arguments) {
      //resolve the constant expressions like "str" "ing" (will resolve to "string")
      var val = arg.accept(resolver);
      // only thing that can't be properly resolved because of the Label + Expression
      if (val is NamedExpression)
        named[Symbol(val.name.label.token.value().toString())] =
            val.getProperty("resolution");
      else
        positional.add(val);
    }
  }

  List get all {
    List ret = positional;
    ret.addAll(named.keys);
    return ret;
  }
}
