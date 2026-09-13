import '../../engines/enrichment_engine.dart';
import '../../engines/evidence_semantics.dart';
import '../../engines/narrative_builder.dart';
import '../../mappers/evidence_projection.dart';
import '../../models/connection_group_node.dart';
import '../../models/evidence_record_model.dart';
import '../../models/evidence_relationship.dart';
import '../../models/reflection_model.dart';
import '../../models/relationship_group.dart';
import '../../models/timeline_anchor_node.dart';
import '../../models/workspace_evidence_item.dart';
import '../../repositories/incident_store.dart';
import '../../repositories/workspace_evidence_repository.dart';
import '../../services/narrative_validation_service.dart';
import '../../services/relationship_group_color_service.dart';
import '../../services/relationship_group_confidence_service.dart';
import '../incident/incident_aggregate.dart';
import 'trust_package.dart';
import 'trust_package_integrity_provenance_builder.dart';

/// Assembles a deterministic [TrustPackage] projection from [IncidentAggregate].
///
/// Never mutates the aggregate. Never duplicates evidence. Never embeds media.
abstract class TrustPackageAssembler {
  TrustPackage assemble(IncidentAggregate aggregate);
}

class DefaultTrustPackageAssembler implements TrustPackageAssembler {
  const DefaultTrustPackageAssembler({
    NarrativeBuilder? narrativeBuilder,
  }) : _narrativeBuilder = narrativeBuilder ?? const DefaultNarrativeBuilder();

  static const packageVersion = '1.0.0';
  static const generatedBy = 'My Truth';
  static const defaultIncidentType = 'General Incident';

  static const _relationshipPaletteHex = [
    '#FF3B36F4',
    '#FF16A34A',
    '#FF9333EA',
    '#FFEA580C',
    '#FFF59E0B',
    '#FF14B8A6',
  ];

  final NarrativeBuilder _narrativeBuilder;

  @override
  TrustPackage assemble(IncidentAggregate aggregate) {
    final store = aggregate.store;
    final incident = store.incident;
    final items = EvidenceSemantics.incidentScopedItems(
      EvidenceProjection.toWorkspaceItems(store),
      incident.id,
    );
    final relationships = EvidenceSemantics.incidentScopedRelationships(
      relationships: store.relationships,
      scopedItems: items,
    );
    final itemById = {for (final item in items) item.id: item};
    final timelineNodes = EvidenceSemantics.incidentScopedTimeline(
      WorkspaceEvidenceRepository.anchoredTree(
        store,
        aggregate.timelineRepository,
      ),
      incident.id,
    );
    final chronologyNodes = [
      for (final node in timelineNodes)
        if (node.capturedItem.kind.isPrimaryChronology) node,
    ];
    final groupNodes = WorkspaceEvidenceRepository.connectionGroupNodes(
      store,
      aggregate.timelineRepository,
    );
    final groups = RelationshipGroupColorService.orderedGroups(
      [
        for (final group in store.relationshipGroups)
          if (group.incidentId.isNotEmpty && group.incidentId == incident.id)
            group,
      ],
    );
    final reflections = _reflectionsFromStore(store);
    final enrichmentContext = EnrichmentContext(
      items: items,
      relationships: relationships,
    );
    final enrichment = EnrichmentEngine.compute(enrichmentContext);
    final narrativeEvents = _buildNarrativeEvents(
      aggregate: aggregate,
      timelineNodes: timelineNodes,
      groupNodes: groupNodes,
      items: items,
      groups: groups,
      reflections: reflections,
      enrichmentContext: enrichmentContext,
    );
    final reconstructionHealth =
        NarrativeValidationService.computeReconstructionHealth(
      narrativeEvents.map((event) => event.validation).toList(growable: false),
    );
    final scopedIds = itemById.keys.toSet();
    final timelineAnchorIds = {
      for (final anchor in store.timelineAnchors)
        if (scopedIds.contains(anchor.capturedEvidenceId))
          anchor.capturedEvidenceId,
    };

    final timelineSection = _buildTimelineSection(
      timelineNodes: chronologyNodes,
      groups: groups,
      itemById: itemById,
    );
    final relationshipGroupsSection = _buildRelationshipGroupsSection(
      groupNodes: groupNodes,
      groups: groups,
      timelineAnchorIds: timelineAnchorIds,
      scopedItemIds: scopedIds,
      enrichmentContext: enrichmentContext,
    );
    final reconstructionSection = _buildReconstructionSection(narrativeEvents);
    final evidenceAppendix = _buildEvidenceAppendix(
      items: items,
      groups: groups,
    );
    final integritySummary = _buildIntegritySummary(
      items: items,
      timelineNodes: timelineNodes,
      groups: groups,
      itemById: itemById,
      narrativeEvents: narrativeEvents,
      reconstructionHealth: reconstructionHealth,
    );
    final integrityProvenance =
        TrustPackageIntegrityProvenanceBuilder.fromItems(items);

    return TrustPackage(
      incidentSummary: TrustPackageIncidentSummary(
        incidentName: incident.title.trim().isEmpty
            ? 'Untitled Incident'
            : incident.title.trim(),
        incidentType: defaultIncidentType,
        incidentStatus: incident.status.label,
        dateCreated: incident.createdAt,
        dateUpdated: incident.updatedAt,
        primaryInvestigator: null,
        investigationConfidence: enrichment.journeyStage.overviewLabel,
        reconstructionHealth: reconstructionHealth.label,
      ),
      investigationSummary: _buildInvestigationSummary(
        aggregate: aggregate,
        items: items,
        relationships: relationships,
        timelineAnchorCount: chronologyNodes.length,
        narrativeEventCount: narrativeEvents.length,
      ),
      timelineSection: timelineSection,
      relationshipGroupsSection: relationshipGroupsSection,
      reconstructionSection: reconstructionSection,
      evidenceAppendix: evidenceAppendix,
      integritySummary: integritySummary,
      integrityProvenance: integrityProvenance,
      metadata: TrustPackageMetadata(
        packageVersion: packageVersion,
        generatedAt: incident.updatedAt,
        generatedBy: generatedBy,
        incidentVersion: incident.updatedAt.millisecondsSinceEpoch.toString(),
        trustPackageId: '${incident.id}@trust-package/v1',
      ),
    );
  }

