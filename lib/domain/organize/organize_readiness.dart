import '../../models/workspace_evidence_item.dart';
import '../evidence/evidence_temporal_intent.dart';

/// Derived Organize-stage usefulness — not completeness, proof, or legality.
enum OrganizeReadinessStatus {
  notReady,
  ready,
}

/// Founder-defined initial combinations. Engineering identifiers only —
/// never shown in product UI.
enum OrganizeReadinessPattern {
  photoVoiceText,
  twoPhotosText,
  photoWitness,
  videoText,
  videoVoice,
  videoWitness,
  twoVideosText,
  twoVideosVoice,
  photoTwoVoice,
  photoTwoText,
}

/// Counts of preserved material. Attachments are additive, not qualifying.
class EvidenceComposition {
  const EvidenceComposition({
    required this.photos,
    required this.videos,
    required this.voices,
    required this.texts,
    required this.witnesses,
    required this.attachments,
  });

  final int photos;
  final int videos;
  final int voices;
  final int texts;
  final int witnesses;
  final int attachments;

  int get qualifyingCount =>
      photos + videos + voices + texts + witnesses;

  bool get isEmpty => qualifyingCount == 0 && attachments == 0;

  /// Human scan of what is preserved. Omits zero counts. No pattern letters.
  String get summary {
    final parts = <String>[
      if (photos > 0) _count(photos, 'Photo', 'Photos'),
      if (videos > 0) _count(videos, 'Video', 'Videos'),
      if (voices > 0) _count(voices, 'Voice', 'Voice'),
      if (texts > 0) _count(texts, 'Text', 'Text'),
      if (witnesses > 0) _count(witnesses, 'Witness', 'Witnesses'),
      if (attachments > 0) _count(attachments, 'Attachment', 'Attachments'),
    ];
    if (parts.isEmpty) {
      return 'Nothing preserved yet';
    }
    return parts.join(' · ');
  }

  static String _count(int n, String one, String many) {
    if (n == 1) {
      return '1 $one';
    }
    return '$n $many';
  }
}

/// One founder-defined combination, described for people not engineers.
class OrganizeReadinessExample {
  const OrganizeReadinessExample({
    required this.composition,
    required this.structure,
  });

  final String composition;
  final String structure;
}

/// Snapshot of whether Organize can provide meaningful value.
///
/// Derived on each call from the incident working set. Not an Incident field.
class OrganizeReadiness {
  const OrganizeReadiness({
    required this.status,
    required this.composition,
    required this.structureSummary,
    this.matchedPattern,
    this.matchedExample,
    this.nextUsefulMaterial,
  });

  final OrganizeReadinessStatus status;
  final EvidenceComposition composition;
  final String structureSummary;
  final OrganizeReadinessPattern? matchedPattern;
  final OrganizeReadinessExample? matchedExample;

  /// Deterministic education only — never Coach or LLM copy.
  final String? nextUsefulMaterial;

  bool get isReady => status == OrganizeReadinessStatus.ready;

  /// Initial combinations, in founder order, without A–J labels.
  static const examples = <OrganizeReadinessExample>[
    OrganizeReadinessExample(
      composition: '1 Photo + 1 Voice + 1 Text',
      structure: 'Voice/Text → Photo → Voice/Text',
    ),
    OrganizeReadinessExample(
      composition: '2 Photos + 1 Text',
      structure: 'Photo evidence + written context',
    ),
    OrganizeReadinessExample(
      composition: '1 Photo + 1 Witness',
      structure: 'Photo evidence + witness',
    ),
    OrganizeReadinessExample(
      composition: '1 Video + 1 Text',
      structure: 'Video evidence + written context',
    ),
    OrganizeReadinessExample(
      composition: '1 Video + 1 Voice',
      structure: 'Video evidence + spoken context',
    ),
    OrganizeReadinessExample(
      composition: '1 Video + 1 Witness',
      structure: 'Video evidence + witness',
    ),
    OrganizeReadinessExample(
      composition: '2 Videos + 1 Text',
      structure: 'Video evidence + written context',
    ),
    OrganizeReadinessExample(
      composition: '2 Videos + 1 Voice',
      structure: 'Video evidence + spoken context',
    ),
    OrganizeReadinessExample(
      composition: '1 Photo + 2 Voice',
      structure: 'Voice → Photo → Voice',
    ),
    OrganizeReadinessExample(
      composition: '1 Photo + 2 Text',
      structure: 'Text → Photo → Text',
    ),
  ];

