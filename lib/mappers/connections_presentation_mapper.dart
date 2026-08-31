import '../domain/collection/evidence_collection.dart';
import '../domain/relationship/relationship_suggestion.dart';
import '../engines/evidence_semantics.dart';
import '../models/connection_group_node.dart';
import '../models/connections_presentation.dart';
import '../models/evidence_relationship.dart';
import '../models/workspace_evidence_item.dart';
import '../widgets/investigation/investigate_incident_scope.dart';

/// Builds the Connections presentation from existing persisted + heuristic data.
///
/// STRUCTURAL: parent-linked supporting, explicit links, collections, groups.
/// SUGGESTED: metadata RELATED (not supporting, not corroboration).
/// Does not mutate stores or invent relationships.
abstract final class ConnectionsPresentationMapper {
  static ConnectionsPresentation build({
    required String incidentId,
    required Iterable<WorkspaceEvidenceItem> items,
    required Iterable<EvidenceRelationship> relationships,
    required Iterable<EvidenceCollection> collections,
    required Iterable<ConnectionGroupNode> groupNodes,
    required Iterable<RelationshipSuggestion> suggestions,
  }) {
    final owned = InvestigateIncidentScope.evidence(items, incidentId);
    final byId = {for (final item in owned) item.id: item};
    final scopedRelationships = InvestigateIncidentScope.relationships(
      relationships,
      items,
      incidentId,
    );
    final scopedCollections = InvestigateIncidentScope.collections(
      collections,
      incidentId,
    );
    final scopedSuggestions = InvestigateIncidentScope.suggestions(
      suggestions,
      incidentId,
    );
    final scopedGroups = [
      for (final node in InvestigateIncidentScope.connections(
        groupNodes,
        incidentId,
      ))
        if (node.evidenceCount > 0) node,
    ];

    final groupMemberSets = [
      for (final node in scopedGroups) {
        for (final entry in node.capturedEntries) ...[
          entry.captured.id,
          ...entry.supportingItems.map((item) => item.id),
        ],
        ...node.standaloneSupporting.map((item) => item.id),
      },
    ];

    final supporting = <ConnectionsPairView>[];
    final supportingPairs = <String>{};
    for (final item in owned) {
      final parentId = item.parentEvidenceId?.trim() ?? '';
      if (parentId.isEmpty) {
        continue;
      }
      final parent = byId[parentId];
      if (parent == null) {
        continue;
      }
      final pair = ConnectionsPairView(
        from: parent,
        to: item,
        kind: ConnectionsPairKind.supporting,
        label: 'Supporting evidence',
      );
      supportingPairs.add(pair.pairId);
      supporting.add(pair);
    }

    final linked = <ConnectionsPairView>[];
    final suggested = <ConnectionsPairView>[];
    final seenPairs = {...supportingPairs};

    for (final relationship in scopedRelationships) {
      final from = byId[relationship.sourceEvidenceId];
      final to = byId[relationship.targetEvidenceId];
      if (from == null || to == null) {
        continue;
      }
      final pairId = _pairId(from.id, to.id);
      if (seenPairs.contains(pairId)) {
        continue;
      }
      if (_isHeuristicRelated(relationship)) {
        if (_isCollectionHeuristic(relationship)) {
          continue;
        }
        seenPairs.add(pairId);
        suggested.add(
          ConnectionsPairView(
            from: from,
            to: to,
            kind: ConnectionsPairKind.suggested,
            label: 'Suggested relationship',
            detail: _suggestedDetail(
              relationship,
              from,
              to,
              scopedSuggestions,
            ),
            confidence: _confidenceFor(
              from.id,
              to.id,
              scopedSuggestions,
            ),
          ),
        );
        continue;
      }
      if (_bothInSameGroup(from.id, to.id, groupMemberSets)) {
        continue;
      }
      seenPairs.add(pairId);
      linked.add(
        ConnectionsPairView(
          from: from,
          to: to,
          kind: ConnectionsPairKind.linked,
          label: 'Linked evidence',
        ),
      );
    }

    for (final suggestion in scopedSuggestions) {
      if (suggestion.status != RelationshipSuggestionStatus.suggested) {
        continue;
      }
      final from = byId[suggestion.sourceEvidenceId];
      final to = byId[suggestion.targetEvidenceId];
      if (from == null || to == null) {
        continue;
      }
      final pairId = _pairId(from.id, to.id);
      if (seenPairs.contains(pairId)) {
        continue;
      }
      if ((suggestion.reason).startsWith('Related through')) {
        continue;
      }
      seenPairs.add(pairId);
      suggested.add(
        ConnectionsPairView(
          from: from,
          to: to,
          kind: ConnectionsPairKind.suggested,
          label: 'Suggested relationship',
          detail: _detailFromSuggestion(suggestion, from, to),
          confidence: suggestion.confidence,
        ),
      );
    }

    final collectionViews = <ConnectionsCollectionView>[];
    for (final collection in scopedCollections) {
      final members = [
        for (final id in collection.memberEvidenceIds)
          if (byId[id] != null) byId[id]!,
      ];
      if (members.isEmpty) {
        continue;
      }
      collectionViews.add(
        ConnectionsCollectionView(
          collection: collection,
          members: members,
        ),
      );
    }

    return ConnectionsPresentation(
      incidentId: incidentId,
      supporting: supporting,
      linked: linked,
      collections: collectionViews,
      groupNodes: scopedGroups,
      suggested: suggested,
    );
  }

