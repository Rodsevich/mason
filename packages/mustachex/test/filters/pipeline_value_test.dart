import 'package:mustachex/mustachex.dart';
import 'package:test/test.dart';

void main() {
  group('PvString', () {
    test('toSyntax quotes and escapes embedded quotes', () {
      expect(const PvString('hi').toSyntax(), '"hi"');
      expect(const PvString('a"b').toSyntax(), r'"a\"b"');
    });

    test('toString returns the raw value', () {
      expect(const PvString('hi').toString(), 'hi');
    });

    test('unwrap returns the String', () {
      expect(const PvString('hi').unwrap(), 'hi');
    });
  });

  group('PvInt', () {
    test('toSyntax / toString / unwrap', () {
      const v = PvInt(42);
      expect(v.toSyntax(), '42');
      expect(v.toString(), '42');
      expect(v.unwrap(), 42);
    });
  });

  group('PvDouble', () {
    test('toSyntax / toString / unwrap', () {
      const v = PvDouble(3.5);
      expect(v.toSyntax(), '3.5');
      expect(v.toString(), '3.5');
      expect(v.unwrap(), 3.5);
    });
  });

  group('PvBool', () {
    test('toSyntax / toString / unwrap', () {
      expect(const PvBool(true).toSyntax(), 'true');
      expect(const PvBool(false).toString(), 'false');
      expect(const PvBool(true).unwrap(), isTrue);
    });
  });

  group('PvDuration', () {
    test('renders whole hours as Nh', () {
      expect(const PvDuration(Duration(hours: 2)).toSyntax(), '2h');
    });

    test('renders whole minutes as Nm', () {
      expect(const PvDuration(Duration(minutes: 5)).toSyntax(), '5m');
    });

    test('falls back to seconds', () {
      expect(const PvDuration(Duration(seconds: 90)).toSyntax(), '90s');
      expect(const PvDuration(Duration(seconds: 3)).toSyntax(), '3s');
    });

    test('toString mirrors toSyntax and unwrap returns the Duration', () {
      const v = PvDuration(Duration(hours: 1));
      expect(v.toString(), '1h');
      expect(v.unwrap(), const Duration(hours: 1));
    });
  });

  group('PvIdentifier', () {
    test('toSyntax / toString / unwrap return the bare identifier', () {
      const v = PvIdentifier('name');
      expect(v.toSyntax(), 'name');
      expect(v.toString(), 'name');
      expect(v.unwrap(), 'name');
    });
  });

  group('PvList', () {
    const list = PvList([PvInt(1), PvString('x'), PvBool(true)]);

    test('toSyntax renders each element syntactically', () {
      expect(list.toSyntax(), '[1, "x", true]');
    });

    test('toString renders element toStrings', () {
      expect(list.toString(), '[1, x, true]');
    });

    test('unwrap returns a List of unwrapped values', () {
      expect(list.unwrap(), [1, 'x', true]);
    });

    test('empty list', () {
      expect(const PvList([]).toSyntax(), '[]');
      expect(const PvList([]).unwrap(), isEmpty);
    });
  });

  group('PvRange', () {
    test('contains respects both bounds', () {
      const r = PvRange(min: 2, max: 5);
      expect(r.contains(1), isFalse);
      expect(r.contains(2), isTrue);
      expect(r.contains(5), isTrue);
      expect(r.contains(6), isFalse);
    });

    test('open-ended ranges', () {
      expect(const PvRange(min: 2).contains(100), isTrue);
      expect(const PvRange(min: 2).contains(1), isFalse);
      expect(const PvRange(max: 5).contains(-10), isTrue);
      expect(const PvRange(max: 5).contains(6), isFalse);
    });

    test('toSyntax for closed and open ranges', () {
      expect(const PvRange(min: 1, max: 3).toSyntax(), '1..3');
      expect(const PvRange(min: 2).toSyntax(), '>=2');
      expect(const PvRange(max: 5).toSyntax(), '<=5');
    });

    test('toString mirrors toSyntax and unwrap returns itself', () {
      const r = PvRange(min: 1, max: 3);
      expect(r.toString(), '1..3');
      expect(r.unwrap(), same(r));
    });

    test('asserts at least one bound', () {
      expect(() => PvRange(), throwsA(isA<AssertionError>()));
    });
  });

  group('PvRegex', () {
    test('toSyntax / toString render /pattern/flags', () {
      const v = PvRegex(r'\d+', 'i');
      expect(v.toSyntax(), r'/\d+/i');
      expect(v.toString(), r'/\d+/i');
    });

    test('toRegExp honors flags', () {
      final ci = const PvRegex('abc', 'i').toRegExp();
      expect(ci.isCaseSensitive, isFalse);
      expect(ci.hasMatch('ABC'), isTrue);

      final plain = const PvRegex('abc', '').toRegExp();
      expect(plain.isCaseSensitive, isTrue);
      expect(plain.isMultiLine, isFalse);

      final ms = const PvRegex('a', 'ms').toRegExp();
      expect(ms.isMultiLine, isTrue);
      expect(ms.isDotAll, isTrue);

      final uni = const PvRegex('a', 'u').toRegExp();
      expect(uni.isUnicode, isTrue);
    });

    test('unwrap returns a compiled RegExp', () {
      final v = const PvRegex(r'\w', '').unwrap();
      expect(v, isA<RegExp>());
      expect((v as RegExp).hasMatch('a'), isTrue);
    });
  });
}
