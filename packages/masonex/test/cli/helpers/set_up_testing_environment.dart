import 'dart:io';

import 'package:path/path.dart' as path;

String testFixturesPath(String cwd, {String suffix = ''}) {
  var basePath = cwd;
  final fixturesPart = path.join('test', 'fixtures');
  if (basePath.contains(fixturesPart)) {
    basePath = basePath.substring(0, basePath.indexOf(fixturesPart));
  }
  return path.join(basePath, fixturesPart, suffix);
}

void setUpTestingEnvironment(String cwd, {String suffix = ''}) {
  try {
    final testDir = Directory(testFixturesPath(cwd, suffix: suffix));
    if (testDir.existsSync()) testDir.deleteSync(recursive: true);
    testDir.createSync(recursive: true);
    Directory.current = testDir.path;
    final bricksJson = File(
      path.join(Directory.current.path, '.masonex', 'bricks.json'),
    );
    if (bricksJson.existsSync()) bricksJson.deleteSync();
  } catch (_) {}
}
