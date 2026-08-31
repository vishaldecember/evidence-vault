import '../engines/enrichment_engine.dart';
import '../engines/evidence_semantics.dart';
import '../models/reflection_model.dart';
import '../models/relationship_group_confidence.dart';
import '../models/workspace_evidence_item.dart';

/// Evidence-type counts for the narrative validation breakdown.
class NarrativeEvidenceTypeCount {
  const NarrativeEvidenceTypeCount({
    required this.emoji,
    required this.label,
    required this.count,
  });

  final String emoji;
  final String label;
  final int count;
}

/// Derived validation for one narrative event — never persisted.
class NarrativeEventValidation {
  const NarrativeEventValidation({
    required this.status,
    required this.typeCounts,
    required this.recommendations,
  });

  final RelationshipGroupConfidence status;
  final List<NarrativeEvidenceTypeCount> typeCounts;
  final List<String> recommendations;

  String get statusEmoji => status.emoji;

  bool get isSufficientlySupported =>
      status == RelationshipGroupConfidence.high ||
      status == RelationshipGroupConfidence.medium;

  List<String> get supportedByLines {
    if (typeCounts.isEmpty) {
      return const ['No evidence attached'];
    }
    return typeCounts
        .map((entry) => '• ${entry.emoji} ${entry.count} ${entry.label}')
        .toList();
  }
}

/// Overall reconstruction completeness — never persisted.
class NarrativeReconstructionHealth {
  const NarrativeReconstructionHealth({
    required this.status,
    required this.label,
    required this.coverageLabel,
    required this.supportedEventCount,
    required this.totalEventCount,
  });

  final ReconstructionHealthStatus status;
  final String label;
  final String coverageLabel;
  final int supportedEventCount;
  final int totalEventCount;

  String get statusEmoji => status.emoji;
}

enum ReconstructionHealthStatus {
  excellent('Excellent', '🟢'),
  needsReview('Needs Review', '🟡'),
  incomplete('Incomplete', '🔴');

  const ReconstructionHealthStatus(this.label, this.emoji);

  final String label;
  final String emoji;
}

/// Heuristic narrative completeness validator — not AI, not truth inference.
abstract final class NarrativeValidationService {
  static const recReferencedRemoved = 'Referenced evidence removed.';
  static const recEventHasNoAttachedEvidence =
      'This event currently has no attached evidence. You may consider linking captured evidence if available.';
  static const recEventSingleEvidence =
      'This reconstructed event currently references 1 evidence item.';
  static const recLocationMissing =
      'Location is not recorded for this evidence.';
  static const recNoWrittenExplanation =
      'No written explanation is attached to this event.';
  static const recWitnessOptional =
      'No witness statement is recorded for this event. You may consider adding one if someone observed the event.';
  static const recSupportingDocumentOptional =
      'No parent-linked supporting document is attached to this event. You may consider attaching one if available.';
  static const recVoiceNoWrittenExplanation =
      'This voice recording has no written explanation attached.';

