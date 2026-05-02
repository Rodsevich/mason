// ignore_for_file: public_member_api_docs, lines_longer_than_80_chars

/// Describes a provider so the interactive selector and audit commands can
/// list it without instantiating the adapter.
class AiProviderDescriptor {
  const AiProviderDescriptor({
    required this.id,
    required this.displayName,
    required this.requiredCommand,
    this.helpUrl,
    this.notes,
  });

  /// Stable identifier used in `~/.masonex/providers.yaml`.
  final String id;

  /// Human-readable name shown in `masonex provider show` and the wizard.
  final String displayName;

  /// The CLI binary that must exist on PATH for this provider to be usable.
  final String requiredCommand;

  final String? helpUrl;
  final String? notes;
}
