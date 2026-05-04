/// Runtime configuration for {{projectName.pascalCase()}}.
///
/// Generated from a brick that exercises every BrickVariableType.
class {{projectName.pascalCase()}}Config {
  const {{projectName.pascalCase()}}Config();

  /// string
  static const projectName = '{{projectName}}';

  /// number
  static const defaultDueDays = {{defaultDueDays}};

  /// boolean
  static const withReminders = {{withReminders}};

  /// enum (one of: memory, sqlite, postgres)
  static const storage = Storage.{{storage}};

  /// array — fixed sub-set of allowed values
  static const flavors = <String>[
    {{#flavors}}'{{.}}',{{/flavors}}
  ];

  /// list — free-form values typed by the user
  static const defaultTags = <String>[
    {{#tags}}'{{.}}',{{/tags}}
  ];
}

enum Storage { memory, sqlite, postgres }
