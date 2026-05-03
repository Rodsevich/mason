// ignore_for_file: public_member_api_docs, lines_longer_than_80_chars

import 'dart:io';

/// Tiny localisation layer for interactive prompts in the AI subsystem.
/// English by default; Spanish when `MASONEX_LANG=es` is set in the
/// environment.
///
/// We keep this minimal on purpose: interactive prompts are short and
/// the language is set process-wide, so a flat key→string map is
/// enough. Adding a new locale is one map entry per key.
class AiI18n {
  AiI18n._(this._strings);

  factory AiI18n.fromEnv() {
    final lang =
        (Platform.environment['MASONEX_LANG'] ?? 'en').toLowerCase().trim();
    if (lang.startsWith('es')) {
      return AiI18n._(_es);
    }
    return AiI18n._(_en);
  }

  final Map<String, String> _strings;

  String tr(String key, {Map<String, String>? params}) {
    final base = _strings[key] ?? _en[key] ?? key;
    if (params == null || params.isEmpty) return base;
    var result = base;
    params.forEach((k, v) {
      result = result.replaceAll('{$k}', v);
    });
    return result;
  }

  static const _en = {
    'noProviderConfigured':
        'No AI provider configured (~/.masonex/providers.yaml).',
    'detectingClis': 'Detecting CLIs available on PATH...',
    'noClisDetected': 'No known CLIs detected on PATH.',
    'detectedList': 'Detected: {list}',
    'pickProvider': 'Pick a provider to configure:',
    'configureManually': 'custom (configure manually)',
    'abort': 'abort',
    'savedConfig': 'Saved provider configuration to {path}',
    'providerFailed': 'AI provider failed: {message}',
    'choose': 'Choose:',
    'editAndRetry': 'edit ~/.masonex/providers.yaml and retry',
    'abortRender': 'abort the render',
    'openingEditor': 'Opening {path} in {editor}...',
    'editorExitedNonZero': 'Editor exited with code {code}.',
    'launchFailed': 'Could not launch editor: {message}',
  };

  static const _es = {
    'noProviderConfigured':
        'No hay un proveedor de IA configurado (~/.masonex/providers.yaml).',
    'detectingClis': 'Detectando CLIs disponibles en el PATH...',
    'noClisDetected': 'No se detectó ninguna CLI conocida en el PATH.',
    'detectedList': 'Detectadas: {list}',
    'pickProvider': 'Elegí un proveedor:',
    'configureManually': 'manual (configurar a mano)',
    'abort': 'abortar',
    'savedConfig': 'Configuración guardada en {path}',
    'providerFailed': 'Falló el proveedor de IA: {message}',
    'choose': 'Elegí:',
    'editAndRetry': 'editar ~/.masonex/providers.yaml y reintentar',
    'abortRender': 'abortar el render',
    'openingEditor': 'Abriendo {path} con {editor}...',
    'editorExitedNonZero': 'El editor terminó con código {code}.',
    'launchFailed': 'No se pudo abrir el editor: {message}',
  };
}
