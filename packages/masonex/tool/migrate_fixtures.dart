import 'dart:io';

import 'package:path/path.dart' as p;

void main() {
  final masonexPath = Directory.current.path;
  final fixturesPath = p.join(masonexPath, 'test', 'fixtures');
  final fixturesDir = Directory(fixturesPath);

  if (!fixturesDir.existsSync()) {
    // ignore: avoid_print
    print('Fixtures directory not found at $fixturesPath');
    return;
  }

  fixturesDir.listSync(recursive: true).forEach((entity) {
    if (entity is File) {
      final ext = p.extension(entity.path);
      if (ext == '.md' ||
          ext == '.yaml' ||
          ext == '.dart' ||
          ext == '.lock' ||
          p.basename(entity.path) == 'LICENSE') {
        _migrateFile(entity);
      }
    }
  });

  // ignore: avoid_print
  print('Idempotent fixture migration (Take 6) complete.');
}

void _migrateFile(File file) {
  var content = file.readAsStringSync();
  var changed = false;

  // 1. Force cleanup any double-migration artifacts
  if (content.contains('Masonexex')) {
    content = content.replaceAll('Masonexex', 'Masonex');
    changed = true;
  }
  if (content.contains('masonexex')) {
    content = content.replaceAll('masonexex', 'masonex');
    changed = true;
  }

  // 2. Use negative lookahead to only replace 'mason' if not already followed
  // by 'ex'
  final masonRegExp = RegExp('mason(?![eE]x)');
  final masonRegExpUpper = RegExp('Mason(?![eE]x)');

  if (masonRegExpUpper.hasMatch(content)) {
    content = content.replaceAll(masonRegExpUpper, 'Masonex');
    changed = true;
  }
  if (masonRegExp.hasMatch(content)) {
    content = content.replaceAll(masonRegExp, 'masonex');
    changed = true;
  }

  // Specific fix for version
  if (content.contains('masonex: ^0.1.2') ||
      content.contains('masonex: ^0.1.0')) {
    content = content.replaceAll(
      RegExp(r'masonex: \^0\.1\.[02]'),
      'masonex: ^0.0.1',
    );
    changed = true;
  }

  if (changed) {
    file.writeAsStringSync(content);
    // ignore: avoid_print
    print('Migrated ${file.path}');
  }
}
