// ignore_for_file: public_member_api_docs, lines_longer_than_80_chars

/// Inputs required by an [AiProviderAdapter] to perform a single AI call.
class AiInvocation {
  const AiInvocation({
    required this.systemPrompt,
    required this.userEnvelope,
    this.modelOverride,
    this.temperature,
    this.seed,
  });

  final String systemPrompt;

  /// XML-serialized [Envelope] sent as the user prompt.
  final String userEnvelope;
  final String? modelOverride;
  final double? temperature;
  final int? seed;
}

/// Output of a single AI call, before validation/post-processing.
class AiInvocationResult {
  const AiInvocationResult({
    required this.stdout,
    required this.duration,
    this.stderrPreview = '',
    this.modelReported,
  });

  final String stdout;
  final Duration duration;
  final String stderrPreview;
  final String? modelReported;
}
