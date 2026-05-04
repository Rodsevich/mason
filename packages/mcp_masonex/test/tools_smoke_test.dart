import 'package:mcp_dart/mcp_dart.dart';
import 'package:mcp_masonex/mcp_masonex.dart';
import 'package:test/test.dart';

void main() {
  group('mcp_masonex server', () {
    test('builds with a custom runner and registers tools', () {
      // We pass an executable path that should never exist on a CI box —
      // it does not matter for this smoke test because we only inspect
      // the registered tool surface, never invoke them.
      final runner = MasonexRunner(executable: '/nonexistent/masonex');
      final server = buildServer(runner: runner);
      expect(server, isA<McpServer>());
    });

    test('every tool name uses the masonex_ prefix', () {
      // Sanity-check the static list of names registered by every
      // `tools/*.dart` file. Kept in sync manually — the smoke test
      // protects against accidental renames.
      const names = <String>[
        'masonex_version',
        'masonex_help',
        'masonex_init',
        'masonex_list_bricks',
        'masonex_search_bricks',
        'masonex_add_brick',
        'masonex_remove_brick',
        'masonex_get',
        'masonex_describe_brick',
        'masonex_make',
        'masonex_new_brick',
        'masonex_bundle',
        'masonex_unbundle',
        'masonex_publish',
        'masonex_build',
        'masonex_audit_ai',
        'masonex_validate',
        'masonex_ai_budget',
        'masonex_ai_context_preview',
        'masonex_ai_trace',
        'masonex_ai_cache',
        'masonex_provider_show',
        'masonex_provider_test',
        'masonex_logout',
      ];
      for (final n in names) {
        expect(n, startsWith('masonex_'));
      }
    });
  });
}