  static NarrativeEventValidation validateEvent({
    required List<WorkspaceEvidenceItem> displayEvidence,
    required List<WorkspaceEvidenceItem> supportingEvidence,
    required List<ReflectionModel> reconstructionNotes,
    required bool hasMissingReferencedEvidence,
    required EnrichmentContext enrichmentContext,
    String? eventSummary,
    int incidentPrimaryChronologyCount = 0,
  }) {
    final typeCounts = _evidenceTypeCounts(displayEvidence);

    if (hasMissingReferencedEvidence) {
      return NarrativeEventValidation(
        status: RelationshipGroupConfidence.low,
        typeCounts: typeCounts,
        recommendations: const [
          recReferencedRemoved,
          recEventHasNoAttachedEvidence,
        ],
      );
    }

    if (displayEvidence.isEmpty) {
      return NarrativeEventValidation(
        status: RelationshipGroupConfidence.low,
        typeCounts: typeCounts,
        recommendations: const [
          recEventHasNoAttachedEvidence,
        ],
      );
    }

    final relationships = enrichmentContext.relationships;
    final primaryCount = displayEvidence
        .where(EvidenceSemantics.isPrimaryChronologyEvidence)
        .length;
    final supportingCount = supportingEvidence
        .where(
          (item) => displayEvidence.any(
            (parent) => EvidenceSemantics.structurallySupports(
              child: item,
              parentId: parent.id,
              relationships: relationships,
            ),
          ),
        )
        .length;
    final totalCount = displayEvidence.length;
    final typeCount = displayEvidence.map((item) => item.kind).toSet().length;

    final hasEventSummary = eventSummary?.trim().isNotEmpty ?? false;
    final hasReconstructionNotes = reconstructionNotes.isNotEmpty;
    final hasLocation = displayEvidence.any(EvidenceSemantics.hasLocation);
    final hasWrittenExplanation = hasEventSummary ||
        hasReconstructionNotes ||
        [...displayEvidence, ...supportingEvidence].any(
          (item) =>
              item.isContextual ||
              (item.notePreview?.trim().isNotEmpty ?? false),
        );
    final hasContext = hasWrittenExplanation || hasLocation;

    final hasWitness = EvidenceSemantics.hasWitnessKind(displayEvidence);
    final hasDocument = supportingCount > 0 &&
        [...displayEvidence, ...supportingEvidence].any(
          (item) =>
              item.kind == WorkspaceEvidenceKind.note ||
              item.kind == WorkspaceEvidenceKind.attachment,
        );
    final voiceWithoutWrittenExplanation = displayEvidence.any(
      (item) =>
          item.kind == WorkspaceEvidenceKind.voice &&
          (item.notePreview?.trim().isEmpty ?? true),
    );

    final status = _resolveStatus(
      totalCount: totalCount,
      primaryCount: primaryCount,
      supportingCount: supportingCount,
      typeCount: typeCount,
      hasContext: hasContext,
      incidentPrimaryChronologyCount: incidentPrimaryChronologyCount,
    );

    final recommendations = _recommendationsFor(
      status: status,
      totalCount: totalCount,
      supportingCount: supportingCount,
      hasLocation: hasLocation,
      hasWrittenExplanation: hasWrittenExplanation,
      hasWitness: hasWitness,
      hasDocument: hasDocument,
      voiceWithoutWrittenExplanation: voiceWithoutWrittenExplanation,
      quietGenericSingleSource: incidentPrimaryChronologyCount >= 2,
    );

    return NarrativeEventValidation(
      status: status,
      typeCounts: typeCounts,
      recommendations: recommendations,
    );
  }

  static NarrativeReconstructionHealth computeReconstructionHealth(
    List<NarrativeEventValidation> validations,
  ) {
    final total = validations.length;
    if (total == 0) {
      return const NarrativeReconstructionHealth(
        status: ReconstructionHealthStatus.incomplete,
        label: 'Incomplete',
        coverageLabel: '0 of 0 Narrative Events sufficiently supported.',
        supportedEventCount: 0,
        totalEventCount: 0,
      );
    }

    final supported =
        validations.where((entry) => entry.isSufficientlySupported).length;
    final lowCount = validations
        .where((entry) => entry.status == RelationshipGroupConfidence.low)
        .length;
    final highCount = validations
        .where((entry) => entry.status == RelationshipGroupConfidence.high)
        .length;

    final ReconstructionHealthStatus status;
    if (lowCount == 0 && highCount == total) {
      status = ReconstructionHealthStatus.excellent;
    } else if (lowCount == 0 || supported / total >= 0.75) {
      status = ReconstructionHealthStatus.needsReview;
    } else {
      status = ReconstructionHealthStatus.incomplete;
    }

    return NarrativeReconstructionHealth(
      status: status,
      label: status.label,
      coverageLabel:
          '$supported of $total Narrative Events sufficiently supported.',
      supportedEventCount: supported,
      totalEventCount: total,
    );
  }

