import '../../models/relationship_type.dart';

/// Incident-owned group of related supporting evidence artifacts.
class RelationshipGroup {
  RelationshipGroup({
    required this.id,
    this.incidentId = '',
    List<String>? memberEvidenceIds,
    List<String>? evidenceIds,
    required this.type,
    required this.createdAt,
    required this.colorIndex,
    this.displayName,
    this.description,
  }) : memberEvidenceIds =
            List.unmodifiable(memberEvidenceIds ?? evidenceIds ?? const []);

  static const int maxDisplayNameLength = 40;
  static const int maxDescriptionLength = 200;

  final String id;
  final String incidentId;
  final List<String> memberEvidenceIds;
  final RelationshipType type;
  final DateTime createdAt;

  /// Permanent palette index assigned at creation — never changes.
  final int colorIndex;

  /// Investigator-defined label. When empty, UI falls back to "Group N".
  final String? displayName;

  /// Optional investigator reasoning for why evidence belongs together.
  final String? description;

  /// Backward-compatible alias for legacy [evidenceIds] consumers.
  List<String> get evidenceIds => memberEvidenceIds;

  RelationshipGroup copyWithMembers(List<String> members) {
    return RelationshipGroup(
      id: id,
      incidentId: incidentId,
      memberEvidenceIds: members,
      type: type,
      createdAt: createdAt,
      colorIndex: colorIndex,
      displayName: displayName,
      description: description,
    );
  }

  RelationshipGroup copyWithInvestigation({
    String? displayName,
    String? description,
  }) {
    return RelationshipGroup(
      id: id,
      incidentId: incidentId,
      memberEvidenceIds: memberEvidenceIds,
      type: type,
      createdAt: createdAt,
      colorIndex: colorIndex,
      displayName: displayName,
      description: description,
    );
  }
}
