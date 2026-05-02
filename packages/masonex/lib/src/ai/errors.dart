// ignore_for_file: public_member_api_docs, lines_longer_than_80_chars

import 'package:masonex/src/exception.dart';

/// Base class for all errors emitted by the masonex AI subsystem.
class AiException extends MasonexException {
  const AiException(super.message);
}

/// Thrown when a tag's pipeline syntax cannot be parsed.
class AiSyntaxError extends AiException {
  AiSyntaxError(this.tagOriginal, String reason)
      : super('Invalid AI pipeline syntax in tag $tagOriginal. $reason');

  final String tagOriginal;
}

/// Thrown when a tag with `| ai` is used in a path or filename. Paths must
/// remain deterministic; AI is allowed only inside file contents.
class AiInPathError extends AiException {
  AiInPathError(this.path)
      : super('The `ai` filter is not allowed in paths or filenames. '
            'Found in: $path');

  final String path;
}

/// Thrown when an AI output fails validation rules (`match`, `oneOf`,
/// `schema`, `lines`, …) after exhausting all retries.
class AiValidationError extends AiException {
  AiValidationError(this.tagId, this.reason, this.lastOutput)
      : super('AI output for tag $tagId failed validation: $reason');

  final String tagId;
  final String reason;
  final String lastOutput;
}

/// The model returned the sentinel `MASONEX_ERROR: <reason>`.
class AiOutputContractError extends AiException {
  AiOutputContractError(this.tagId, this.modelReason)
      : super('AI returned MASONEX_ERROR for tag $tagId: $modelReason');

  final String tagId;
  final String modelReason;
}

/// The configured provider command was not found on PATH.
class AiProviderUnavailableError extends AiException {
  AiProviderUnavailableError(this.providerId, this.commandTried)
      : super('Configured AI provider "$providerId" is unavailable: '
            'command not found on PATH ($commandTried).');

  final String providerId;
  final String commandTried;
}

/// The provider command exited with non-zero status.
class AiProviderInvocationError extends AiException {
  AiProviderInvocationError(
    this.providerId,
    this.exitCode,
    this.stderrPreview,
  ) : super('AI provider "$providerId" invocation failed '
            '(exit $exitCode): $stderrPreview');

  final String providerId;
  final int exitCode;
  final String stderrPreview;
}

/// The provider reported authentication failure.
class AiAuthError extends AiException {
  AiAuthError(this.providerId, String detail)
      : super('AI provider "$providerId" not authenticated. $detail');

  final String providerId;
}

/// A single AI invocation exceeded its configured timeout.
class AiTimeoutError extends AiException {
  AiTimeoutError(this.providerId, this.timeout)
      : super('AI provider "$providerId" timed out after $timeout.');

  final String providerId;
  final Duration timeout;
}

/// The envelope exceeds the configured token budget even after truncation.
class AiContextOverflowError extends AiException {
  AiContextOverflowError(this.tagId, this.estimatedTokens, this.budget)
      : super('AI envelope for tag $tagId is too large '
            '(~$estimatedTokens tokens > $budget budget) '
            'and could not be safely truncated.');

  final String tagId;
  final int estimatedTokens;
  final int budget;
}

/// User chose to abort the render in an interactive recovery prompt.
class AiAbortedByUserError extends AiException {
  AiAbortedByUserError() : super('AI render aborted by user.');
}

/// Cache file is corrupt and `--strict-cache` was requested.
class AiCacheError extends AiException {
  AiCacheError(String detail) : super('AI cache error: $detail');
}

/// Render aborted because at least one tag couldn't be resolved.
/// No file in the destination project was modified.
class AiAbortedRenderError extends AiException {
  AiAbortedRenderError(this.cause)
      : super('AI render aborted: ${cause.message}. '
            'No files were modified.');

  final AiException cause;
}
