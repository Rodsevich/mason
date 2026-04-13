import 'package:build_verify/build_verify.dart';
import 'package:test/test.dart';

void main() {
  test(
    'ensure_build',
    tags: 'pull-request-only',
    () => expectBuildClean(
      packageRelativeDirectory: 'packages/masonex',
    ),
    timeout: const Timeout.factor(4),
  );
}
