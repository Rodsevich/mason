import 'dart:async';
import 'dart:convert';

import 'package:mason_logger/src/io.dart';
import 'package:mason_logger/src/progress.dart';
import 'package:meta/meta.dart';
import 'package:universal_io/io.dart' as io;

const _asyncRunZoned = runZoned;

// TODO(felangel): remove when IOOverrides stdout/stdin is available in stable, https://github.com/dart-lang/sdk/commit/0d6c343196ea216cfb1eecc9e4f5c4cdedcdd52f
/// This class facilitates overriding [io.stdout] and [io.stdin].
/// It should be extended by another class in client code with overrides
/// that construct a custom implementation.
@visibleForTesting
abstract class StdioOverrides {
  static final _token = Object();

  /// Returns the current [StdioOverrides] instance.
  ///
  /// This will return `null` if the current [Zone] does not contain
  /// any [StdioOverrides].
  ///
  /// See also:
  /// * [StdioOverrides.runZoned] to provide [StdioOverrides]
  /// in a fresh [Zone].
  ///
  static StdioOverrides? get current {
    return Zone.current[_token] as StdioOverrides?;
  }

  /// Runs [body] in a fresh [Zone] using the provided overrides.
  static R runZoned<R>(
    R Function() body, {
    io.Stdout Function()? stdout,
    io.Stdin Function()? stdin,
  }) {
    final overrides = _StdioOverridesScope(stdout, stdin);
    return _asyncRunZoned(body, zoneValues: {_token: overrides});
  }

  /// The [io.Stdout] that will be used within the current [Zone].
  io.Stdout get stdout => io.stdout;

  /// The [io.Stdin] that will be used within the current [Zone].
  io.Stdin get stdin => io.stdin;
}

class _StdioOverridesScope extends StdioOverrides {
  _StdioOverridesScope(this._stdout, this._stdin);

  final StdioOverrides? _previous = StdioOverrides.current;
  final io.Stdout Function()? _stdout;
  final io.Stdin Function()? _stdin;

  @override
  io.Stdout get stdout {
    return _stdout?.call() ?? _previous?.stdout ?? super.stdout;
  }

  @override
  io.Stdin get stdin {
    return _stdin?.call() ?? _previous?.stdin ?? super.stdin;
  }
}

/// A basic Logger which wraps `stdio` and applies various styles.
class Logger {
  final _queue = <String?>[];
  final StdioOverrides? _overrides = StdioOverrides.current;

  io.Stdout get _stdout => _overrides?.stdout ?? io.stdout;
  io.Stdin get _stdin => _overrides?.stdin ?? io.stdin;

  /// Flushes internal message queue.
  void flush([Function(String?)? print]) {
    final writeln = print ?? info;
    for (final message in _queue) {
      writeln(message);
    }
    _queue.clear();
  }

  /// Write message via `stdout.write`.
  void write(String? message) => _stdout.write(message);

  /// Writes info message to stdout.
  void info(String? message) => _stdout.writeln(message);

  /// Writes delayed message to stdout.
  void delayed(String? message) => _queue.add(message);

  /// Writes progress message to stdout.
  Progress progress(String message) {
    return Progress(message, _stdout);
  }

  /// Writes error message to stdout.
  void err(String? message) => _stdout.writeln(lightRed.wrap(message));

  /// Writes alert message to stdout.
  void alert(String? message) {
    _stdout.writeln(lightCyan.wrap(styleBold.wrap(message)));
  }

  /// Writes detail message to stdout.
  void detail(String? message) => _stdout.writeln(darkGray.wrap(message));

  /// Writes warning message to stdout.
  void warn(String? message, {String tag = 'WARN'}) {
    _stdout.writeln(yellow.wrap(styleBold.wrap('[$tag] $message')));
  }

  /// Writes success message to stdout.
  void success(String? message) => _stdout.writeln(lightGreen.wrap(message));

  /// Prompts user and returns response.
  /// Provide a default value via [defaultValue].
  /// Set [hidden] to `true` if you want to hide user input for sensitive info.
  String prompt(String? message, {Object? defaultValue, bool hidden = false}) {
    final hasDefault = defaultValue != null && '$defaultValue'.isNotEmpty;
    final _defaultValue = hasDefault ? '$defaultValue' : '';
    final suffix = hasDefault ? ' ${darkGray.wrap('($_defaultValue)')}' : '';
    final _message = '$message$suffix ';
    _stdout.write(_message);
    final input =
        hidden ? _readLineHiddenSync() : _stdin.readLineSync()?.trim();
    final response = input == null || input.isEmpty ? _defaultValue : input;
    final lines = _message.split('\n').length - 1;
    final prefix =
        lines > 1 ? '\x1b[A\u001B[2K\u001B[${lines}A' : '\x1b[A\u001B[2K';
    _stdout.writeln(
      '''$prefix$_message${styleDim.wrap(lightCyan.wrap(hidden ? '******' : response))}''',
    );
    return response;
  }

