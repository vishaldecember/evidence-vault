/// How a relationship suggestion was produced (Sprint 5C).
enum RelationshipSuggestionSource {
  metadata,
  user,
  ai;

  String get wireName => name;
}

/// Lifecycle of a [RelationshipSuggestion].
enum RelationshipSuggestionStatus {
  suggested,
  accepted,
  rejected,
  dismissed;

  String get wireName => name;
}

/// Extensible contract for metadata / user / future AI relationship suggestions.
///
/// Deterministic Sprint 5C providers emit [suggested] items; the UI never
/// exposes provider implementation details.
class RelationshipSuggestion {
  const RelationshipSuggestion({
    required this.id,
    required this.incidentId,
    required this.sourceEvidenceId,
    required this.targetEvidenceId,
    required this.relationshipType,
    required this.confidence,
    required this.reason,
    required this.source,
    required this.status,
    required this.createdAt,
    this.timeExplanation,
    this.spaceExplanation,
    this.matterExplanation,
  });

  final String id;
  final String incidentId;
  final String sourceEvidenceId;
  final String targetEvidenceId;

  /// Wire name of [RelationshipType] (relatedTo / supports / …).
  final String relationshipType;

  /// 0.0 – 1.0
  final double confidence;
  final String reason;
  final RelationshipSuggestionSource source;
  final RelationshipSuggestionStatus status;
  final DateTime createdAt;

  /// Independent TIME clause when present. Null if TIME did not contribute.
  final String? timeExplanation;

  /// Independent SPACE clause when present. Null if SPACE did not contribute.
  final String? spaceExplanation;

  /// Independent MATTER clause when present. Null if MATTER did not contribute.
  final String? matterExplanation;

  RelationshipSuggestion copyWith({
    RelationshipSuggestionStatus? status,
  }) {
    return RelationshipSuggestion(
      id: id,
      incidentId: incidentId,
      sourceEvidenceId: sourceEvidenceId,
      targetEvidenceId: targetEvidenceId,
      relationshipType: relationshipType,
      confidence: confidence,
      reason: reason,
      source: source,
      status: status ?? this.status,
      createdAt: createdAt,
      timeExplanation: timeExplanation,
      spaceExplanation: spaceExplanation,
      matterExplanation: matterExplanation,
    );
  }
}

/// Metadata, user, and composed Matter providers implement this.
///
/// Default production composition is heuristic TIME/SPACE plus a disabled
/// Matter provider. Matter must emit [RelationshipType.relatedTo] only.
abstract class RelationshipSuggestionProvider {
  List<RelationshipSuggestion> suggest({
    required String incidentId,
    required List<RelationshipEvidenceSignal> signals,
  });
}

/// Lightweight signal for relationship heuristics / future AI.
class RelationshipEvidenceSignal {
  const RelationshipEvidenceSignal({
    required this.evidenceId,
    required this.kindLabel,
    required this.capturedAt,
    this.collectionId,
    this.collectionName,
    this.latitude,
    this.longitude,
    this.deviceModel,
    this.isPrimary = false,
    this.parentEvidenceId,
    this.timelineOrder,
  });

  final String evidenceId;
  final String kindLabel;
  final DateTime capturedAt;
  final String? collectionId;
  final String? collectionName;
  final double? latitude;
  final double? longitude;
  final String? deviceModel;
  final bool isPrimary;
  final String? parentEvidenceId;
  final int? timelineOrder;
}