  /// Assess from existing evidence kinds, existing chronology, and explicit
  /// [EvidenceTemporalIntent].
  ///
  /// [orderedCapturedEvidenceIds] is [TimelineAnchor.sequenceOrder] for
  /// Photo / Video / Voice. Notes and witness interleave using existing
  /// [WorkspaceEvidenceItem.capturedAt] / [recordedAt] / [lastPreservedAt]
  /// timestamps. Attachments never enter the structure sequence.
  ///
  /// Voice/Text with [EvidenceTemporalIntent.chronological] count as
  /// chronological qualifying material using those existing timestamps —
  /// this does not create TimelineAnchors or sequenceOrder. Voice/Text with
  /// [EvidenceTemporalIntent.context] do not satisfy chronological
  /// requirements. Null / undeclared keeps legacy kind counting.
  static OrganizeReadiness assess({
    required List<WorkspaceEvidenceItem> evidence,
    List<String> orderedCapturedEvidenceIds = const [],
  }) {
    final composition = _compositionOf(evidence);
    final sequence = _structuredSequence(
      evidence: evidence,
      orderedCapturedEvidenceIds: orderedCapturedEvidenceIds,
    );
    final structureSummary = sequence.isEmpty
        ? (composition.attachments > 0
            ? 'Supporting attachments only'
            : 'No chronological structure yet')
        : sequence.map(_roleLabel).join(' → ');

    final match = _firstMatch(composition, sequence);
    return OrganizeReadiness(
      status: match == null
          ? OrganizeReadinessStatus.notReady
          : OrganizeReadinessStatus.ready,
      composition: composition,
      structureSummary: structureSummary,
      matchedPattern: match,
      matchedExample: match == null ? null : examples[match.index],
      nextUsefulMaterial: match == null ? _hint(composition) : null,
    );
  }

  static EvidenceComposition _compositionOf(
    List<WorkspaceEvidenceItem> evidence,
  ) {
    var photos = 0;
    var videos = 0;
    var voices = 0;
    var texts = 0;
    var witnesses = 0;
    var attachments = 0;
    for (final item in evidence) {
      switch (item.kind) {
        case WorkspaceEvidenceKind.image:
          photos++;
        case WorkspaceEvidenceKind.video:
          videos++;
        case WorkspaceEvidenceKind.voice:
          if (_countsAsChronologicalVoiceOrText(item)) {
            voices++;
          }
        case WorkspaceEvidenceKind.note:
          if (_countsAsChronologicalVoiceOrText(item)) {
            texts++;
          }
        case WorkspaceEvidenceKind.witness:
          witnesses++;
        case WorkspaceEvidenceKind.attachment:
          attachments++;
      }
    }
    return EvidenceComposition(
      photos: photos,
      videos: videos,
      voices: voices,
      texts: texts,
      witnesses: witnesses,
      attachments: attachments,
    );
  }

  static List<WorkspaceEvidenceKind> _structuredSequence({
    required List<WorkspaceEvidenceItem> evidence,
    required List<String> orderedCapturedEvidenceIds,
  }) {
    final relevant = [
      for (final item in evidence)
        if (item.kind != WorkspaceEvidenceKind.attachment) item,
    ];
    if (relevant.isEmpty) {
      return const [];
    }

    final byId = {for (final item in relevant) item.id: item};
    final captured = <WorkspaceEvidenceItem>[
      for (final id in orderedCapturedEvidenceIds)
        if (byId[id] != null && _isCapturedChronologyMember(byId[id]!))
          byId[id]!,
    ];
    final capturedIds = {for (final item in captured) item.id};
    final leftoverCaptured = [
      for (final item in relevant)
        if (_isCapturedChronologyMember(item) && !capturedIds.contains(item.id))
          item,
    ]..sort(_byInstant);
    captured.addAll(leftoverCaptured);

    final supporting = [
      for (final item in relevant)
        if (_isSupportingChronologyMember(item)) item,
    ]..sort(_byInstant);

    return [
      for (final item in _mergeByInstant(captured, supporting)) item.kind,
    ];
  }

  static List<WorkspaceEvidenceItem> _mergeByInstant(
    List<WorkspaceEvidenceItem> captured,
    List<WorkspaceEvidenceItem> supporting,
  ) {
    if (captured.isEmpty) {
      return supporting;
    }
    if (supporting.isEmpty) {
      return captured;
    }
    final merged = <WorkspaceEvidenceItem>[];
    var s = 0;
    for (final cap in captured) {
      final capTime = _instant(cap);
      while (s < supporting.length &&
          _instant(supporting[s]).isBefore(capTime)) {
        merged.add(supporting[s]);
        s++;
      }
      merged.add(cap);
    }
    merged.addAll(supporting.skip(s));
    return merged;
  }

  static int _byInstant(WorkspaceEvidenceItem a, WorkspaceEvidenceItem b) {
    return _instant(a).compareTo(_instant(b));
  }

  /// Explicit context Voice/Text are authored context, not chronological
  /// qualifying material. Null keeps legacy kind counting. Does not read
  /// origin, TimelineAnchor, or timestamps to invent intent.
  static bool _countsAsChronologicalVoiceOrText(WorkspaceEvidenceItem item) {
    if (item.kind != WorkspaceEvidenceKind.voice &&
        item.kind != WorkspaceEvidenceKind.note) {
      return false;
    }
    return item.temporalIntent != EvidenceTemporalIntent.context;
  }

