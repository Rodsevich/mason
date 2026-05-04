/// {{name}}
///
/// `slug` and `createdAt` were not asked of the user — `pre_gen.dart`
/// derived them from `name` and put them into `context.vars`.
class {{slug.pascalCase()}}Task {
  const {{slug.pascalCase()}}Task();

  static const slug = '{{slug}}';
  static const title = '{{name}}';
  static const createdAt = '{{createdAt}}';
}
