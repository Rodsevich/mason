// `>>>` prefix: this file is *recursively merged* with the destination
// when it already exists. Lists keep both sides; new top-level
// declarations are appended; existing ones are kept untouched.

const enabledPlugins = <String>[
  {{#plugins}}'{{.}}',{{/plugins}}
];
