import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Result of a single masonex CLI invocation.
class MasonexResult {
  const MasonexResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
    required this.durationMs,
    required this.timedOut,
    required this.command,
  });

  final int exitCode;
  final String stdout;
  final String stderr;
  final int durationMs;
  final bool timedOut;
  final List<String> command;

  bool get success => exitCode == 0 && !timedOut;

  Map<String, Object?> toJson() => {
        'exitCode': exitCode,
        'timedOut': timedOut,
        'durationMs': durationMs,
        'command': command,
        'stdout': stdout,
        'stderr': stderr,
      };
}

/// Function signature used to actually spawn a process. Injected so tests
/// can swap the implementation without launching real binaries.
typedef ProcessSpawner = Future<Process> Function(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
  Map<String, String>? environment,
  bool runInShell,
});

/// Thin wrapper around the `masonex` binary. Handles working directory,
/// environment, timeouts, and stream collection.
class MasonexRunner {
  MasonexRunner({
    String? executable,
    String? defaultWorkingDirectory,
    Map<String, String>? defaultEnvironment,
    Duration defaultTimeout = const Duration(minutes: 2),
    ProcessSpawner? spawner,
  })  : _executable = executable ?? 'masonex',
        _defaultWorkingDirectory = defaultWorkingDirectory,
        _defaultEnvironment = defaultEnvironment,
        _defaultTimeout = defaultTimeout,
        _spawner = spawner ?? _defaultSpawner;

  final String _executable;
  final String? _defaultWorkingDirectory;
  final Map<String, String>? _defaultEnvironment;
  final Duration _defaultTimeout;
  final ProcessSpawner _spawner;

  String get executable => _executable;

  String? get defaultWorkingDirectory => _defaultWorkingDirectory;

  static Future<Process> _defaultSpawner(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool runInShell = false,
  }) {
    return Process.start(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      environment: environment,
      runInShell: runInShell,
    );
  }

  /// Runs masonex with the given [args]. Returns a [MasonexResult] even when
  /// the process exits with a non-zero code — callers decide how to surface
  /// failures.
  Future<MasonexResult> run(
    List<String> args, {
    String? workingDirectory,
    Map<String, String>? environment,
    Duration? timeout,
  }) async {
    final cwd = workingDirectory ?? _defaultWorkingDirectory;
    final env = <String, String>{
      ...?_defaultEnvironment,
      ...?environment,
    };
    final effectiveTimeout = timeout ?? _defaultTimeout;
    final stopwatch = Stopwatch()..start();
    final command = [_executable, ...args];

    Process process;
    try {
      process = await _spawner(
        _executable,
        args,
        workingDirectory: cwd,
        environment: env.isEmpty ? null : env,
      );
    } on ProcessException catch (e) {
      stopwatch.stop();
      return MasonexResult(
        exitCode: 127,
        stdout: '',
        stderr: 'Failed to spawn $_executable: ${e.message}',
        durationMs: stopwatch.elapsedMilliseconds,
        timedOut: false,
        command: command,
      );
    }

    final stdoutBuffer = StringBuffer();
    final stderrBuffer = StringBuffer();

    final stdoutFuture = process.stdout
        .transform(utf8.decoder)
        .forEach(stdoutBuffer.write);
    final stderrFuture = process.stderr
        .transform(utf8.decoder)
        .forEach(stderrBuffer.write);

    var timedOut = false;
    final exitCodeFuture = process.exitCode;
    final timer = Timer(effectiveTimeout, () {
      timedOut = true;
      process.kill(ProcessSignal.sigterm);
    });

    final exitCode = await exitCodeFuture;
    timer.cancel();
    await Future.wait([stdoutFuture, stderrFuture]);
    stopwatch.stop();

    return MasonexResult(
      exitCode: exitCode,
      stdout: stdoutBuffer.toString(),
      stderr: stderrBuffer.toString(),
      durationMs: stopwatch.elapsedMilliseconds,
      timedOut: timedOut,
      command: command,
    );
  }
}
