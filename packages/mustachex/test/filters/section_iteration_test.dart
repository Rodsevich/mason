// ignore_for_file: lines_longer_than_80_chars

import 'package:mustachex/mustachex.dart';
import 'package:test/test.dart';

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
  group('section iteration with deferred filter', () {
    test('iterates section: 1 deferred call per iteration with distinct ids', () {
      const src = '{{#items}}{{ "fetch {{.}}" | ai }}\n{{/items}}';
      final ai = _RecordingDeferred((c) => 'resolved:${c.headValue}');
      final t = Template(src, lenient: true, filters: [ai]);
      final calls = t.collectDeferredCalls({
        'items': ['poblacion', 'superficie'],
      });
      expect(calls, hasLength(2));
      expect(calls[0].headValue, 'fetch poblacion');
      expect(calls[1].headValue, 'fetch superficie');
      // Distinct ids per iteration.
      expect(calls[0].id, isNot(equals(calls[1].id)));
    });

    test('end-to-end: section + outer scope vars + deferred ai', () async {
      const src =
          '{{#stats}}{{.}}: {{ "buscar {{.}} para {{country}}" | ai(expect: word) }}\n{{/stats}}';
      final answers = {
        'buscar poblacion para Argentina': '45.500.000',
        'buscar superficie para Argentina': '2.756.000',
      };
      final ai = _RecordingDeferred(
        (c) => answers[c.headValue] ?? 'UNMATCHED',
      );
      final t = Template(src, lenient: true, filters: [ai]);
      final vars = {
        'country': 'Argentina',
        'stats': ['poblacion', 'superficie'],
      };
      final calls = t.collectDeferredCalls(vars);
      final resolutions = await ai.fulfill(calls);
      final out = t.renderString(vars, resolutions: resolutions);
      expect(
        out.trim(),
        'poblacion: 45.500.000\n'
        'superficie: 2.756.000',
      );
    });

    test('inner Mustache resolves dotted accessors inside literal head', () {
      const src =
          '{{#cities}}{{ "city: {{name}}" | ai }}\n{{/cities}}';
      final ai = _RecordingDeferred((c) => c.headValue.toUpperCase());
      final t = Template(src, lenient: true, filters: [ai]);
      final calls = t.collectDeferredCalls({
        'cities': [
          {'name': 'Buenos Aires'},
          {'name': 'Córdoba'},
        ],
      });
      expect(calls.map((c) => c.headValue).toList(), [
        'city: Buenos Aires',
        'city: Córdoba',
      ]);
    });

    test('regex matches {{.}} inside a literal head', () {
      const src =
          '{{#xs}}{{ "got {{.}}" | ai }}\n{{/xs}}';
      final ai = _RecordingDeferred((c) => c.headValue);
      final t = Template(src, lenient: true, filters: [ai]);
      final calls = t.collectDeferredCalls({
        'xs': ['a', 'b', 'c'],
      });
      expect(
        calls.map((c) => c.headValue).toList(),
        ['got a', 'got b', 'got c'],
      );
    });

    test('inverse section skips when value is non-empty / truthy', () {
      const src = '{{^empty}}{{ "x" | ai }}{{/empty}}';
      final ai = _RecordingDeferred((c) => 'y');
      final t = Template(src, lenient: true, filters: [ai]);
      final emptyCalls = t.collectDeferredCalls({'empty': false});
      expect(emptyCalls, hasLength(1));
      final nonEmptyCalls = t.collectDeferredCalls({
        'empty': ['something'],
      });
      expect(nonEmptyCalls, isEmpty);
    });
  });
}
