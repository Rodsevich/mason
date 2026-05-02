// ignore_for_file: public_member_api_docs, lines_longer_than_80_chars

import 'package:masonex/src/ai/provider/adapter.dart';
import 'package:masonex/src/ai/provider/builtin/claude.dart';
import 'package:masonex/src/ai/provider/builtin/custom.dart';
import 'package:masonex/src/ai/provider/config_yaml.dart';
import 'package:masonex/src/ai/provider/descriptor.dart';

/// Built-in providers known to masonex out of the box. Used by the
/// interactive setup wizard to suggest options when no config exists.
const List<AiProviderDescriptor> builtinProviderDescriptors = [
  ClaudeProviderAdapter.staticDescriptor,
  AiProviderDescriptor(
    id: 'gemini',
    displayName: 'Gemini (Google CLI)',
    requiredCommand: 'gemini',
    notes: 'TODO(F4): full adapter; works today via custom config.',
  ),
  AiProviderDescriptor(
    id: 'codex',
    displayName: 'Codex (OpenAI CLI)',
    requiredCommand: 'codex',
    notes: 'TODO(F4): full adapter; works today via custom config.',
  ),
  AiProviderDescriptor(
    id: 'cursor-agent',
    displayName: 'Cursor agent CLI',
    requiredCommand: 'cursor-agent',
    notes: 'TODO(F4): full adapter; works today via custom config.',
  ),
  AiProviderDescriptor(
    id: 'aider',
    displayName: 'Aider',
    requiredCommand: 'aider',
    notes: 'TODO(F4): full adapter; works today via custom config.',
  ),
  AiProviderDescriptor(
    id: 'ollama',
    displayName: 'Ollama (local)',
    requiredCommand: 'ollama',
    notes: 'TODO(F4): full adapter; works today via custom config.',
  ),
];

/// Builds an [AiProviderAdapter] for the given config. Known IDs map to
/// dedicated adapters; everything else uses the generic CLI runner.
AiProviderAdapter buildAdapter(ProviderConfig config) {
  switch (config.id) {
    case 'claude':
      return ClaudeProviderAdapter(config: config);
    case 'mock':
      // Mock requires brick root; instantiated by callers directly.
      throw StateError(
        'Mock provider must be constructed explicitly with a brick root.',
      );
    default:
      return CustomProviderAdapter(config);
  }
}
