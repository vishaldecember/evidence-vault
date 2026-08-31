/// User-created organizational grouping of existing incidents.
///
/// Membership is incident IDs only. This is not an [Incident], not evidence,
/// not an intra-incident EvidenceCollection, and not an AI pattern.
class IncidentCollection {
  IncidentCollection({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    List<String>? memberIncidentIds,
  }) : memberIncidentIds = List<String>.unmodifiable(
          normalizeMemberIds(memberIncidentIds ?? const []),
        );

  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Incident IDs in first-seen order. Duplicates and blank IDs are dropped.
  final List<String> memberIncidentIds;

  int get count => memberIncidentIds.length;

  bool contains(String incidentId) =>
      memberIncidentIds.contains(incidentId.trim());

  /// First-seen order, unique, blank IDs removed.
  static List<String> normalizeMemberIds(Iterable<String> ids) {
    final seen = <String>{};
    final out = <String>[];
    for (final raw in ids) {
      final id = raw.trim();
      if (id.isEmpty || seen.contains(id)) {
        continue;
      }
      seen.add(id);
      out.add(id);
    }
    return out;
  }

  IncidentCollection copyWith({
    String? title,
    DateTime? updatedAt,
    List<String>? memberIncidentIds,
  }) {
    return IncidentCollection(
      id: id,
      title: title ?? this.title,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      memberIncidentIds: memberIncidentIds ?? this.memberIncidentIds,
    );
  }

  /// Idempotent add. Returns [this] when the ID is already a member or blank.
  IncidentCollection withMember(String incidentId, {DateTime? updatedAt}) {
    final id = incidentId.trim();
    if (id.isEmpty || memberIncidentIds.contains(id)) {
      return this;
    }
    return copyWith(
      memberIncidentIds: [...memberIncidentIds, id],
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Idempotent remove. Returns [this] when the ID is not a member.
  IncidentCollection withoutMember(String incidentId, {DateTime? updatedAt}) {
    final id = incidentId.trim();
    if (id.isEmpty || !memberIncidentIds.contains(id)) {
      return this;
    }
    return copyWith(
      memberIncidentIds: [
        for (final member in memberIncidentIds)
          if (member != id) member,
      ],
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! IncidentCollection) {
      return false;
    }
    if (other.id != id ||
        other.title != title ||
        other.memberIncidentIds.length != memberIncidentIds.length ||
        !other.createdAt.isAtSameMomentAs(createdAt) ||
        !other.updatedAt.isAtSameMomentAs(updatedAt)) {
      return false;
    }
    for (var i = 0; i < memberIncidentIds.length; i++) {
      if (other.memberIncidentIds[i] != memberIncidentIds[i]) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
        id,
        title,
        createdAt.toUtc(),
        updatedAt.toUtc(),
        Object.hashAll(memberIncidentIds),
      );
}
