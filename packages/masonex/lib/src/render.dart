import 'dart:async';
import 'dart:convert';

import 'package:mustachex/mustachex.dart';
import 'package:masonex/src/recase.dart';

final _newlineInRegExp = RegExp(r'(\\\r\n|\\\r|\\\n)');
final _newlineOutRegExp = RegExp(r'(\r\n|\r|\n)');
final _unicodeInRegExp = RegExp(r'\\[^\x00-\x7F]');
final _unicodeOutRegExp = RegExp(r'[^\x00-\x7F]');

/// The set of built-in lambda names supported by Mason.
const _lambdaNames = {
  'camelCase',
  'constantCase',
  'dotCase',
  'headerCase',
  'lowerCase',
  'mustacheCase',
  'pascalCase',
  'pascalDotCase',
  'paramCase',
  'pathCase',
  'sentenceCase',
  'snakeCase',
  'titleCase',
  'upperCase',
};

/// Regex that matches Mason's `{{varName.lambdaName()}}` or `{{varName | lambdaName}}` syntax.
/// Captures: group(1) = varName, group(2) = lambdaName (without trailing ())
final _masonLambdaRegExp = RegExp(
  r'\{\{\s*([\w]+)\s*(?:\.\s*([\w]+)\s*\(\s*\)|\|\s*([\w]+)\s*)\s*\}\}',
);

/// Transpiles Mason extended lambda syntax into standard mustache section lambdas.
///
/// `{{name.pascalCase()}}` → `{{#pascalCase}}{{name}}{{/pascalCase}}`
/// `{{name | snakeCase}}` → `{{#snakeCase}}{{name}}{{/snakeCase}}`
String _transpileMasonSyntax(String source) {
  return source.replaceAllMapped(_masonLambdaRegExp, (match) {
    final varName = match.group(1)!;
    // group(2) = dot style lambda, group(3) = pipe style lambda
    final lambdaName = match.group(2) ?? match.group(3);
    if (lambdaName == null || !_lambdaNames.contains(lambdaName)) {
      // Not a known lambda — leave it alone so mustachex handles it.
      return match.group(0)!;
    }
    return '{{#$lambdaName}}{{$varName}}{{/$lambdaName}}';
  });
}

String _sanitizeInput(String input) {
  return input.replaceAllMapped(
    RegExp('${_newlineOutRegExp.pattern}|${_unicodeOutRegExp.pattern}'),
    (match) => match.group(0) != null ? '\\${match.group(0)}' : match.input,
  );
}

final _builtInVars = <String, dynamic>{
  '__LEFT_CURLY_BRACKET__': '{',
  '__RIGHT_CURLY_BRACKET__': '}',
  'now': DateTime.now().toIso8601String(),
};

String _sanitizeOutput(String output) {
  return output.replaceAllMapped(
    RegExp('${_newlineInRegExp.pattern}|${_unicodeInRegExp.pattern}'),
    (match) => match.group(0)?.substring(1) ?? match.input,
  );
}

final _builtInLambdas = <String, LambdaFunction>{
  /// camelCase
  'camelCase': (ctx) => ReCase(ctx.renderString()).camelCase,

  /// CONSTANT_CASE
  'constantCase': (ctx) => ReCase(ctx.renderString()).constantCase,

  /// dot.case
  'dotCase': (ctx) => ReCase(ctx.renderString()).dotCase,

  /// Header-Case
  'headerCase': (ctx) => ReCase(ctx.renderString()).headerCase,

  /// lower case
  'lowerCase': (ctx) => ctx.renderString().toLowerCase(),

  /// {{ mustache case }}
  'mustacheCase': (ctx) => '{{ ${ctx.renderString()} }}',

  /// PascalCase
  'pascalCase': (ctx) => ReCase(ctx.renderString()).pascalCase,

  /// Pascal.Dot.Case
  'pascalDotCase': (ctx) => ReCase(ctx.renderString()).pascalDotCase,

  /// param-case
  'paramCase': (ctx) => ReCase(ctx.renderString()).paramCase,

  /// path/case
  'pathCase': (ctx) => ReCase(ctx.renderString()).pathCase,

  /// Sentence case
  'sentenceCase': (ctx) => ReCase(ctx.renderString()).sentenceCase,

  /// snake_case
  'snakeCase': (ctx) => ReCase(ctx.renderString()).snakeCase,

  /// Title Case
  'titleCase': (ctx) => ReCase(ctx.renderString()).titleCase,

  /// UPPER CASE
  'upperCase': (ctx) => ctx.renderString().toUpperCase(),
};

/// {@template render_template}
/// Given a `String` with mustache templates, and a [Map] of String key /
/// value pairs, substitute all instances of `{{key}}` for `value`.
///
/// ```text
/// Hello {{name}}!
/// ```
///
/// and
///
/// ```text
/// {'name': 'Bob'}
/// ```
///
/// becomes:
///
/// ```text
/// Hello Bob!
/// ```
/// {@endtemplate}
extension RenderTemplate on String {
  /// {@macro render_template}
  Future<String> render(
    Map<String, dynamic> vars, {
    PartialResolverFunction? partialsResolver,
    FutureOr<String> Function(String variable)? onMissingVariable,
  }) async {
    final renderedBytes = await renderBytes(
      vars,
      partialsResolver: partialsResolver,
      onMissingVariable: onMissingVariable,
    );
    return _sanitizeOutput(utf8.decode(renderedBytes));
  }

  /// Processes the [String] template and returns the rendered result as raw bytes ([List<int>]).
  /// Binary values (Uint8List / List<int>) in [vars] are written directly without string conversion.
  Future<List<int>> renderBytes(
    Map<String, dynamic> vars, {
    PartialResolverFunction? partialsResolver,
    FutureOr<String> Function(String variable)? onMissingVariable,
  }) async {
    // Transpile Mason's dot/pipe lambda syntax into standard mustache sections
    // BEFORE handing off to MustachexProcessor. This ensures
    // `{{name.pascalCase()}}` becomes `{{#pascalCase}}{{name}}{{/pascalCase}}`
    // so the built-in lambda functions handle it correctly.
    final transpiled = _transpileMasonSyntax(this);

    final allVars = <String, dynamic>{
      ...vars,
      ..._builtInLambdas,
      ..._builtInVars,
    };

    final processor = MustachexProcessor(
      initialVariables: allVars,
      missingVarFulfiller: onMissingVariable != null
          ? (exception) async => await onMissingVariable(exception.varName!)
          : null,
      partialsResolver: partialsResolver,
    );

    try {
      return await processor.processBytes(transpiled);
    } catch (e, st) {
      print('Render error for $this: $e\n$st');
      return utf8.encode(this);
    }
  }
}

/// {@template resolve_partial}
/// A resolver function which given a partial name.
/// attempts to return a new [Template].
/// {@endtemplate}
extension ResolvePartial on Map<String, List<int>> {
  /// {@macro resolve_partial}
  Template? resolve(String name) {
    final content = this['{{~ $name }}'];
    if (content == null) return null;
    final decoded = utf8.decode(content);
    final sanitized = _sanitizeInput(decoded);
    return Template(sanitized, name: name, lenient: true);
  }
}