  static RelationshipGroupConfidence _resolveStatus({
    required int totalCount,
    required int primaryCount,
    required int supportingCount,
    required int typeCount,
    required bool hasContext,
    int incidentPrimaryChronologyCount = 0,
  }) {
    if (totalCount == 0) {
      return RelationshipGroupConfidence.low;
    }

    // Default one-event-per-anchor is valid when the incident already has
    // multiple chronology items. Do not treat a single attached anchor as
    // incident-level incompleteness or corroboration failure.
    final defaultOneAnchorIsValid =
        incidentPrimaryChronologyCount >= 2 && totalCount >= 1;

    if (totalCount <= 1 &&
        !hasContext &&
        supportingCount == 0 &&
        !defaultOneAnchorIsValid) {
      return RelationshipGroupConfidence.low;
    }

    final hasMultiplePrimary = primaryCount >= 2;
    final hasMultipleTypes = typeCount >= 2;
    final hasSupportingEvidence = supportingCount > 0;

    if (hasMultiplePrimary &&
        hasContext &&
        hasMultipleTypes &&
        hasSupportingEvidence) {
      return RelationshipGroupConfidence.high;
    }

    if (hasContext || hasSupportingEvidence || totalCount >= 2) {
      return RelationshipGroupConfidence.medium;
    }
    if (defaultOneAnchorIsValid) {
      return RelationshipGroupConfidence.medium;
    }

    return RelationshipGroupConfidence.low;
  }

  static List<String> _recommendationsFor({
    required RelationshipGroupConfidence status,
    required int totalCount,
    required int supportingCount,
    required bool hasLocation,
    required bool hasWrittenExplanation,
    required bool hasWitness,
    required bool hasDocument,
    required bool voiceWithoutWrittenExplanation,
    bool quietGenericSingleSource = false,
  }) {
    if (status == RelationshipGroupConfidence.high) {
      return const [];
    }

    final recommendations = <String>[];

    if (totalCount <= 1 && !quietGenericSingleSource) {
      recommendations.add(recEventSingleEvidence);
    }
    if (!hasLocation) {
      recommendations.add(recLocationMissing);
    }
    if (!hasWrittenExplanation) {
      recommendations.add(recNoWrittenExplanation);
    }
    if (!hasWitness && !quietGenericSingleSource) {
      recommendations.add(recWitnessOptional);
    }
    if (!hasDocument && supportingCount == 0) {
      recommendations.add(recSupportingDocumentOptional);
    }
    if (voiceWithoutWrittenExplanation) {
      recommendations.add(recVoiceNoWrittenExplanation);
    }

    return recommendations;
  }

  static List<NarrativeEvidenceTypeCount> _evidenceTypeCounts(
    List<WorkspaceEvidenceItem> evidence,
  ) {
    var photos = 0;
    var videos = 0;
    var voices = 0;
    var witnesses = 0;
    var documents = 0;

    for (final item in evidence) {
      switch (item.kind) {
        case WorkspaceEvidenceKind.image:
          photos += 1;
        case WorkspaceEvidenceKind.video:
          videos += 1;
        case WorkspaceEvidenceKind.voice:
          voices += 1;
        case WorkspaceEvidenceKind.witness:
          witnesses += 1;
        case WorkspaceEvidenceKind.note:
        case WorkspaceEvidenceKind.attachment:
          documents += 1;
      }
    }

    final counts = <NarrativeEvidenceTypeCount>[];
    if (photos > 0) {
      counts.add(NarrativeEvidenceTypeCount(
        emoji: '📷',
        label: photos == 1 ? 'Photo' : 'Photos',
        count: photos,
      ));
    }
    if (videos > 0) {
      counts.add(NarrativeEvidenceTypeCount(
        emoji: '🎥',
        label: videos == 1 ? 'Video' : 'Videos',
        count: videos,
      ));
    }
    if (voices > 0) {
      counts.add(NarrativeEvidenceTypeCount(
        emoji: '🎤',
        label: voices == 1 ? 'Voice' : 'Voices',
        count: voices,
      ));
    }
    if (witnesses > 0) {
      counts.add(NarrativeEvidenceTypeCount(
        emoji: '👤',
        label: witnesses == 1 ? 'Witness' : 'Witnesses',
        count: witnesses,
      ));
    }
    if (documents > 0) {
      counts.add(NarrativeEvidenceTypeCount(
        emoji: '📄',
        label: documents == 1 ? 'Document' : 'Documents',
        count: documents,
      ));
    }
    return counts;
  }
}
