// ignore_for_file: lines_longer_than_80_chars

import 'package:mustachex/mustachex.dart';
import 'package:test/test.dart';

class _UpperCase extends MustachexFilter {
  const _UpperCase();
  @override
  String get name => 'upper';
  @override
  String renderSync(String input, FilterArgs args, FilterContext ctx) =>
      input.toUpperCase();
}

class _Reverse extends MustachexFilter {
  const _Reverse();
  @override
  String get name => 'reverse';
  @override
  String renderSync(String input, FilterArgs args, FilterContext ctx) =>
      String.fromCharCodes(input.codeUnits.reversed);
}

class _RecordingDeferred extends MustachexFilter {
  _RecordingDeferred(this.responder);
  final String Function(DeferredCall call) responder;

  @override
  String get name => 'ai';
  @override
  bool get deferred => true;

  @override
  Future<Map<DeferredCallId, String>> fulfill(List<DeferredCall> calls) async {
    return {for (final c in calls) c.id: responder(c)};
  }
}

void main() {
  group('Template + filters', () {
    test('renders sync filter chain', () {
      final t = Template(
        '{{ name | upper }}',
        lenient: true,
        filters: const [_UpperCase()],
      );
      expect(t.renderString({'name': 'argentina'}), 'ARGENTINA');
    });

    test('renders dot-notation filter', () {
      final t = Template(
        '{{ name.upper() }}',
        lenient: true,
        filters: const [_UpperCase()],
      );
      expect(t.renderString({'name': 'argentina'}), 'ARGENTINA');
    });

    test('chains multiple sync filters', () {
      final t = Template(
        '{{ "hello" | upper | reverse }}',
        lenient: true,
        filters: const [_UpperCase(), _Reverse()],
      );
      expect(t.renderString(const {}), 'OLLEH');
    });

    test('literal head pre-renders inner Mustache vars', () {
      final t = Template(
        '{{ "hi {{name}}" | upper }}',
        lenient: true,
        filters: const [_UpperCase()],
      );
      expect(t.renderString({'name': 'world'}), 'HI WORLD');
    });

    test('plain Mustache tags untouched (backward compat)', () {
      final t = Template('Hello {{name}}!', lenient: true);
      expect(t.renderString({'name': 'Dash'}), 'Hello Dash!');
    });

    test('UnknownFilterError when filter not registered', () {
      final t = Template('{{ x | unknown }}', lenient: true);
      expect(
        () => t.renderString({'x': 'y'}),
        throwsA(isA<UnknownFilterError>()),
      );
    });
  });

  group('deferred filter', () {
    late _RecordingDeferred filter;

    setUp(() {
      filter = _RecordingDeferred((call) {
        return 'resolved:${call.headValue}';
      });
    });

    test('collectDeferredCalls finds calls without rendering', () {
      final t = Template(
        '{{ "campeón" | ai }} y {{ "subcampeón" | ai }}',
        lenient: true,
        filters: [filter],
      );
      final calls = t.collectDeferredCalls(const {});
      expect(calls, hasLength(2));
      expect(calls[0].headValue, 'campeón');
      expect(calls[1].headValue, 'subcampeón');
    });

    test('renderString throws when deferred resolution missing', () {
      final t = Template(
        '{{ "x" | ai }}',
        lenient: true,
        filters: [filter],
      );
      expect(
        () => t.renderString(const {}),
        throwsA(isA<MissingDeferredResolutionError>()),
      );
    });

    test('end-to-end: collect → fulfill → renderString(resolutions)',
        () async {
      final t = Template(
        'Champion: {{ "the FIFA winner" | ai | upper }}.',
        lenient: true,
        filters: [filter, const _UpperCase()],
      );
      final calls = t.collectDeferredCalls(const {});
      final resolutions = await filter.fulfill(calls);
      final out = t.renderString(const {}, resolutions: resolutions);
      // ai returns "resolved:the FIFA winner", upper turns it uppercase.
      expect(out, 'Champion: RESOLVED:THE FIFA WINNER.');
    });

    test('inline detection: own-line tag has inline=false', () {
      const src = 'before\n{{ "x" | ai }}\nafter';
      final t = Template(src, lenient: true, filters: [filter]);
      final calls = t.collectDeferredCalls(const {});
      expect(calls.single.context.inline, isFalse);
    });

    test('inline detection: mid-line tag has inline=true', () {
      const src = 'X: {{ "x" | ai }}.';
      final t = Template(src, lenient: true, filters: [filter]);
      final calls = t.collectDeferredCalls(const {});
      expect(calls.single.context.inline, isTrue);
    });
  });
}