  List<NarrativeEventViewModel> _buildNarrativeEvents({
    required IncidentAggregate aggregate,
    required List<TimelineAnchorNode> timelineNodes,
    required List<ConnectionGroupNode> groupNodes,
    required List<WorkspaceEvidenceItem> items,
    required List<RelationshipGroup> groups,
    required List<ReflectionModel> reflections,
    required EnrichmentContext enrichmentContext,
  }) {
    return _narrativeBuilder.build(
      NarrativeBuildContext(
        store: aggregate.store,
        timelineNodes: timelineNodes,
        groupNodes: groupNodes,
        notes: reflections,
        items: items,
        groups: groups,
        enrichmentContext: enrichmentContext,
      ),
    );
  }

  List<ReflectionModel> _reflectionsFromStore(IncidentStore store) {
    final notes = List<ReflectionModel>.from(store.reconstructionNotes)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return notes;
  }

  TrustPackageInvestigationSummary _buildInvestigationSummary({
    required IncidentAggregate aggregate,
    required List<WorkspaceEvidenceItem> items,
    required List<EvidenceRelationship> relationships,
    required int timelineAnchorCount,
    required int narrativeEventCount,
  }) {
    final incidentId = aggregate.store.incident.id;
    final primaryEvidenceCount =
        EvidenceSemantics.primaryChronologyCount(items);
    final supportingEvidenceCount = items.where((child) {
      if (EvidenceSemantics.isPrimaryChronologyEvidence(child)) {
        return false;
      }
      return items.any(
        (parent) => EvidenceSemantics.structurallySupports(
          child: child,
          parentId: parent.id,
          relationships: relationships,
        ),
      );
    }).length;
    final ownContextCount =
        items.where(_hasOwnRecordedContextFields).length;
    final reconstructionNoteCount = aggregate.store.reconstructionNotes
        .where(
          (note) =>
              note.incidentId.isNotEmpty && note.incidentId == incidentId,
        )
        .length;
    final witnessCount = items
        .where((item) => item.kind == WorkspaceEvidenceKind.witness)
        .length;
    final documentCount = items
        .where(
          (item) =>
              item.kind == WorkspaceEvidenceKind.note ||
              item.kind == WorkspaceEvidenceKind.attachment,
        )
        .length;

    return TrustPackageInvestigationSummary(
      timelineAnchorCount: timelineAnchorCount,
      relationshipGroupCount: aggregate.relationshipRepository.groups
          .where(
            (group) =>
                group.incidentId.isNotEmpty && group.incidentId == incidentId,
          )
          .length,
      narrativeEventCount: narrativeEventCount,
      primaryEvidenceCount: primaryEvidenceCount,
      supportingEvidenceCount: supportingEvidenceCount,
      contextEntryCount: ownContextCount + reconstructionNoteCount,
      witnessCount: witnessCount,
      documentCount: documentCount,
    );
  }