  /// Prompts user with a yes/no question.
  bool confirm(String? message, {bool defaultValue = false}) {
    final suffix = ' ${darkGray.wrap('(${defaultValue.toYesNo()})')}';
    final _message = '$message$suffix ';
    _stdout.write(_message);
    final input = _stdin.readLineSync()?.trim();
    final response = input == null || input.isEmpty
        ? defaultValue
        : input.toBoolean() ?? defaultValue;
    final lines = _message.split('\n').length - 1;
    final prefix =
        lines > 1 ? '\x1b[A\u001B[2K\u001B[${lines}A' : '\x1b[A\u001B[2K';
    _stdout.writeln(
      '''$prefix$_message${styleDim.wrap(lightCyan.wrap(response ? 'Yes' : 'No'))}''',
    );
    return response;
  }

  /// Prompts user with [message] to choose one value from the provided
  /// [choices].
  ///
  /// An optional [defaultValue] can be specified.
  /// The [defaultValue] must be one of the provided [choices].
  String chooseOne(
    String? message, {
    required List<String> choices,
    String? defaultValue,
  }) {
    const upKey = [27, 91, 65];
    const downKey = [27, 91, 66];
    const enterKey = [10];

    final hasDefault = defaultValue != null && defaultValue.isNotEmpty;
    var index = hasDefault ? choices.indexOf(defaultValue) : 0;

    void writeChoices() {
      _stdout
        // save cursor
        ..write('\x1b7')
        // hide cursor
        ..write('\x1b[?25l')
        ..writeln('$message');

      for (final choice in choices) {
        final isCurrent = choices.indexOf(choice) == index;
        final checkBox = isCurrent ? lightCyan.wrap('◉') : '◯';
        if (isCurrent) {
          _stdout
            ..write(green.wrap('❯'))
            ..write(' $checkBox ${lightCyan.wrap(choice)}');
        } else {
          _stdout
            ..write(' ')
            ..write(' $checkBox $choice');
        }
        if (choices.last != choice) {
          _stdout.write('\n');
        }
      }
    }

    _stdin
      ..lineMode = false
      ..echoMode = false;

    writeChoices();

    final event = <int>[];
    var result = '';
    while (result.isEmpty) {
      final byte = _stdin.readByteSync();
      if (event.length == 3) event.clear();
      event.add(byte);
      if (upKey.every(event.contains)) {
        event.clear();
        index = (index - 1) % (choices.length);
      } else if (downKey.every(event.contains)) {
        event.clear();
        index = (index + 1) % (choices.length);
      } else if (enterKey.every(event.contains)) {
        _stdin
          ..lineMode = true
          ..echoMode = true;

        _stdout
          // restore cursor
          ..write('\x1b8')
          // clear to end of screen
          ..write('\x1b[J')
          // show cursor
          ..write('\x1b[?25h')
          ..write('$message ')
          ..writeln(styleDim.wrap(lightCyan.wrap(choices[index])));

        result = choices[index];
        break;
      }

      // restore cursor
      _stdout.write('\x1b8');
      writeChoices();
    }

    return result;
  }

  String _readLineHiddenSync() {
    const lineFeed = 10;
    const carriageReturn = 13;
    const delete = 127;
    final value = <int>[];

    try {
      _stdin
        ..echoMode = false
        ..lineMode = false;
      int char;
      do {
        char = _stdin.readByteSync();
        if (char != lineFeed && char != carriageReturn) {
          final shouldDelete = char == delete && value.isNotEmpty;
          shouldDelete ? value.removeLast() : value.add(char);
        }
      } while (char != lineFeed && char != carriageReturn);
    } finally {
      _stdin
        ..lineMode = true
        ..echoMode = true;
    }
    _stdout.writeln();
    return utf8.decode(value);
  }
}

extension on bool {
  String toYesNo() {
    return this == true ? 'Y/n' : 'y/N';
  }
}

extension on String {
  bool? toBoolean() {
    switch (toLowerCase()) {
      case 'y':
      case 'yea':
      case 'yeah':
      case 'yep':
      case 'yes':
      case 'yup':
        return true;
      case 'n':
      case 'no':
      case 'nope':
        return false;
      default:
        return null;
    }
  }
}
