# 0.1.0-dev.10

- feat: `chooseOne` API

  ```dart
  final favoriteColor = logger.chooseOne(
    'What is your favorite color?',
    choices: ['red', 'green', 'blue'],
    defaultValue: 'blue',
  );
  ```

# 0.1.0-dev.9

- feat: `progress` API enhancements
  ```dart
  final progress = Logger().progress('calculating');
  try {
    await _performCalculation();
    // Complete progress successfully.
    progress.complete();
  } catch (error, stackTrace) {
    // Terminate progress unsuccessfully.
    progress.fail();
  }
  ```

# 0.1.0-dev.8

- fix: single line prompts are overwritten
  - when using `confirm` and `prompt`

# 0.1.0-dev.7

- fix: multiline prompts are outputting twice
  - when using `confirm` and `prompt`

# 0.1.0-dev.6

- feat: add `write`

# 0.1.0-dev.5

- feat: add `hidden` flag to `prompt`
- chore: upgrade to Dart 2.16

# 0.1.0-dev.4

- fix: `progress` string truncation
- feat: add `confirm`
- feat: add `defaultValue` to `prompt`
- feat: improve `progress` time style
- docs: update example and `README`

# 0.1.0-dev.3

- feat: add `tag` to `warn` call

# 0.1.0-dev.2

- test: 100% test coverage
- docs: README updates to include usage
- docs: include example

# 0.1.0-dev.1

**Dev Release**

- chore: initial package (🚧 under construction 🚧)
