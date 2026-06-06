@pragma('masonex:header', {
  ProjectConfig: '{{projectName.pascalCase()}}Config',
})
library;

/// Runtime configuration for {{projectName.pascalCase()}}.
///
/// Generated from a brick that exercises every BrickVariableType.
class ProjectConfig {
  const ProjectConfig();

  /// string
  static const projectName = '{{projectName}}';

  /// number
  static const defaultDueDays = /*{{defaultDueDays}}*/ 7;

  /// boolean
  static const withReminders = /*{{withReminders}}*/ true;

  /// enum (one of: memory, sqlite, postgres)
  static const storage = Storage./*{{storage}}*/ memory;

  /// array — fixed sub-set of allowed values
  static const flavors = <String>[
    /*{{#flavors}}*/ '{{.}}', /*{{/flavors}}*/
  ];

  /// list — free-form values typed by the user
  static const defaultTags = <String>[
    /*{{#tags}}*/ '{{.}}', /*{{/tags}}*/
  ];
}

enum Storage { memory, sqlite, postgres }
