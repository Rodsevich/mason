/// The taskflow plugin registry.
///
/// This file is production code, not a brick. The annotation lines below
/// are read by `inFileGenerationBuilder` (run via `masonex build`) and
/// turned into entries in `inFileGenerations.json`. When someone later
/// renders a brick that ships a `%plugin_register%` snippet file, the
/// snippet is woven in at the matching annotation site.
///
/// The builder is line-based: it looks for `@GenerateBefore`,
/// `@GenerateAfter`, or `@GenerationMerge` together with a `:` and uses
/// everything after the colon as the template payload. Putting the
/// annotations inside `//` comments keeps the file valid Dart while
/// still being parseable by masonex.
class TaskRegistry {
  TaskRegistry._();

  // @GenerateBefore('imports'): {{plugin_import_lines}}
  static final _plugins = <String>[
    'core',
    // @GenerateAfter('plugin_register'): '{{new_plugin_id}}',
  ];

  // @GenerationMerge('plugin_factories'): '{{factory_id}}': () => {{factory_class}}(),
  static final factories = <String, dynamic Function()>{
    'core': () => const Object(),
  };

  /// Read-only view of the plugin id list.
  static List<String> get plugins => List.unmodifiable(_plugins);
}
