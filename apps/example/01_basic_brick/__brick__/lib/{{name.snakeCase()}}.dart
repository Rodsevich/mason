@pragma('masonex:header', {
  Task: '{{name.pascalCase()}}',
})
library;

/// A single unit of work in the taskflow domain.
class Task {
  const Task({required this.id, required this.title});

  final String id;
  final String title;

  @override
  String toString() => '{{name.pascalCase()}}($id, "$title")';
}
