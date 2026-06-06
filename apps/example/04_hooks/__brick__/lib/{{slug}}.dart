@pragma('masonex:header', {
  SlugTask: '{{slug.pascalCase()}}Task',
})
library;

/// {{name}}
///
/// `slug` and `createdAt` were not asked of the user — `pre_gen.dart`
/// derived them from `name` and put them into `context.vars`.
class SlugTask {
  const SlugTask();

  static const slug = '{{slug}}';
  static const title = '{{name}}';
  static const createdAt = '{{createdAt}}';
}
