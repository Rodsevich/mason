@pragma('masonex:header', {
  ItemPlugin: '{{item.pascalCase()}}Plugin',
})
library;

// `*plugins*` prefix: this template is rendered ONCE PER ITEM in the
// `plugins` list. The current item is exposed as `{{item}}`.

class ItemPlugin {
  const ItemPlugin();
  String get id => '{{item}}';
}
