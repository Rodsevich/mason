import 'dart:io';
import 'package:path/path.dart' as p;

/// Resolves the path to a brick by its name.
///
/// It correctly handles execution from both the package root
/// (`packages/masonex`) and the workspace root.
String getBrickPath(String brickName) {
  final cwd = Directory.current.path;

  // Case 1: Running from packages/masonex
  final path1 = p.join(cwd, '..', '..', 'bricks', brickName);
  if (Directory(path1).existsSync()) {
    return p.normalize(path1);
  }

  // Case 2: Running from workspace root
  final path2 = p.join(cwd, 'bricks', brickName);
  if (Directory(path2).existsSync()) {
    return p.normalize(path2);
  }

  // Case 3: Searching up for the bricks folder
  var current = Directory(cwd);
  while (current.path != current.parent.path) {
    final potential = p.join(current.path, 'bricks', brickName);
    if (Directory(potential).existsSync()) {
      return p.normalize(potential);
    }
    current = current.parent;
  }

  throw Exception(
    'Could not find brick "$brickName".\n'
    'Attempted to look relative to CWD: $cwd',
  );
}

/// Resolves the path to a fixture by its name.
///
/// It correctly handles execution from both the package root
/// (`packages/masonex`) and the workspace root.
String getFixturePath(List<String> parts) {
  final cwd = Directory.current.path;

  // Case 1: Running from packages/masonex
  final path1 = p.joinAll([cwd, 'test', 'fixtures', ...parts]);
  if (FileSystemEntity.isFileSync(path1) ||
      FileSystemEntity.isDirectorySync(path1)) {
    return p.normalize(path1);
  }

  // Case 2: Running from workspace root
  final path2 = p.joinAll([cwd, 'packages', 'masonex', 'test', 'fixtures', ...parts]);
  if (FileSystemEntity.isFileSync(path2) ||
      FileSystemEntity.isDirectorySync(path2)) {
    return p.normalize(path2);
  }

  // Case 3: Searching up for the packages/masonex/test/fixtures folder
  var current = Directory(cwd);
  while (current.path != current.parent.path) {
    final potential = p.joinAll([
      current.path,
      'packages',
      'masonex',
      'test',
      'fixtures',
      ...parts,
    ]);
    if (FileSystemEntity.isFileSync(potential) ||
        FileSystemEntity.isDirectorySync(potential)) {
      return p.normalize(potential);
    }
    current = current.parent;
  }

  throw Exception(
    'Could not find fixture "${parts.join('/')}".\n'
    'Attempted to look relative to CWD: $cwd',
  );
}

/// Resolves the path to a bundle by its name.
///
/// It correctly handles execution from both the package root
/// (`packages/masonex`) and the workspace root.
String getBundlePath(String bundleName) {
  final cwd = Directory.current.path;

  // Case 1: Running from packages/masonex
  final path1 = p.join(cwd, 'test', 'bundles', bundleName);
  if (File(path1).existsSync()) {
    return p.normalize(path1);
  }
  final path1cli = p.join(cwd, 'test', 'cli', 'bundles', bundleName);
  if (File(path1cli).existsSync()) {
    return p.normalize(path1cli);
  }
  final path1root = p.join(cwd, bundleName);
  if (File(path1root).existsSync()) {
    return p.normalize(path1root);
  }

  // Case 2: Running from workspace root
  final path2 = p.join(cwd, 'packages', 'masonex', 'test', 'bundles', bundleName);
  if (File(path2).existsSync()) {
    return p.normalize(path2);
  }
  final path2cli = p.join(cwd, 'packages', 'masonex', 'test', 'cli', 'bundles', bundleName);
  if (File(path2cli).existsSync()) {
    return p.normalize(path2cli);
  }

  // Case 3: Searching up for the bundle
  var current = Directory(cwd);
  while (current.path != current.parent.path) {
    for (final sub in [
      p.join('packages', 'masonex', 'test', 'bundles'),
      p.join('packages', 'masonex', 'test', 'cli', 'bundles'),
      p.join('packages', 'masonex'),
    ]) {
      final potential = p.join(current.path, sub, bundleName);
      if (File(potential).existsSync()) {
        return p.normalize(potential);
      }
    }
    current = current.parent;
  }

  throw Exception(
    'Could not find bundle "$bundleName".\n'
    'Attempted to look relative to CWD: $cwd',
  );
}
