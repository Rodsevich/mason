// ignore_for_file: public_member_api_docs, lines_longer_than_80_chars

import 'package:masonex/src/ai/provider/descriptor.dart';
import 'package:masonex/src/ai/provider/invocation.dart';

/// Common interface for any provider that can fulfil an AI invocation.
abstract class AiProviderAdapter {
  AiProviderDescriptor get descriptor;

  /// Quick check: is this provider's CLI available and authenticated?
  /// Implementations should NOT actually invoke the model — at most a
  /// trivial probe (e.g., `claude --version`).
  Future<bool> isAvailable();

  /// Performs a single invocation. Implementations are responsible for:
  ///   - propagating timeouts (throw [AiTimeoutError] from the errors module)
  ///   - producing structured errors (auth, invocation, etc.)
  ///   - writing prompt material to a temporary file when the CLI requires it
  Future<AiInvocationResult> invoke(
    AiInvocation request, {
    required Duration timeout,
  });
}
