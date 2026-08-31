import 'trust_package_integrity_provenance.dart';

export 'trust_package_integrity_provenance.dart';

/// Canonical investigation artifact — projection only, never persisted.
///
/// All sections reference existing domain objects by ID. Evidence media is
/// never embedded or duplicated.
class TrustPackage {
  const TrustPackage({
    required this.incidentSummary,
    required this.investigationSummary,
    required this.timelineSection,
    required this.relationshipGroupsSection,
    required this.reconstructionSection,
    required this.evidenceAppendix,
    required this.integritySummary,
    required this.metadata,
    this.integrityProvenance = TrustPackageIntegrityProvenanceSection.empty,
  });

  final TrustPackageIncidentSummary incidentSummary;
  final TrustPackageInvestigationSummary investigationSummary;
  final TrustPackageTimelineSection timelineSection;
  final TrustPackageRelationshipGroupsSection relationshipGroupsSection;
  final TrustPackageReconstructionSection reconstructionSection;
  final TrustPackageEvidenceAppendix evidenceAppendix;
  final TrustPackageIntegritySummary integritySummary;
  final TrustPackageIntegrityProvenanceSection integrityProvenance;
  final TrustPackageMetadata metadata;
}

class TrustPackageIncidentSummary {
  const TrustPackageIncidentSummary({
    required this.incidentName,
    required this.incidentType,
    required this.incidentStatus,
    required this.dateCreated,
    required this.dateUpdated,
    this.primaryInvestigator,
    required this.investigationConfidence,
    required this.reconstructionHealth,
  });

  final String incidentName;
  final String incidentType;
  final String incidentStatus;
  final DateTime dateCreated;
  final DateTime dateUpdated;
  final String? primaryInvestigator;
  final String investigationConfidence;
  final String reconstructionHealth;
}

class TrustPackageInvestigationSummary {
  const TrustPackageInvestigationSummary({
    required this.timelineAnchorCount,
    required this.relationshipGroupCount,
    required this.narrativeEventCount,
    required this.primaryEvidenceCount,
    required this.supportingEvidenceCount,
    required this.contextEntryCount,
    required this.witnessCount,
    required this.documentCount,
  });

  final int timelineAnchorCount;
  final int relationshipGroupCount;
  final int narrativeEventCount;
  final int primaryEvidenceCount;

  /// Count of items that structurally support another scoped item.
  /// Not a kind count — see [WorkspaceEvidenceItem.isSupportingEvidence].
  final int supportingEvidenceCount;

  /// Own recorded location / written description, plus reconstruction notes.
  /// Parent linkage alone is not context.
  final int contextEntryCount;
  final int witnessCount;
  final int documentCount;

  String get primaryChronologyStatement {
    if (primaryEvidenceCount == 1) {
      return '1 primary chronology item';
    }
    return '$primaryEvidenceCount primary chronology items';
  }

  String get structuralSupportStatement {
    if (supportingEvidenceCount == 0) {
      return 'No parent-linked supporting material is currently attached';
    }
    if (supportingEvidenceCount == 1) {
      return '1 item is structurally linked as supporting material';
    }
    return '$supportingEvidenceCount items are structurally linked as '
        'supporting material';
  }

  String get recordedContextStatement {
    if (contextEntryCount == 0) {
      return 'No recorded location or written context is currently attached';
    }
    return 'Location or written context is recorded';
  }
}

class TrustPackageTimelineSection {
  const TrustPackageTimelineSection({required this.entries});

  final List<TrustPackageTimelineEntry> entries;
}

class TrustPackageTimelineEntry {
  const TrustPackageTimelineEntry({
    required this.timestamp,
    required this.title,
    required this.relatedEvidenceIds,
    required this.relationshipGroupIds,
    required this.timelineAnchorId,
    required this.capturedEvidenceId,
  });

  final DateTime timestamp;
  final String title;
  final List<String> relatedEvidenceIds;
  final List<String> relationshipGroupIds;
  final String timelineAnchorId;
  final String capturedEvidenceId;
}

class TrustPackageRelationshipGroupsSection {
  const TrustPackageRelationshipGroupsSection({required this.groups});

  final List<TrustPackageRelationshipGroupEntry> groups;
}

class TrustPackageRelationshipGroupEntry {
  const TrustPackageRelationshipGroupEntry({
    required this.groupId,
    required this.colorHex,
    required this.groupName,
    required this.supportingEvidenceIds,
    required this.connectedTimelineAnchorIds,
    required this.confidenceLevel,
    required this.validationStatus,
  });

  final String groupId;
  final String colorHex;
  final String groupName;
  final List<String> supportingEvidenceIds;
  final List<String> connectedTimelineAnchorIds;
  final String confidenceLevel;
  final String validationStatus;

  List<String> get memberEvidenceIds => [
        ...connectedTimelineAnchorIds,
        ...supportingEvidenceIds,
      ];
}

class TrustPackageReconstructionSection {
  const TrustPackageReconstructionSection({required this.events});

  final List<TrustPackageReconstructionEventEntry> events;
}

class TrustPackageReconstructionEventEntry {
  const TrustPackageReconstructionEventEntry({
    required this.eventId,
    required this.title,
    this.summary,
    required this.evidenceReferenceIds,
    required this.confidence,
    required this.validationStatus,
  });

  final String eventId;
  final String title;
  final String? summary;
  final List<String> evidenceReferenceIds;
  final String confidence;
  final String validationStatus;
}

class TrustPackageEvidenceAppendix {
  const TrustPackageEvidenceAppendix({required this.entries});

  final List<TrustPackageEvidenceAppendixEntry> entries;
}

class TrustPackageEvidenceAppendixEntry {
  const TrustPackageEvidenceAppendixEntry({
    required this.evidenceId,
    required this.title,
    required this.evidenceType,
    required this.timestamp,
    this.device,
    this.location,
    this.context,
    required this.relationshipGroupIds,
  });

  final String evidenceId;
  final String title;
  final String evidenceType;
  final DateTime timestamp;
  final String? device;
  final String? location;
  final String? context;
  final List<String> relationshipGroupIds;
}

class TrustPackageIntegritySummary {
  const TrustPackageIntegritySummary({
    required this.evidenceCount,
    required this.timelineIntegrity,
    required this.relationshipIntegrity,
    required this.missingReferences,
    required this.validationStatus,
  });

  final int evidenceCount;
  final String timelineIntegrity;
  final String relationshipIntegrity;
  final List<String> missingReferences;
  final String validationStatus;
}

class TrustPackageMetadata {
  const TrustPackageMetadata({
    required this.packageVersion,
    required this.generatedAt,
    required this.generatedBy,
    required this.incidentVersion,
    required this.trustPackageId,
  });

  final String packageVersion;
  final DateTime generatedAt;
  final String generatedBy;
  final String incidentVersion;
  final String trustPackageId;
}
