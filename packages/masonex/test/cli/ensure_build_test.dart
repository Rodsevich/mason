import 'dart:io';
import 'package:build_verify/build_verify.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  test(
    'ensure_build',
    tags: 'pull-request-only',
    () => expectBuildClean(
      packageRelativeDirectory:
          path.join(Directory.current.path).contains('packages/masonex')
              ? ''
              : 'packages/masonex',
    ),
  );
}
