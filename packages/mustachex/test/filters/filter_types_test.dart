import 'package:mustachex/mustachex.dart';
import 'package:test/test.dart';

void main() {
  group('FilterCall.toSyntax', () {
    test('bare name when there are no arguments', () {
      expect(const FilterCall(name: 'uppercase').toSyntax(), 'uppercase');
    });

    test('renders positional arguments', () {
      const call = FilterCall(
        name: 'truncate',
        positional: [PvInt(10)],
      );
      expect(call.toSyntax(), 'truncate(10)');
    });

    test('renders named arguments', () {
      const call = FilterCall(
        name: 'ai',
        named: {'expect': PvIdentifier('word')},
      );
      expect(call.toSyntax(), 'ai(expect: word)');
    });

    test('renders positional and named together', () {
      const call = FilterCall(
        name: 'f',
        positional: [PvString('a')],
        named: {'n': PvInt(2)},
      );
      expect(call.toSyntax(), 'f("a", n: 2)');
    });
  });

  group('FilterArgs', () {
    test('unwraps positional and named values', () {
      const args = FilterArgs(
        positional: [PvInt(1), PvString('x')],
        named: {'flag': PvBool(true)},
      );
      expect(args.unwrappedPositional, [1, 'x']);
      expect(args.unwrappedNamed, {'flag': true});
    });

    test('defaults are empty', () {
      const args = FilterArgs();
      expect(args.unwrappedPositional, isEmpty);
      expect(args.unwrappedNamed, isEmpty);
    });
  });

  group('DeferredCallId', () {
    test('value equality and hashCode', () {
      const a = DeferredCallId('id-1');
      const b = DeferredCallId('id-1');
      const c = DeferredCallId('id-2');
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });

    test('is not equal to other types', () {
      expect(const DeferredCallId('x') == 'x', isFalse);
    });

    test('toString returns the raw value', () {
      expect(const DeferredCallId('abc').toString(), 'abc');
    });
  });

  group('error types', () {
    test('MissingDeferredResolutionError mentions id and filter', () {
      final e = MissingDeferredResolutionError(
        const DeferredCallId('id-9'),
        'ai',
      );
      expect(e.toString(), contains('id-9'));
      expect(e.toString(), contains('ai'));
    });

    test('UnknownFilterError mentions filter and tag', () {
      final e = UnknownFilterError('nope', '{{ x | nope }}');
      expect(e.toString(), contains('nope'));
      expect(e.toString(), contains('{{ x | nope }}'));
    });
  });

  group('MustachexFilter defaults', () {
    test('a sync filter returns its input unchanged by default', () {
      const filter = _PassthroughFilter();
      expect(filter.deferred, isFalse);
      expect(
        filter.renderSync(
          'value',
          const FilterArgs(),
          const FilterContext(vars: {}, line: 1, column: 1, inline: false),
        ),
        'value',
      );
    });

    test('the default fulfill throws UnimplementedError', () {
      const filter = _PassthroughFilter();
      expect(filter.fulfill(const []), throwsA(isA<UnimplementedError>()));
    });
  });

  group('FilterContext', () {
    test('exposes the provided metadata', () {
      const ctx = FilterContext(
        vars: {'name': 'Dash'},
        line: 3,
        column: 7,
        inline: true,
        currentFilePath: 'lib/a.dart',
        surroundingBefore: 'before',
        surroundingAfter: 'after',
        extras: {'brick': 'greeting'},
      );
      expect(ctx.vars['name'], 'Dash');
      expect(ctx.line, 3);
      expect(ctx.column, 7);
      expect(ctx.inline, isTrue);
      expect(ctx.currentFilePath, 'lib/a.dart');
      expect(ctx.surroundingBefore, 'before');
      expect(ctx.surroundingAfter, 'after');
      expect(ctx.extras['brick'], 'greeting');
    });
  });
}

class _PassthroughFilter extends MustachexFilter {
  const _PassthroughFilter();

  @override
  String get name => 'passthrough';
}
