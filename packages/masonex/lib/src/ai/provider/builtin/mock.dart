// ignore_for_file: public_member_api_docs, lines_longer_than_80_chars

import 'dart:io';

import 'package:masonex/src/ai/errors.dart';
import 'package:masonex/src/ai/provider/adapter.dart';
import 'package:masonex/src/ai/provider/descriptor.dart';
import 'package:masonex/src/ai/provider/invocation.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// Strict / lenient policies for the mock provider.
enum MockMode { strict, lenient }

/// A test-only provider that replays canned responses from
/// `<brickRoot>/brick_test/ai_fixtures.yaml`. Used by integration tests and
/// reproducible CI runs of bricks that contain `| ai` tags.
class MockAiProvider implements AiProviderAdapter {
  MockAiProvider({
    required this.brickRoot,
    this.mode = MockMode.strict,
  });

  final String brickRoot;
  final MockMode mode;

  @override
  AiProviderDescriptor get descriptor => const AiProviderDescriptor(
        id: 'mock',
        displayName: 'Mock (test fixtures)',
        requiredCommand: '',
        notes: 'Reads brick_test/ai_fixtures.yaml. CI default.',
      );

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<AiInvocationResult> invoke(
    AiInvocation request, {
    required Duration timeout,
  }) async {
    final fixtures = await _loadFixtures();
    final stopwatch = Stopwatch()..start();
    final tagId = _extractTagId(request.userEnvelope);
    final prompt = _extractPrompt(request.userEnvelope);

    String? matchOutput;
    String? matchedBy;
    for (final f in fixtures) {
      if (f.tagId != null && f.tagId == tagId) {
        matchOutput = f.output;
        matchedBy = 'tag_id';
        break;
      }
      if (f.match != null && prompt.contains(f.match!)) {
        matchOutput = f.output;
        matchedBy = 'match';
        break;
      }
    }
    stopwatch.stop();
    if (matchOutput != null) {
      return AiInvocationResult(
        stdout: matchOutput,
        duration: stopwatch.elapsed,
        modelReported: 'mock:$matchedBy',
      );
    }
    if (mode == MockMode.strict) {
      throw AiException(
        'No matching fixture for tag_id="$tagId" / prompt="$prompt". '
        'Add a fixture in brick_test/ai_fixtures.yaml or run with '
        'MockMode.lenient.',
      );
    }
    return AiInvocationResult(
      stdout: 'MOCK_OUTPUT',
      duration: stopwatch.elapsed,
      modelReported: 'mock:lenient',
    );
  }

  Future<List<_Fixture>> _loadFixtures() async {
    final f = File(p.join(brickRoot, 'brick_test', 'ai_fixtures.yaml'));
    if (!f.existsSync()) {
      if (mode == MockMode.strict) {
        throw AiException(
          'MockAiProvider: missing fixtures file at ${f.path}.',
        );
      }
      return [];
    }
    final raw = await f.readAsString();
    final doc = loadYaml(raw);
    if (doc is! YamlMap) {
      throw const AiException(
        'ai_fixtures.yaml top-level must be a map with `fixtures:` list.',
      );
    }
    final list = doc['fixtures'];
    if (list is! YamlList) {
      throw const AiException(
        'ai_fixtures.yaml must contain a `fixtures:` list.',
      );
    }
    return list.map<_Fixture>((entry) {
      if (entry is! YamlMap) {
        throw const AiException(
          'Each fixture entry must be a map.',
        );
      }
      return _Fixture(
        tagId: entry['tag_id']?.toString(),
        match: entry['match']?.toString(),
        output: entry['output']?.toString() ?? '',
      );
    }).toList();
  }

  static String _extractTagId(String envelopeXml) {
    // The mock looks for the original tag content's stable hash in the
    // <tag original=...> attribute. Tests can also match by `match:` substring.
    final m = RegExp('<tag inline="[^"]*" original="([^"]+)"')
        .firstMatch(envelopeXml);
    return m?.group(1) ?? '';
  }

  static String _extractPrompt(String envelopeXml) {
    final m = RegExp(r'<prompt><!\[CDATA\[(.*?)\]\]></prompt>', dotAll: true)
        .firstMatch(envelopeXml);
    return m?.group(1) ?? '';
  }
}

class _Fixture {
  _Fixture({required this.output, this.tagId, this.match});
  final String? tagId;
  final String? match;
  final String output;
}
