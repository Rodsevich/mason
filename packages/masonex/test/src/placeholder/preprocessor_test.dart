// ignore_for_file: lines_longer_than_80_chars

import 'package:masonex/src/placeholder/errors.dart';
import 'package:masonex/src/placeholder/preprocessor.dart';
import 'package:test/test.dart';

void main() {
  group('preprocessPlaceholderDart', () {
    test('returns source unchanged when no markers are present', () {
      const source = '''
class Foo {
  void bar() {}
}
''';
      expect(preprocessPlaceholderDart(source), source);
    });

    group('inline form', () {
      test('substitutes a single class identifier', () {
        const source = '''
class /*{{className}}*/ Foo {}
''';
        const expected = '''
class {{className}} {}
''';
        expect(preprocessPlaceholderDart(source), expected);
      });

      test('handles filter pipelines inside the placeholder', () {
        const source = '''
class /*{{className.pascalCase()}}*/ Foo {
  void /*{{methodName.camelCase()}}*/ doStuff() {}
}
''';
        const expected = '''
class {{className.pascalCase()}} {
  void {{methodName.camelCase()}}() {}
}
''';
        expect(preprocessPlaceholderDart(source), expected);
      });

      test('passes through section sigils', () {
        const source = '''
class Foo {
  /*{{#fields}}*/
  final String /*{{name}}*/ field;
  /*{{/fields}}*/
}
''';
        const expected = '''
class Foo {
  {{#fields}}
  final String {{name}};
  {{/fields}}
}
''';
        expect(preprocessPlaceholderDart(source), expected);
      });

      test('passes through inverse and triple-mustache', () {
        const source = '''
class Foo {
  /*{{^empty}}*/
  String /*{{{description}}}*/ name = '';
  /*{{/empty}}*/
}
''';
        // Triple-mustache is passthrough per RFC §3.2 — the comment
        // delimiters are stripped but the next token is NOT consumed.
        const expected = '''
class Foo {
  {{^empty}}
  String {{{description}}} name = '';
  {{/empty}}
}
''';
        expect(preprocessPlaceholderDart(source), expected);
      });

      test('falls back to passthrough when no stand-in token follows', () {
        const source = '''
void main() {
  foo(/*{{argName}}*/);
}
''';
        const expected = '''
void main() {
  foo({{argName}});
}
''';
        expect(preprocessPlaceholderDart(source), expected);
      });

      test('substitutes the {{.}} dot tag inside an iteration', () {
        const source = '''
class Stats {
  /*{{#estadisticos}}*/
  final String /*{{.}}*/ name;
  /*{{/estadisticos}}*/
}
''';
        const expected = '''
class Stats {
  {{#estadisticos}}
  final String {{.}};
  {{/estadisticos}}
}
''';
        expect(preprocessPlaceholderDart(source), expected);
      });

      test('does not match comments inside string literals', () {
        const source = '''
class Foo {
  static const note = '/*{{notARealTag}}*/';
}
''';
        // Source starts with the inline marker only inside the string
        // literal, so the preprocessor still tries (looksLike returns true)
        // but the analyzer sees STRING content, not a comment, so nothing
        // is rewritten.
        expect(preprocessPlaceholderDart(source), source);
      });

      test('substitutes a string-literal stand-in', () {
        const source = '''
const id = /*{{name | snakeCase}}*/ 'placeholder';
''';
        const expected = '''
const id = {{name | snakeCase}};
''';
        expect(preprocessPlaceholderDart(source), expected);
      });
    });

    group('pragma form', () {
      test('rewrites identifier tokens inside masonex:header scope', () {
        const source = '''
@pragma('masonex:header', {
  'ClassName': '{{className.pascalCase()}}',
  'methodName': '{{methodName.camelCase()}}',
})
library;

class ClassName {
  void methodName() {}
}
''';
        const expected = 'class {{className.pascalCase()}} {\n'
            '  void {{methodName.camelCase()}}() {}\n'
            '}\n';
        expect(preprocessPlaceholderDart(source), expected);
      });

      test('rewrites keyword tokens inside masonex:replace scope', () {
        const source = '''
class Stats {
  @pragma('masonex:replace', {
    'final': '{{modifier}}',
    'int': '{{type}}',
    'varName': '{{name}}',
  })
  final int varName = 0;
}
''';
        const expected = '''
class Stats {
  {{modifier}} {{type}} {{name}} = 0;
}
''';
        expect(preprocessPlaceholderDart(source), expected);
      });

      test('accepts unquoted Type literals as keys', () {
        const source = '''
@pragma('masonex:header', {
  BlocXState: 'Bloc{{name.pascalCase()}}State',
  BlocXEvent: 'Bloc{{name.pascalCase()}}Event',
  BlocX: 'Bloc{{name.pascalCase()}}Bloc',
})
library;

abstract class BlocXState {}
abstract class BlocXEvent {}

class BlocX {}
''';
        const expected = 'abstract class Bloc{{name.pascalCase()}}State {}\n'
            'abstract class Bloc{{name.pascalCase()}}Event {}\n'
            '\n'
            'class Bloc{{name.pascalCase()}}Bloc {}\n';
        expect(preprocessPlaceholderDart(source), expected);
      });

      test('does not rewrite tokens inside string literals', () {
        const source = '''
@pragma('masonex:header', {
  'final': '{{modifier}}',
})
library;

class Foo {
  static const note = 'this final stays';
}
''';
        const expected = 'class Foo {\n'
            "  static const note = 'this final stays';\n"
            '}\n';
        expect(preprocessPlaceholderDart(source), expected);
      });

      test('throws PlaceholderPragmaShapeError on non-Map second argument', () {
        const source = '''
@pragma('masonex:header', 'not a map')
library;

class Foo {}
''';
        expect(
          () => preprocessPlaceholderDart(source),
          throwsA(isA<PlaceholderPragmaShapeError>()),
        );
      });

      test('throws PlaceholderPragmaShapeError on non-tag string value', () {
        const source = '''
@pragma('masonex:header', {
  'Foo': 'no tag here',
})
library;

class Foo {}
''';
        expect(
          () => preprocessPlaceholderDart(source),
          throwsA(isA<PlaceholderPragmaShapeError>()),
        );
      });
    });

    group('mixed forms', () {
      test('pragma + inline together', () {
        const source = '''
@pragma('masonex:header', {
  ClassName: '{{className.pascalCase()}}',
})
library;

class ClassName {
  /*{{#methods}}*/
  void /*{{name.camelCase()}}*/ method() {}
  /*{{/methods}}*/
}
''';
        const expected = 'class {{className.pascalCase()}} {\n'
            '  {{#methods}}\n'
            '  void {{name.camelCase()}}() {}\n'
            '  {{/methods}}\n'
            '}\n';
        expect(preprocessPlaceholderDart(source), expected);
      });
    });

    group('parse errors', () {
      test('throws PlaceholderParseError on syntactically invalid Dart', () {
        const source = '''
@pragma('masonex:header', { 'X': '{{x}}' })
library;

class { broken
''';
        expect(
          () => preprocessPlaceholderDart(source),
          throwsA(isA<PlaceholderParseError>()),
        );
      });
    });
  });
}