  static bool _isHeuristicRelated(EvidenceRelationship relationship) {
    return EvidenceSemantics.isSuggestedRelated(relationship);
  }

  static bool _isCollectionHeuristic(EvidenceRelationship relationship) {
    return (relationship.reason ?? '').startsWith('Related through');
  }

  static bool _bothInSameGroup(
    String a,
    String b,
    List<Set<String>> groupMemberSets,
  ) {
    for (final members in groupMemberSets) {
      if (members.contains(a) && members.contains(b)) {
        return true;
      }
    }
    return false;
  }

  static double? _confidenceFor(
    String a,
    String b,
    List<RelationshipSuggestion> suggestions,
  ) {
    for (final suggestion in suggestions) {
      final same = (suggestion.sourceEvidenceId == a &&
              suggestion.targetEvidenceId == b) ||
          (suggestion.sourceEvidenceId == b &&
              suggestion.targetEvidenceId == a);
      if (same) {
        return suggestion.confidence;
      }
    }
    return null;
  }

  static String? _suggestedDetail(
    EvidenceRelationship relationship,
    WorkspaceEvidenceItem from,
    WorkspaceEvidenceItem to,
    List<RelationshipSuggestion> suggestions,
  ) {
    final parts = <String>[];
    final fromRelationship = _suggestedDetailFromReason(
      relationship.reason ?? '',
      from,
      to,
    );
    if (fromRelationship != null) {
      parts.add(fromRelationship);
    }
    for (final suggestion in suggestions) {
      if (suggestion.source != RelationshipSuggestionSource.ai) {
        continue;
      }
      if (!_samePair(
        suggestion.sourceEvidenceId,
        suggestion.targetEvidenceId,
        from.id,
        to.id,
      )) {
        continue;
      }
      for (final part in _independentParts(suggestion, from, to)) {
        if (!parts.contains(part)) {
          parts.add(part);
        }
      }
    }
    if (parts.isNotEmpty) {
      return parts.join(' ');
    }
    return _suggestedDetailFromReason(relationship.reason ?? '', from, to);
  }

  static String? _detailFromSuggestion(
    RelationshipSuggestion suggestion,
    WorkspaceEvidenceItem from,
    WorkspaceEvidenceItem to,
  ) {
    final parts = _independentParts(suggestion, from, to);
    if (parts.isNotEmpty) {
      return parts.join(' ');
    }
    return _suggestedDetailFromReason(suggestion.reason, from, to);
  }

  static List<String> _independentParts(
    RelationshipSuggestion suggestion,
    WorkspaceEvidenceItem from,
    WorkspaceEvidenceItem to,
  ) {
    final parts = <String>[];
    final time = suggestion.timeExplanation?.trim();
    if (time != null && time.isNotEmpty) {
      parts.add(time);
    }
    final space = suggestion.spaceExplanation?.trim();
    if (space != null && space.isNotEmpty) {
      parts.add(space);
    }
    final matter = suggestion.matterExplanation?.trim();
    if (matter != null && matter.isNotEmpty) {
      parts.add(_sentence(matter));
    }
    if (parts.isEmpty && suggestion.source == RelationshipSuggestionSource.ai) {
      final fallback = _suggestedDetailFromReason(
        suggestion.reason,
        from,
        to,
      );
      if (fallback != null) {
        parts.add(fallback);
      }
    }
    return parts;
  }

  static String _sentence(String clause) {
    if (clause.endsWith('.')) {
      return clause[0].toUpperCase() + clause.substring(1);
    }
    return '${clause[0].toUpperCase()}${clause.substring(1)}.';
  }

  static bool _samePair(String a1, String b1, String a2, String b2) {
    return (a1 == a2 && b1 == b2) || (a1 == b2 && b1 == a2);
  }

  static String? _suggestedDetailFromReason(
    String reason,
    WorkspaceEvidenceItem from,
    WorkspaceEvidenceItem to,
  ) {
    if (reason.startsWith('Suggested relationship because ')) {
      return reason;
    }
    if (reason.contains('seconds apart')) {
      final seconds =
          from.lastPreservedAt.difference(to.lastPreservedAt).inSeconds.abs();
      if (seconds <= 0) {
        return 'Captured close together';
      }
      return 'Captured $seconds seconds apart';
    }
    if (reason.contains('near the same location')) {
      return 'Captured near the same location';
    }
    return null;
  }

  static String _pairId(String a, String b) {
    return a.compareTo(b) <= 0 ? '${a}__$b' : '${b}__$a';
  }
}
