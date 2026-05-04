import 'dart:async';
import 'dart:convert';

import 'package:masonex/src/ai/integration.dart';
import 'package:masonex/src/recase.dart';
import 'package:mustachex/mustachex.dart';

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

final _aiPipelineDetector = RegExp(r'(\|\s*ai\b|\.\s*ai\s*\()');

String _transpileMasonSyntax(String content) {
  final tagRegex = RegExp(r'(\{{2,3})(.*?)(\}{2,3})', dotAll: true);

  return content.replaceAllMapped(tagRegex, (match) {
    var opening = match.group(1)!;
    final inner = match.group(2)!;
    var closing = match.group(3)!;

    final trimmedInner = inner.trim();
    if (trimmedInner.startsWith('#') ||
        trimmedInner.startsWith('/') ||
        trimmedInner.startsWith('^') ||
        trimmedInner.startsWith('>') ||
        trimmedInner.startsWith('&') ||
        trimmedInner.startsWith('{')) {
      return match.group(0)!;
    }

    // Skip tags that include the deferred `ai` filter; they are handled
    // by mustachex 2.0's native pipeline support so the rest of the
    // chain (uppercase/snakeCase/etc.) must remain visible to the parser.
    if (_aiPipelineDetector.hasMatch(trimmedInner)) {
      return match.group(0)!;
    }

    final tagLen = opening.length < closing.length
        ? opening.length
        : closing.length;

    var prefix = opening.substring(0, opening.length - tagLen);
    var suffix = closing.substring(tagLen);
    opening = opening.substring(opening.length - tagLen);
    closing = closing.substring(0, tagLen);

    final lambdas = <String>[];
    var currentInner = inner;

    var changed = true;
    while (changed) {
      changed = false;
      final currentTrimmed = currentInner.trim();

      var foundInThisPass = false;
      for (final lambda in _lambdaNames) {
        final dotRegex = RegExp(r'\.\s*' + lambda + r'\s*\(\s*\)\s*$');
        final dotMatch = dotRegex.firstMatch(currentTrimmed);
        if (dotMatch != null) {
          lambdas.add(lambda);
          final startInInner =
              currentInner.lastIndexOf(currentTrimmed) + dotMatch.start;
          currentInner = currentInner.substring(0, startInInner);
          foundInThisPass = true;
          changed = true;
          break;
        }
      }

      if (!foundInThisPass) {
        for (final lambda in _lambdaNames) {
          final pipeRegex = RegExp(r'\|\s*' + lambda + r'\s*$');
          final pipeMatch = pipeRegex.firstMatch(currentTrimmed);
          if (pipeMatch != null) {
            lambdas.add(lambda);
            final startInInner =
                currentInner.lastIndexOf(currentTrimmed) + pipeMatch.start;
            currentInner = currentInner.substring(0, startInInner);
            foundInThisPass = true;
            changed = true;
            break;
          }
        }
      }
    }

    if (lambdas.isEmpty) {
      return match.group(0)!;
    }

    final varPart = currentInner;
    final varName = (varPart.trim().isEmpty || varPart.trim() == '..')
        ? '.'
        : varPart;
    // We use triple braces if the original was triple, but we must ensure
    // it doesn't merge with a prefix brace.
    var result = (opening.length == 3 && closing.length == 3)
        ? '{{{$varName}}}'
        : '{{$varName}}';

    for (final lambda in lambdas.reversed) {
      result = '{{#$lambda}}$result{{/$lambda}}';
    }

    String escape(String s) {
      var res = '';
      for (var i = 0; i < s.length; i++) {
        if (s[i] == '{') {
          res += '{{__LEFT_CURLY_BRACKET__}}';
        } else if (s[i] == '}') {
          res += '{{__RIGHT_CURLY_BRACKET__}}';
        } else {
          res += s[i];
        }
      }
      return res;
    }

    prefix = escape(prefix);
    suffix = escape(suffix);

    return '$prefix$result$suffix';
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
  'camelCase': (ctx) => ReCase(ctx.renderString()).camelCase,
  'constantCase': (ctx) => ReCase(ctx.renderString()).constantCase,
  'dotCase': (ctx) => ReCase(ctx.renderString()).dotCase,
  'headerCase': (ctx) => ReCase(ctx.renderString()).headerCase,
  'lowerCase': (ctx) => ctx.renderString().toLowerCase(),
  'mustacheCase': (ctx) => '{{ ${ctx.renderString()} }}',
  'pascalCase': (ctx) => ReCase(ctx.renderString()).pascalCase,
  'pascalDotCase': (ctx) => ReCase(ctx.renderString()).pascalDotCase,
  'paramCase': (ctx) => ReCase(ctx.renderString()).paramCase,
  'pathCase': (ctx) => ReCase(ctx.renderString()).pathCase,
  'sentenceCase': (ctx) => ReCase(ctx.renderString()).sentenceCase,
  'snakeCase': (ctx) => ReCase(ctx.renderString()).snakeCase,
  'titleCase': (ctx) => ReCase(ctx.renderString()).titleCase,
  'upperCase': (ctx) => ctx.renderString().toUpperCase(),
};

/// Adds template-rendering helpers ([render], [renderBytes]) to [String].
extension RenderTemplate on String {
  /// Renders this template string against [vars] and returns the result.
  Future<String> render(
    Map<String, dynamic> vars, {
    PartialResolverFunction? partialsResolver,
    FutureOr<String> Function(String variable)? onMissingVariable,
    AiRenderOptions? aiOptions,
  }) async {
    final renderedBytes = await renderBytes(
      vars,
      partialsResolver: partialsResolver,
      onMissingVariable: onMissingVariable,
      aiOptions: aiOptions,
    );
    return _sanitizeOutput(utf8.decode(renderedBytes));
  }

  /// Renders this template string against [vars] and returns the raw bytes.
  Future<List<int>> renderBytes(
    Map<String, dynamic> vars, {
    PartialResolverFunction? partialsResolver,
    FutureOr<String> Function(String variable)? onMissingVariable,
    AiRenderOptions? aiOptions,
  }) async {
    final allVars = <String, dynamic>{
      ...vars,
      ..._builtInLambdas,
      ..._builtInVars,
    };

    var filters = <MustachexFilter>[];
    var resolutions = <DeferredCallId, String>{};
    if (aiOptions != null && !aiOptions.disabled) {
      final aiResult = await runAiPass(
        this,
        vars: vars,
        options: aiOptions,
      );
      filters = aiResult.filters;
      resolutions = aiResult.deferredResolutions;
    }

    final transpiled = _transpileMasonSyntax(this);

    final processor = MustachexProcessor(
      lenient: true,
      initialVariables: allVars,
      missingVarFulfiller: onMissingVariable != null
          ? (exception) async => await onMissingVariable(exception.varName!)
          : null,
      partialsResolver: partialsResolver,
      filters: filters,
      deferredResolutions: resolutions,
    );

    try {
      return await processor.processBytes(transpiled);
    } catch (e, st) {
      // ignore: avoid_print
      print('Render error for $this: $e\n$st');
      return utf8.encode(this);
    }
  }
}

/// Adds [resolve] for looking up partial templates by name from a byte map.
extension ResolvePartial on Map<String, List<int>> {
  /// Returns the partial [Template] registered under [name], or `null`.
  Template? resolve(String name) {
    final content = this[name];
    if (content == null) return null;
    final decoded = utf8.decode(content);
    final transpiled = _transpileMasonSyntax(decoded);
    final sanitized = _sanitizeInput(transpiled);
    return Template(sanitized, name: name, lenient: true);
  }
}