  TrustPackageTimelineSection _buildTimelineSection({
    required List<TimelineAnchorNode> timelineNodes,
    required List<RelationshipGroup> groups,
    required Map<String, WorkspaceEvidenceItem> itemById,
  }) {
    final entries = <TrustPackageTimelineEntry>[];

    for (final node in timelineNodes) {
      final capturedId = node.capturedItem.id;
      final relatedEvidenceIds = <String>[
        capturedId,
        ...node.supportingItems.map((item) => item.id),
      ];

      entries.add(
        TrustPackageTimelineEntry(
          timestamp: node.anchor.anchoredAt,
          title: node.capturedItem.title,
          relatedEvidenceIds: relatedEvidenceIds,
          relationshipGroupIds: _groupIdsForEvidence(capturedId, groups),
          timelineAnchorId: node.anchor.id,
          capturedEvidenceId: capturedId,
        ),
      );
    }

    return TrustPackageTimelineSection(entries: entries);
  }

  TrustPackageRelationshipGroupsSection _buildRelationshipGroupsSection({
    required List<ConnectionGroupNode> groupNodes,
    required List<RelationshipGroup> groups,
    required Set<String> timelineAnchorIds,
    required Set<String> scopedItemIds,
    required EnrichmentContext enrichmentContext,
  }) {
    final entries = <TrustPackageRelationshipGroupEntry>[];

    for (final node in groupNodes) {
      final confidence = RelationshipGroupConfidenceService.compute(
        node,
        enrichmentContext,
      );
      final members = _groupMemberIds(node)
          .where(scopedItemIds.contains)
          .toList(growable: false);
      // Non-anchor group members (layout). Not the structural-support count.
      final supportingEvidenceIds = members
          .where((id) => !timelineAnchorIds.contains(id))
          .toList(growable: false);
      final connectedTimelineAnchorIds = members
          .where(timelineAnchorIds.contains)
          .toList(growable: false);

      entries.add(
        TrustPackageRelationshipGroupEntry(
          groupId: node.group.id,
          colorHex: _colorHexForGroup(node.group),
          groupName: RelationshipGroupColorService.displayName(
            node.group,
            groups,
          ),
          supportingEvidenceIds: supportingEvidenceIds,
          connectedTimelineAnchorIds: connectedTimelineAnchorIds,
          confidenceLevel: confidence.label,
          validationStatus: '${confidence.emoji} ${confidence.label}',
        ),
      );
    }

    return TrustPackageRelationshipGroupsSection(groups: entries);
  }

  TrustPackageReconstructionSection _buildReconstructionSection(
    List<NarrativeEventViewModel> narrativeEvents,
  ) {
    final entries = narrativeEvents
        .map(
          (viewModel) => TrustPackageReconstructionEventEntry(
            eventId: viewModel.event.id,
            title: viewModel.event.title,
            summary: viewModel.event.summary,
            evidenceReferenceIds: viewModel.displayEvidence
                .map((item) => item.id)
                .toList(growable: false),
            confidence: viewModel.validation.status.label,
            validationStatus:
                '${viewModel.validation.statusEmoji} ${viewModel.validation.status.label}',
          ),
        )
        .toList(growable: false);

    return TrustPackageReconstructionSection(events: entries);
  }

