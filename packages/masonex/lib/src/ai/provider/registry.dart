// ignore_for_file: public_member_api_docs, lines_longer_than_80_chars

import 'package:masonex/src/ai/provider/adapter.dart';
import 'package:masonex/src/ai/provider/builtin/aider.dart';
import 'package:masonex/src/ai/provider/builtin/claude.dart';
import 'package:masonex/src/ai/provider/builtin/codex.dart';
import 'package:masonex/src/ai/provider/builtin/cursor_agent.dart';
import 'package:masonex/src/ai/provider/builtin/custom.dart';
import 'package:masonex/src/ai/provider/builtin/gemini.dart';
import 'package:masonex/src/ai/provider/builtin/ollama.dart';
import 'package:masonex/src/ai/provider/config_yaml.dart';
import 'package:masonex/src/ai/provider/descriptor.dart';

/// Built-in providers known to masonex out of the box. Used by the
/// interactive setup wizard to suggest options when no config exists.
const List<AiProviderDescriptor> builtinProviderDescriptors = [
  ClaudeProviderAdapter.staticDescriptor,
  GeminiProviderAdapter.staticDescriptor,
  CodexProviderAdapter.staticDescriptor,
  CursorAgentProviderAdapter.staticDescriptor,
  AiderProviderAdapter.staticDescriptor,
  OllamaProviderAdapter.staticDescriptor,
];

/// Returns the built-in default `ProviderConfig` for [id], or null if
/// the id is unknown. Used by the interactive setup to populate
/// `~/.masonex/providers.yaml` when the user picks a known CLI.
ProviderConfig? defaultConfigFor(String id) {
  switch (id) {
    case 'claude':
      return ClaudeProviderAdapter.defaultConfig;
    case 'gemini':
      return GeminiProviderAdapter.defaultConfig;
    case 'codex':
      return CodexProviderAdapter.defaultConfig;
    case 'cursor-agent':
      return CursorAgentProviderAdapter.defaultConfig;
    case 'aider':
      return AiderProviderAdapter.defaultConfig;
    case 'ollama':
      return OllamaProviderAdapter.defaultConfig;
    default:
      return null;
  }
}

/// Builds an [AiProviderAdapter] for the given config. Known IDs map to
/// dedicated adapters; everything else uses the generic CLI runner.
AiProviderAdapter buildAdapter(ProviderConfig config) {
  switch (config.id) {
    case 'claude':
      return ClaudeProviderAdapter(config: config);
    case 'gemini':
      return GeminiProviderAdapter(config: config);
    case 'codex':
      return CodexProviderAdapter(config: config);
    case 'cursor-agent':
      return CursorAgentProviderAdapter(config: config);
    case 'aider':
      return AiderProviderAdapter(config: config);
    case 'ollama':
      return OllamaProviderAdapter(config: config);
    case 'mock':
      throw StateError(
        'Mock provider must be constructed explicitly with a brick root.',
      );
    default:
      return CustomProviderAdapter(config);
  }
}
