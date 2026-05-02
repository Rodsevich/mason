// ignore_for_file: public_member_api_docs, lines_longer_than_80_chars

import 'package:masonex/src/ai/pipeline/ai_tag_request.dart';

/// One file inside the brick's `__brick__/` directory as exposed in the
/// envelope. `included = true` means the file's content is embedded;
/// otherwise only its path is listed.
class BrickFileEntry {
  const BrickFileEntry({
    required this.path,
    required this.included,
    this.content,
  });

  final String path;
  final bool included;
  final String? content;
}

/// Per-render context passed to the [EnvelopeBuilder].
class BrickContext {
  const BrickContext({
    required this.brickName,
    required this.brickVersion,
    required this.brickDescription,
    required this.userVars,
    required this.providerName,
    required this.providerModel,
    required this.brickFiles,
    this.projectRules,
  });

  final String brickName;
  final String brickVersion;
  final String? brickDescription;
  final Map<String, dynamic> userVars;
  final String providerName;
  final String? providerModel;
  final List<BrickFileEntry> brickFiles;
  final String? projectRules;
}

/// Resolution of a previously processed AI tag, exposed under
/// `<previous_ai_resolutions>` to support style coherence (v2 mostly,
/// kept here so the envelope schema is forward compatible).
class PreviousResolution {
  const PreviousResolution({required this.tagId, required this.output});
  final String tagId;
  final String output;
}

/// Optional context to attach to a single envelope.
class TagEnvelopeExtras {
  const TagEnvelopeExtras({
    this.extraFiles = const [],
    this.extraContext,
    this.linesBefore,
    this.linesAfter,
    this.previousAttempt,
  });

  final List<BrickFileEntry> extraFiles;
  final String? extraContext;
  final String? linesBefore;
  final String? linesAfter;
  final PreviousAttempt? previousAttempt;
}

class PreviousAttempt {
  const PreviousAttempt({required this.output, required this.reason});
  final String output;
  final String reason;
}

/// The fully-built envelope, ready to be serialized to XML.
class Envelope {
  Envelope({
    required this.brickContext,
    required this.request,
    required this.expectedShape,
    required this.constraintLines,
    required this.postFilters,
    required this.authorNote,
    required this.extras,
    required this.previousResolutions,
  });

  final BrickContext brickContext;
  final AiTagRequest request;
  final String expectedShape;
  final List<String> constraintLines;
  final List<String> postFilters;
  final String? authorNote;
  final TagEnvelopeExtras extras;
  final List<PreviousResolution> previousResolutions;
}
