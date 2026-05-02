// ignore_for_file: public_member_api_docs, lines_longer_than_80_chars, cascade_invocations

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:masonex/src/ai/errors.dart';
import 'package:masonex/src/ai/pipeline/ai_tag_request.dart';
import 'package:masonex/src/ai/pipeline/parser.dart';
import 'package:masonex/src/ai/pipeline/pipeline_node.dart';
import 'package:masonex/src/ai/pipeline/tag_finder.dart';

/// Result of an AI rewriting pass over a single template source.
class RewriteResult {
  RewriteResult({
    required this.rewrittenSource,
    required this.requests,
  });

  final String rewrittenSource;
  final List<AiTagRequest> requests;
}

/// Rewrites a template source by detecting `| ai` / `.ai(...)` pipelines and
/// replacing them with synthetic variables. Returns the rewritten source plus
/// a list of [AiTagRequest] to be resolved by the orchestrator.
///
/// Tags without `ai` are left untouched (the existing masonex transpiler
/// continues to handle plain pipelines like `{{name | uppercase}}`).
class AiTagRewriter {
  AiTagRewriter({
    required this.relativePath,
    required this.varsForPrompt,
    int initialIndex = 0,
  }) : _index = initialIndex;

  /// Path inside `__brick__/` (relative). Used to compute stable IDs.
  final String relativePath;

  /// Vars used to pre-render Mustache substitutions inside literal prompts.
  /// Only top-level scalars are interpolated; nested maps / lists are
  /// rendered with `toString()`. This is intentionally minimal — for richer
  /// substitutions, the brick author should use a regular template tag and
  /// pipe its value through `| ai(...)`.
  final Map<String, dynamic> varsForPrompt;

  int _index;

  RewriteResult rewrite(String source) {
    final tags = TagFinder(source).find().toList();
    if (tags.isEmpty) return RewriteResult(rewrittenSource: source, requests: []);

    final requests = <AiTagRequest>[];
    final buf = StringBuffer();
    var cursor = 0;

    for (final tag in tags) {
      final content = tag.content.trim();
      if (content.isEmpty) continue;
      // Skip section / inverse / partial / comment / unescaped sigils — they
      // never carry pipelines in masonex.
      final firstChar = content[0];
      if (const ['#', '/', '^', '>', '!', '&', '='].contains(firstChar)) {
        continue;
      }

      FilterPipelineNode? node;
      try {
        node = PipelineParser.fromTag(tag.content).parse();
      } on AiSyntaxError {
        rethrow;
      }

      if (node == null || !node.hasAi) continue;

      // Build the prompt string from the head (literal vs var).
      final prompt = _buildPrompt(node);

      final inline = !_tagOnOwnLine(source, tag.tagStart, tag.tagEnd);

      final id = _stableId(relativePath, tag.line, tag.column, prompt);
      final syntheticName = '__masonex_ai_${_index++}';

      requests.add(
        AiTagRequest(
          id: id,
          syntheticVarName: syntheticName,
          relativePath: relativePath,
          line: tag.line,
          column: tag.column,
          prompt: prompt,
          node: node,
          tagOriginal: tag.content,
          inlineHint: inline,
        ),
      );

      // Emit untouched chunk before this tag.
      buf.write(source.substring(cursor, tag.tagStart));
      // Emit synthetic tag (always escape=false / triple braces) so the AI
      // output is inserted verbatim — escaping the AI value would corrupt
      // language-specific punctuation.
      buf.write('{{{$syntheticName}}}');
      cursor = tag.tagEnd;
    }
    buf.write(source.substring(cursor));

    return RewriteResult(
      rewrittenSource: buf.toString(),
      requests: requests,
    );
  }

  String _buildPrompt(FilterPipelineNode node) {
    if (node.headKind == HeadKind.literal) {
      return _renderMustacheLiteral(node.head);
    }
    // Variable head: lookup in vars (top-level only). If missing, fall back
    // to the head as a literal (user's choice per the RFC).
    final value = varsForPrompt[node.head];
    if (value == null) return node.head;
    return value.toString();
  }

  /// Mini-Mustache pre-render for prompt literals. Supports `{{varName}}`
  /// substitutions only. Anything else (sections, partials) is left as-is.
  String _renderMustacheLiteral(String literal) {
    final re = RegExp(r'\{\{\s*([a-zA-Z_][a-zA-Z0-9_-]*)\s*\}\}');
    return literal.replaceAllMapped(re, (m) {
      final key = m.group(1)!;
      final value = varsForPrompt[key];
      return value?.toString() ?? m.group(0)!;
    });
  }

  bool _tagOnOwnLine(String source, int start, int end) {
    // Look backward for newline.
    var i = start - 1;
    while (i >= 0) {
      final c = source[i];
      if (c == '\n') break;
      if (c != ' ' && c != '\t' && c != '\r') return false;
      i--;
    }
    // Look forward for newline.
    var j = end;
    while (j < source.length) {
      final c = source[j];
      if (c == '\n') break;
      if (c != ' ' && c != '\t' && c != '\r') return false;
      j++;
    }
    return true;
  }

  static String _stableId(
    String path,
    int line,
    int column,
    String prompt,
  ) {
    final raw = '$path|L$line|c$column|${prompt.length}|$prompt';
    final digest = sha256.convert(utf8.encode(raw)).toString();
    return '${path.isEmpty ? "<inline>" : path}#L$line:c$column:'
        '${digest.substring(0, 8)}';
  }
}
