import 'package:masonex/masonex.dart';

/// Runs before any file is generated.
///
/// We normalize `name` into a `slug`, stamp `createdAt`, and let the
/// templates consume both as if the user had typed them.
void run(HookContext context) {
  final name = (context.vars['name'] as String?) ?? 'untitled';
  final slug = name
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');

  context.vars['slug'] = slug;
  context.vars['createdAt'] = DateTime.now().toUtc().toIso8601String();

  context.logger.info('[pre_gen] normalized name -> $slug');
}
