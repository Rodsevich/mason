// ignore_for_file: public_member_api_docs, lines_longer_than_80_chars

import 'package:masonex/src/ai/pipeline/pipeline_node.dart';

/// A single AI tag request extracted from a template by the rewriter.
///
/// The orchestrator consumes these, resolves them through the configured
/// provider, applies validators and post-filters, and produces a
/// [resolvedValue] that gets injected into the variables map under the
/// synthetic name [syntheticVarName].
class AiTagRequest {
  AiTagRequest({
    required this.id,
    required this.syntheticVarName,
    required this.relativePath,
    required this.line,
    required this.column,
    required this.prompt,
    required this.node,
    required this.tagOriginal,
    required this.inlineHint,
  });

  /// Stable identifier for this tag inside the current render. Used for
  /// fixtures, cache lookups, traces and `consider`/`consistent_with`
  /// references in v2.
  final String id;

  /// The mustache variable name we substitute in the rewritten template.
  /// Defaults to `__masonex_ai_<n>` where `<n>` is a per-render counter.
  final String syntheticVarName;

  /// Path of the file inside `__brick__/` that owns this tag, with leading
  /// `__brick__/` stripped for readability. Empty when the tag was found in
  /// some non-file source (e.g., audit-only operations).
  final String relativePath;
  final int line;
  final int column;

  /// The prompt that will be sent to the AI as the literal `<prompt>` in the
  /// envelope. Mustache substitutions (`{{vars}}` inside the literal) are
  /// already resolved by the rewriter.
  final String prompt;

  /// The full pipeline AST.
  final FilterPipelineNode node;

  /// Original tag content (between `{{` and `}}`).
  final String tagOriginal;

  /// Whether the tag was found inline (in the middle of a line) or as a
  /// standalone tag occupying its own line. Drives the `<expected_shape>`
  /// hint in the envelope.
  final bool inlineHint;

  /// Resolved string value, written by the orchestrator. `null` until the
  /// tag has been processed.
  String? resolvedValue;

  /// Diagnostics: which provider produced the value (or 'cache'), and how
  /// many retries were needed.
  String? resolvedBy;
  int retries = 0;
  bool fromCache = false;
  Duration? duration;
}
