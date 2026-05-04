// `*plugins*` prefix: this template is rendered ONCE PER ITEM in the
// `plugins` list. The current item is exposed as `{{item}}`.

class {{item.pascalCase()}}Plugin {
  const {{item.pascalCase()}}Plugin();
  String get id => '{{item}}';
}
