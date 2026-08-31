import 'package:flutter/foundation.dart';

import '../../domain/collection/evidence_collection.dart';
import '../../domain/relationship/relationship_suggestion.dart';
import '../../engines/evidence_semantics.dart';
import '../../models/evidence_relationship.dart';
import '../../models/relationship_type.dart';
import '../../models/workspace_evidence_item.dart';
import '../../repositories/incident_store.dart';
import '../../repositories/relationship_repository.dart';
import 'composed_relationship_provider.dart';

/// Sprint 5C — produces and applies investigation relationships.
///
/// Conservative about SUPPORTS (user / existing parent links only).
/// Deterministic RELATED may be auto-accepted from strong metadata signals.
/// Matter / content intelligence composes via [ComposedRelationshipProvider]
/// (disabled by default) and must remain RELATED-only, source: ai.
class RelationshipEngine {
  RelationshipEngine({
    RelationshipSuggestionProvider? provider,
  }) : _provider = provider ?? ComposedRelationshipProvider();

  static final RelationshipEngine instance = RelationshipEngine();

  RelationshipSuggestionProvider _provider;

  void useProvider(RelationshipSuggestionProvider provider) {
    _provider = provider;
  }

  /// Regenerates suggestions and auto-accepts high-confidence RELATED links.
  ///
  /// Safe to call asynchronously after Investigation opens — does not block capture.
  RelationshipEnsureResult ensureRelationships({
    required IncidentStore store,
    required RelationshipRepository relationshipRepository,
    double autoAcceptConfidence = 0.7,
  }) {
    final signals = _signalsFromStore(store);
    final suggestions = _provider.suggest(
      incidentId: store.incident.id,
      signals: signals,
    );

    store.relationshipSuggestions
      ..clear()
      ..addAll(suggestions);

    var created = 0;
    var skipped = 0;
    for (final suggestion in suggestions) {
      if (suggestion.relationshipType != RelationshipType.relatedTo.name) {
        skipped++;
        continue;
      }
      if (suggestion.confidence < autoAcceptConfidence) {
        skipped++;
        continue;
      }
      if (relationshipRepository.isLinked(
            sourceEvidenceId: suggestion.sourceEvidenceId,
            targetEvidenceId: suggestion.targetEvidenceId,
          ) ||
          relationshipRepository.isLinked(
            sourceEvidenceId: suggestion.targetEvidenceId,
            targetEvidenceId: suggestion.sourceEvidenceId,
          )) {
        skipped++;
        continue;
      }
      final linked = relationshipRepository.linkEvidence(
        sourceEvidenceId: suggestion.sourceEvidenceId,
        targetEvidenceId: suggestion.targetEvidenceId,
        type: RelationshipType.relatedTo,
        reason: suggestion.reason,
        source: suggestion.source.wireName,
      );
      if (linked != null) {
        created++;
        final index = store.relationshipSuggestions
            .indexWhere((s) => s.id == suggestion.id);
        if (index >= 0) {
          store.relationshipSuggestions[index] = suggestion.copyWith(
            status: RelationshipSuggestionStatus.accepted,
          );
        }
      } else {
        skipped++;
      }
    }

    debugPrint(
      '[RelationshipEngine] ensure → created=$created skipped=$skipped '
      'suggestions=${suggestions.length}',
    );
    return RelationshipEnsureResult(
      suggestions: List.unmodifiable(store.relationshipSuggestions),
      createdCount: created,
      skippedCount: skipped,
    );
  }

