import 'dart:io';

import 'package:masonex/masonex.dart';

/// Runs after every template file has been written.
///
/// Records the generated task slug in a sibling log file so a human can
/// later see what was scaffolded.
void run(HookContext context) {
  final slug = context.vars['slug'] as String? ?? '?';
  final createdAt = context.vars['createdAt'] as String? ?? '?';
  File('.taskflow_log').writeAsStringSync(
    '$createdAt\t$slug\n',
    mode: FileMode.append,
  );
  context.logger.success('[post_gen] task $slug registered');
}