  static bool _isCapturedChronologyMember(WorkspaceEvidenceItem item) {
    if (!item.kind.isPrimaryChronology) {
      return false;
    }
    if (item.kind == WorkspaceEvidenceKind.voice &&
        item.temporalIntent == EvidenceTemporalIntent.context) {
      return false;
    }
    return true;
  }

  static bool _isSupportingChronologyMember(WorkspaceEvidenceItem item) {
    if (item.kind == WorkspaceEvidenceKind.witness) {
      return true;
    }
    return item.kind == WorkspaceEvidenceKind.note &&
        _countsAsChronologicalVoiceOrText(item);
  }

  /// Existing timestamps only — not a new chronology field.
  static DateTime _instant(WorkspaceEvidenceItem item) {
    return item.capturedAt ?? item.recordedAt ?? item.lastPreservedAt;
  }

  static OrganizeReadinessPattern? _firstMatch(
    EvidenceComposition c,
    List<WorkspaceEvidenceKind> seq,
  ) {
    if (c.photos >= 1 &&
        c.voices >= 1 &&
        c.texts >= 1 &&
        _photoFramedByVoiceOrText(seq)) {
      return OrganizeReadinessPattern.photoVoiceText;
    }
    if (c.photos >= 2 && c.texts >= 1) {
      return OrganizeReadinessPattern.twoPhotosText;
    }
    if (c.photos >= 1 && c.witnesses >= 1) {
      return OrganizeReadinessPattern.photoWitness;
    }
    if (c.videos >= 1 && c.texts >= 1) {
      return OrganizeReadinessPattern.videoText;
    }
    if (c.videos >= 1 && c.voices >= 1) {
      return OrganizeReadinessPattern.videoVoice;
    }
    if (c.videos >= 1 && c.witnesses >= 1) {
      return OrganizeReadinessPattern.videoWitness;
    }
    if (c.videos >= 2 && c.texts >= 1) {
      return OrganizeReadinessPattern.twoVideosText;
    }
    if (c.videos >= 2 && c.voices >= 1) {
      return OrganizeReadinessPattern.twoVideosVoice;
    }
    if (c.photos >= 1 &&
        c.voices >= 2 &&
        _hasSubsequence(seq, const [
          WorkspaceEvidenceKind.voice,
          WorkspaceEvidenceKind.image,
          WorkspaceEvidenceKind.voice,
        ])) {
      return OrganizeReadinessPattern.photoTwoVoice;
    }
    if (c.photos >= 1 &&
        c.texts >= 2 &&
        _hasSubsequence(seq, const [
          WorkspaceEvidenceKind.note,
          WorkspaceEvidenceKind.image,
          WorkspaceEvidenceKind.note,
        ])) {
      return OrganizeReadinessPattern.photoTwoText;
    }
    return null;
  }

  static bool _photoFramedByVoiceOrText(List<WorkspaceEvidenceKind> seq) {
    for (var i = 0; i < seq.length; i++) {
      if (seq[i] != WorkspaceEvidenceKind.image) {
        continue;
      }
      final before = seq.sublist(0, i).any(_isVoiceOrText);
      final after = seq.sublist(i + 1).any(_isVoiceOrText);
      if (before && after) {
        return true;
      }
    }
    return false;
  }

  static bool _isVoiceOrText(WorkspaceEvidenceKind kind) {
    return kind == WorkspaceEvidenceKind.voice ||
        kind == WorkspaceEvidenceKind.note;
  }

  static bool _hasSubsequence(
    List<WorkspaceEvidenceKind> haystack,
    List<WorkspaceEvidenceKind> needle,
  ) {
    var i = 0;
    for (final kind in haystack) {
      if (kind == needle[i]) {
        i++;
        if (i == needle.length) {
          return true;
        }
      }
    }
    return false;
  }

  static String _roleLabel(WorkspaceEvidenceKind kind) {
    return switch (kind) {
      WorkspaceEvidenceKind.image => 'Photo',
      WorkspaceEvidenceKind.video => 'Video',
      WorkspaceEvidenceKind.voice => 'Voice',
      WorkspaceEvidenceKind.note => 'Text',
      WorkspaceEvidenceKind.witness => 'Witness',
      WorkspaceEvidenceKind.attachment => 'Attachment',
    };
  }

  static String? _hint(EvidenceComposition c) {
    if (c.qualifyingCount == 0 && c.attachments > 0) {
      return 'Attachments can support an Incident, but they do not determine '
          'Organize readiness on their own.';
    }
    if ((c.photos == 1 && c.videos == 0 || c.videos == 1 && c.photos == 0) &&
        c.voices == 0 &&
        c.texts == 0 &&
        c.witnesses == 0) {
      return 'Visual evidence is preserved. Written, spoken, or witness '
          'context can help Organize make sense of it.';
    }
    return null;
  }
}