  /// Projects a calm investigation graph for UI (async-friendly pure function).
  InvestigationGraphView buildGraphView({
    required IncidentStore store,
    required List<WorkspaceEvidenceItem> evidence,
    required List<EvidenceRelationship> relationships,
  }) {
    final byId = {for (final e in evidence) e.id: e};
    // User-facing primary is the chronology role, not CapturedEvidence.isPrimaryEvidence.
    final primaryIds = <String>{
      for (final item in evidence)
        if (EvidenceSemantics.isPrimaryChronologyEvidence(item)) item.id,
    };

    final supportsByTarget = <String, List<String>>{};
    for (final s in store.supportingEvidence) {
      final parent = s.resolvedParentEvidenceId;
      if (parent == null) {
        continue;
      }
      supportsByTarget.putIfAbsent(parent, () => []).add(s.id);
    }

    final related = <InvestigationGraphEdge>[
      for (final rel in relationships)
        InvestigationGraphEdge(
          id: rel.id,
          sourceEvidenceId: rel.sourceEvidenceId,
          targetEvidenceId: rel.targetEvidenceId,
          // SUPPORTS stays support. RELATED / EXPLAINS / REFERENCES are not
          // supporting and are not corroboration — including metadata RELATED.
          kind: rel.type == RelationshipType.supports
              ? InvestigationGraphEdgeKind.supports
              : InvestigationGraphEdgeKind.related,
          reason: rel.reason,
          source: rel.source,
        ),
      for (final entry in supportsByTarget.entries)
        for (final supportId in entry.value)
          InvestigationGraphEdge(
            id: 'supports_${supportId}_${entry.key}',
            sourceEvidenceId: supportId,
            targetEvidenceId: entry.key,
            kind: InvestigationGraphEdgeKind.supports,
            reason: 'Supporting evidence for this primary item.',
          ),
    ];

    final collections = List<EvidenceCollection>.from(store.evidenceCollections)
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

    return InvestigationGraphView(
      primaryEvidenceIds: primaryIds.toList(),
      supportingByPrimaryId: {
        for (final e in supportsByTarget.entries)
          e.key: List<String>.unmodifiable(e.value),
      },
      edges: related,
      collections: collections,
      evidenceById: byId,
    );
  }

  static List<RelationshipEvidenceSignal> _signalsFromStore(IncidentStore store) {
    final collectionNameById = {
      for (final c in store.evidenceCollections) c.id: c.name,
    };
    return [
      for (final item in store.capturedEvidence)
        RelationshipEvidenceSignal(
          evidenceId: item.id,
          kindLabel: item.type.name,
          capturedAt: item.capturedAt,
          collectionId: item.collectionId,
          collectionName: item.collectionId == null
              ? null
              : collectionNameById[item.collectionId!],
          latitude: item.latitude,
          longitude: item.longitude,
          deviceModel: item.deviceModel,
          isPrimary: item.isPrimaryEvidence,
          timelineOrder: item.timelineOrder,
        ),
      for (final item in store.supportingEvidence)
        RelationshipEvidenceSignal(
          evidenceId: item.id,
          kindLabel: item.type.name,
          capturedAt: item.createdAt,
          collectionId: item.collectionId,
          collectionName: item.collectionId == null
              ? null
              : collectionNameById[item.collectionId!],
          latitude: item.latitude,
          longitude: item.longitude,
          deviceModel: item.deviceModel,
          parentEvidenceId: item.resolvedParentEvidenceId,
          timelineOrder: item.timelineOrder,
        ),
    ];
  }
}

class RelationshipEnsureResult {
  const RelationshipEnsureResult({
    required this.suggestions,
    required this.createdCount,
    required this.skippedCount,
  });

  final List<RelationshipSuggestion> suggestions;
  final int createdCount;
  final int skippedCount;
}

enum InvestigationGraphEdgeKind { related, supports, collectionMember }

class InvestigationGraphEdge {
  const InvestigationGraphEdge({
    required this.id,
    required this.sourceEvidenceId,
    required this.targetEvidenceId,
    required this.kind,
    this.reason,
    this.source,
  });

  final String id;
  final String sourceEvidenceId;
  final String targetEvidenceId;
  final InvestigationGraphEdgeKind kind;
  final String? reason;

  /// metadata | user | ai — preserved for consumers; Graph UI does not use it.
  final String? source;
}

/// UI-facing investigation graph snapshot (not persisted).
class InvestigationGraphView {
  const InvestigationGraphView({
    required this.primaryEvidenceIds,
    required this.supportingByPrimaryId,
    required this.edges,
    required this.collections,
    required this.evidenceById,
  });

  final List<String> primaryEvidenceIds;
  final Map<String, List<String>> supportingByPrimaryId;
  final List<InvestigationGraphEdge> edges;
  final List<EvidenceCollection> collections;
  final Map<String, WorkspaceEvidenceItem> evidenceById;

  List<WorkspaceEvidenceItem> get primaryEvidence => [
        for (final id in primaryEvidenceIds)
          if (evidenceById[id] != null) evidenceById[id]!,
      ];

  List<WorkspaceEvidenceItem> supportingFor(String primaryId) => [
        for (final id in supportingByPrimaryId[primaryId] ?? const <String>[])
          if (evidenceById[id] != null) evidenceById[id]!,
      ];
}