  TrustPackageEvidenceAppendix _buildEvidenceAppendix({
    required List<WorkspaceEvidenceItem> items,
    required List<RelationshipGroup> groups,
  }) {
    final sortedItems = List<WorkspaceEvidenceItem>.from(items)
      ..sort((a, b) {
        final byTime = a.lastPreservedAt.compareTo(b.lastPreservedAt);
        if (byTime != 0) {
          return byTime;
        }
        return a.id.compareTo(b.id);
      });

    final entries = sortedItems
        .map(
          (item) {
            final metadata = EvidenceRecordMetadata.forItem(item);
            return TrustPackageEvidenceAppendixEntry(
              evidenceId: item.id,
              title: item.title,
              evidenceType: item.kind.label,
              timestamp: item.lastPreservedAt,
              device: metadata.device,
              location: metadata.location,
              context: _contextLabel(item),
              relationshipGroupIds: _groupIdsForEvidence(item.id, groups),
            );
          },
        )
        .toList(growable: false);

    return TrustPackageEvidenceAppendix(entries: entries);
  }

  TrustPackageIntegritySummary _buildIntegritySummary({
    required List<WorkspaceEvidenceItem> items,
    required List<TimelineAnchorNode> timelineNodes,
    required List<RelationshipGroup> groups,
    required Map<String, WorkspaceEvidenceItem> itemById,
    required List<NarrativeEventViewModel> narrativeEvents,
    required NarrativeReconstructionHealth reconstructionHealth,
  }) {
    final missingReferences = <String>[];

    for (final node in timelineNodes) {
      if (!itemById.containsKey(node.capturedItem.id)) {
        missingReferences.add(
          'Timeline anchor ${node.anchor.id} references missing evidence '
          '${node.capturedItem.id}.',
        );
      }
    }

    for (final group in groups) {
      for (final evidenceId in group.memberEvidenceIds) {
        if (!itemById.containsKey(evidenceId)) {
          missingReferences.add(
            'Relationship group ${group.id} references missing evidence '
            '$evidenceId.',
          );
        }
      }
    }

    for (final viewModel in narrativeEvents) {
      if (viewModel.hasMissingReferencedEvidence) {
        missingReferences.add(
          'Narrative event ${viewModel.event.id} references removed anchor '
          '${viewModel.event.timelineAnchorEvidenceId}.',
        );
      }
    }

    final timelineIntegrity = missingReferences.any(
          (entry) => entry.startsWith('Timeline anchor'),
        )
        ? 'Incomplete'
        : timelineNodes.isEmpty
            ? 'No Timeline Anchors'
            : 'Complete';

    final relationshipIntegrity = missingReferences.any(
          (entry) => entry.startsWith('Relationship group'),
        )
        ? 'Incomplete'
        : groups.isEmpty
            ? 'No Relationship Groups'
            : 'Complete';

    return TrustPackageIntegritySummary(
      evidenceCount: items.length,
      timelineIntegrity: timelineIntegrity,
      relationshipIntegrity: relationshipIntegrity,
      missingReferences: missingReferences,
      validationStatus: reconstructionHealth.label,
    );
  }

  static List<String> _groupIdsForEvidence(
    String evidenceId,
    List<RelationshipGroup> groups,
  ) {
    return [
      for (final group in groups)
        if (group.memberEvidenceIds.contains(evidenceId)) group.id,
    ];
  }

  static List<String> _groupMemberIds(ConnectionGroupNode node) {
    final memberIds = <String>{
      for (final entry in node.capturedEntries) entry.captured.id,
      for (final entry in node.capturedEntries)
        ...entry.supportingItems.map((item) => item.id),
      ...node.standaloneSupporting.map((item) => item.id),
    };
    return memberIds.toList()..sort();
  }

  static String _colorHexForGroup(RelationshipGroup group) {
    return _relationshipPaletteHex[
        group.colorIndex % _relationshipPaletteHex.length];
  }

  static bool _hasOwnRecordedContextFields(WorkspaceEvidenceItem item) {
    return EvidenceSemantics.hasLocation(item) ||
        EvidenceSemantics.hasWrittenDescription(item);
  }

  static String? _contextLabel(WorkspaceEvidenceItem item) {
    if (EvidenceSemantics.hasWrittenDescription(item)) {
      return item.notePreview!.trim();
    }
    if (EvidenceSemantics.hasLocation(item)) {
      return 'Location information is recorded';
    }
    return null;
  }
}
