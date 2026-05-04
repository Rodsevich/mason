import 'dart:io';

import 'package:masonex/masonex.dart';

/// Renders the local `07_workspace/bricks/task` brick into the
/// directory passed as the first CLI argument.
///
/// Usage: `dart run bin/render.dart /tmp/taskflow_prog`
Future<void> main(List<String> args) async {
  final outDir = Directory(args.isNotEmpty ? args.first : '/tmp/taskflow_prog');
  outDir.createSync(recursive: true);

  // Three ways to declare a brick — pick one:
  //
  // (a) Local path (used here):
  final brick = Brick.path('../07_workspace/bricks/task');
  //
  // (b) Git source:
  // final brick = Brick.git(
  //   const GitPath(
  //     'https://github.com/felangel/mason',
  //     path: 'bricks/widget',
  //   ),
  // );
  //
  // (c) Hosted on brickhub.dev:
  // final brick = Brick(
  //   name: 'greeting',
  //   location: const BrickLocation(version: '^0.1.0'),
  // );

  final generator = await MasonexGenerator.fromBrick(brick);
  final target = DirectoryGeneratorTarget(outDir);

  final files = await generator.generate(
    target,
    vars: const <String, dynamic>{'name': 'AuditOrders'},
    fileConflictResolution: FileConflictResolution.overwrite,
  );

  stdout.writeln('Generated ${files.length} file(s) into ${outDir.path}:');
  for (final f in files) {
    stdout.writeln('  ${f.status.name.padRight(10)} ${f.path}');
  }
}
