import '../../domain/trust_package/trust_package.dart';

/// Serializes [TrustPackage] to JSON without modifying the domain model.
abstract final class TrustPackageSerializer {
  static Map<String, dynamic> toJson(TrustPackage package) {
    return {
      'incidentSummary': _incidentSummary(package.incidentSummary),
      'investigationSummary': _investigationSummary(package.investigationSummary),
      'timelineSection': _timelineSection(package.timelineSection),
      'relationshipGroupsSection':
          _relationshipGroupsSection(package.relationshipGroupsSection),
      'reconstructionSection': _reconstructionSection(package.reconstructionSection),
      'evidenceAppendix': _evidenceAppendix(package.evidenceAppendix),
      'integritySummary': _integritySummary(package.integritySummary),
      'integrityProvenance':
          _integrityProvenance(package.integrityProvenance),
      'metadata': _metadata(package.metadata),
    };
  }

  static Map<String, dynamic> _incidentSummary(
    TrustPackageIncidentSummary summary,
  ) {
    return {
      'incidentName': summary.incidentName,
      'incidentType': summary.incidentType,
      'incidentStatus': summary.incidentStatus,
      'dateCreated': summary.dateCreated.toIso8601String(),
      'dateUpdated': summary.dateUpdated.toIso8601String(),
      'primaryInvestigator': summary.primaryInvestigator,
      'investigationConfidence': summary.investigationConfidence,
      'reconstructionHealth': summary.reconstructionHealth,
    };
  }

  static Map<String, dynamic> _investigationSummary(
    TrustPackageInvestigationSummary summary,
  ) {
    return {
      'timelineAnchorCount': summary.timelineAnchorCount,
      'relationshipGroupCount': summary.relationshipGroupCount,
      'narrativeEventCount': summary.narrativeEventCount,
      'primaryEvidenceCount': summary.primaryEvidenceCount,
      'supportingEvidenceCount': summary.supportingEvidenceCount,
      'contextEntryCount': summary.contextEntryCount,
      'witnessCount': summary.witnessCount,
      'documentCount': summary.documentCount,
    };
  }

  static Map<String, dynamic> _timelineSection(
    TrustPackageTimelineSection section,
  ) {
    return {
      'entries': [
        for (final entry in section.entries) _timelineEntry(entry),
      ],
    };
  }

  static Map<String, dynamic> _timelineEntry(TrustPackageTimelineEntry entry) {
    return {
      'timestamp': entry.timestamp.toIso8601String(),
      'title': entry.title,
      'relatedEvidenceIds': entry.relatedEvidenceIds,
      'relationshipGroupIds': entry.relationshipGroupIds,
      'timelineAnchorId': entry.timelineAnchorId,
      'capturedEvidenceId': entry.capturedEvidenceId,
    };
  }

  static Map<String, dynamic> _relationshipGroupsSection(
    TrustPackageRelationshipGroupsSection section,
  ) {
    return {
      'groups': [
        for (final group in section.groups) _relationshipGroup(group),
      ],
    };
  }

  static Map<String, dynamic> _relationshipGroup(
    TrustPackageRelationshipGroupEntry group,
  ) {
    return {
      'groupId': group.groupId,
      'colorHex': group.colorHex,
      'groupName': group.groupName,
      'supportingEvidenceIds': group.supportingEvidenceIds,
      'connectedTimelineAnchorIds': group.connectedTimelineAnchorIds,
      'confidenceLevel': group.confidenceLevel,
      'validationStatus': group.validationStatus,
    };
  }

  static Map<String, dynamic> _reconstructionSection(
    TrustPackageReconstructionSection section,
  ) {
    return {
      'events': [
        for (final event in section.events) _reconstructionEvent(event),
      ],
    };
  }

  static Map<String, dynamic> _reconstructionEvent(
    TrustPackageReconstructionEventEntry event,
  ) {
    return {
      'eventId': event.eventId,
      'title': event.title,
      'summary': event.summary,
      'evidenceReferenceIds': event.evidenceReferenceIds,
      'confidence': event.confidence,
      'validationStatus': event.validationStatus,
    };
  }

  static Map<String, dynamic> _evidenceAppendix(
    TrustPackageEvidenceAppendix appendix,
  ) {
    return {
      'entries': [
        for (final entry in appendix.entries) _appendixEntry(entry),
      ],
    };
  }

  static Map<String, dynamic> _appendixEntry(
    TrustPackageEvidenceAppendixEntry entry,
  ) {
    return {
      'evidenceId': entry.evidenceId,
      'title': entry.title,
      'evidenceType': entry.evidenceType,
      'timestamp': entry.timestamp.toIso8601String(),
      'device': entry.device,
      'location': entry.location,
      'context': entry.context,
      'relationshipGroupIds': entry.relationshipGroupIds,
    };
  }

  static Map<String, dynamic> _integrityProvenance(
    TrustPackageIntegrityProvenanceSection section,
  ) {
    return {
      'packStatus': section.packStatusLabel,
      'entries': [
        for (final entry in section.entries)
          {
            'evidenceId': entry.evidenceId,
            'title': entry.title,
            'state': entry.state.name,
            'status': entry.statusLabel,
            'originalPreserved': entry.originalPreserved,
            'capturedAt': entry.capturedAt?.toIso8601String(),
            'preservedAt': entry.preservedAt?.toIso8601String(),
            'source': entry.source,
            'captureModality': entry.captureModality,
            'location': entry.locationDisplay,
            'contentHash': entry.contentHash,
            'independentVerification': entry.independentVerification,
            'history': [
              for (final event in entry.history)
                {
                  'at': event.at.toIso8601String(),
                  'label': event.label,
                },
            ],
          },
      ],
    };
  }

  static Map<String, dynamic> _integritySummary(
    TrustPackageIntegritySummary summary,
  ) {
    return {
      'evidenceCount': summary.evidenceCount,
      'timelineIntegrity': summary.timelineIntegrity,
      'relationshipIntegrity': summary.relationshipIntegrity,
      'missingReferences': summary.missingReferences,
      'validationStatus': summary.validationStatus,
    };
  }

  static Map<String, dynamic> _metadata(TrustPackageMetadata metadata) {
    return {
      'packageVersion': metadata.packageVersion,
      'generatedAt': metadata.generatedAt.toIso8601String(),
      'generatedBy': metadata.generatedBy,
      'incidentVersion': metadata.incidentVersion,
      'trustPackageId': metadata.trustPackageId,
    };
  }
}
