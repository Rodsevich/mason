/// A single unit of work in the taskflow domain.
class {{name.pascalCase()}} {
  const {{name.pascalCase()}}({required this.id, required this.title});

  final String id;
  final String title;

  @override
  String toString() => '{{name.pascalCase()}}($id, "$title")';
}
