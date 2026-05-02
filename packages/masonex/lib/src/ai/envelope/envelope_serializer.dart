// ignore_for_file: public_member_api_docs, lines_longer_than_80_chars

import 'package:masonex/src/ai/envelope/envelope.dart';

/// Serializes an [Envelope] to its XML representation.
///
/// The format is the user prompt sent to the AI provider. The system prompt
/// (separate) describes the meaning of each tag. Both are versioned together
/// inside masonex.
class EnvelopeSerializer {
  const EnvelopeSerializer();

  static const String envelopeVersion = '1';

  String serialize(Envelope env) {
    final buf = StringBuffer()
      ..writeln('<masonex_render_request version="$envelopeVersion">')
      ..writeln(_meta(env))
      ..writeln(_brickContents(env))
      ..writeln(_currentFile(env))
      ..writeln(_surrounding(env))
      ..writeln(_tag(env))
      ..writeln(_previousResolutions(env))
      ..writeln(_extraFiles(env))
      ..writeln(_extraContext(env))
      ..writeln(_previousAttempt(env))
      ..writeln(_task(env))
      ..writeln('</masonex_render_request>');
    return buf.toString();
  }

  String _meta(Envelope env) {
    final ctx = env.brickContext;
    final vars = ctx.userVars.entries.map((e) {
      return '    <var name="${_attr(e.key)}">${_text(e.value?.toString() ?? '')}</var>';
    }).join('\n');
    final desc = ctx.brickDescription == null
        ? ''
        : ' description="${_attr(ctx.brickDescription!)}"';
    final model = ctx.providerModel == null
        ? ''
        : ' model="${_attr(ctx.providerModel!)}"';
    return '  <meta>\n'
        '    <brick name="${_attr(ctx.brickName)}" version="${_attr(ctx.brickVersion)}"$desc/>\n'
        '    <provider name="${_attr(ctx.providerName)}"$model/>\n'
        '    <user_vars>\n$vars\n    </user_vars>\n'
        '  </meta>';
  }

  String _brickContents(Envelope env) {
    final ctx = env.brickContext;
    final files = ctx.brickFiles.map((f) {
      final inc = f.included ? 'true' : 'false';
      if (f.included && f.content != null) {
        return '    <file path="${_attr(f.path)}" included="$inc"><![CDATA['
            '${_cdata(f.content!)}'
            ']]></file>';
      }
      return '    <file path="${_attr(f.path)}" included="$inc"/>';
    }).join('\n');
    return '  <brick_contents>\n$files\n  </brick_contents>';
  }

  String _currentFile(Envelope env) {
    final r = env.request;
    final lang = _languageFor(r.relativePath);
    return '  <current_file path="${_attr(r.relativePath)}" '
        'language="${_attr(lang)}"/>';
  }

  String _surrounding(Envelope env) {
    final before = env.extras.linesBefore ?? '';
    final after = env.extras.linesAfter ?? '';
    return '  <surrounding_text>\n'
        '    <before><![CDATA[${_cdata(before)}]]></before>\n'
        '    <after><![CDATA[${_cdata(after)}]]></after>\n'
        '  </surrounding_text>';
  }

  String _tag(Envelope env) {
    final r = env.request;
    return '  <tag inline="${r.inlineHint}" '
        'original="${_attr('{{ ${r.tagOriginal} }}')}"/>';
  }

  String _previousResolutions(Envelope env) {
    if (env.previousResolutions.isEmpty) {
      return '  <previous_ai_resolutions/>';
    }
    final entries = env.previousResolutions.map((p) {
      final tagId = _attr(p.tagId);
      final cdata = _cdata(p.output);
      return '    <resolution tag_id="$tagId"><![CDATA[$cdata]]></resolution>';
    }).join('\n');
    return '  <previous_ai_resolutions>\n$entries\n'
        '  </previous_ai_resolutions>';
  }

  String _extraFiles(Envelope env) {
    if (env.extras.extraFiles.isEmpty) return '  <extra_files/>';
    final files = env.extras.extraFiles.map((f) {
      return '    <file path="${_attr(f.path)}"><![CDATA['
          '${_cdata(f.content ?? '')}'
          ']]></file>';
    }).join('\n');
    return '  <extra_files>\n$files\n  </extra_files>';
  }

  String _extraContext(Envelope env) {
    final extra = env.extras.extraContext;
    if (extra == null || extra.isEmpty) return '  <extra_context/>';
    return '  <extra_context><![CDATA[${_cdata(extra)}]]></extra_context>';
  }

  String _previousAttempt(Envelope env) {
    final pa = env.extras.previousAttempt;
    if (pa == null) return '';
    return '  <previous_attempt>\n'
        '    <output><![CDATA[${_cdata(pa.output)}]]></output>\n'
        '    <validation_error reason="${_attr(pa.reason)}"/>\n'
        '  </previous_attempt>';
  }

  String _task(Envelope env) {
    final constraintsXml = env.constraintLines.isEmpty
        ? '    <constraints/>'
        : '    <constraints>\n'
            '${env.constraintLines.map((l) => '      $l').join('\n')}\n'
            '    </constraints>';
    final post = env.postFilters.isEmpty
        ? '    <post_filters/>'
        : '    <post_filters>${_text(env.postFilters.join(','))}'
            '</post_filters>';
    final note = (env.authorNote == null || env.authorNote!.isEmpty)
        ? '    <author_note/>'
        : '    <author_note><![CDATA[${_cdata(env.authorNote!)}]]></author_note>';

    return '  <task>\n'
        '    <prompt><![CDATA[${_cdata(env.request.prompt)}]]></prompt>\n'
        '    <expected_shape>${_text(env.expectedShape)}</expected_shape>\n'
        '$constraintsXml\n$post\n$note\n'
        '  </task>';
  }

  String _languageFor(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.dart')) return 'dart';
    if (lower.endsWith('.md')) return 'markdown';
    if (lower.endsWith('.yaml') || lower.endsWith('.yml')) return 'yaml';
    if (lower.endsWith('.json')) return 'json';
    if (lower.endsWith('.ts') || lower.endsWith('.tsx')) return 'typescript';
    if (lower.endsWith('.js') || lower.endsWith('.jsx')) return 'javascript';
    if (lower.endsWith('.py')) return 'python';
    if (lower.endsWith('.html')) return 'html';
    if (lower.endsWith('.css')) return 'css';
    return 'text';
  }

  String _attr(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  String _text(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');

  String _cdata(String s) => s.replaceAll(']]>', ']]]]><![CDATA[>');
}
