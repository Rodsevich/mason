
# Run @ {{projectName}}

`>>` prefix: this entry is **appended** to the end of CHANGELOG.md every
time the brick is regenerated. Run the brick twice to see two stacked
entries.

- plugins: {{#plugins}}{{.}} {{/plugins}}
- reminders: {{withReminders}}
