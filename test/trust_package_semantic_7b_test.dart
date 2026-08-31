import 'package:evidence_vault/controllers/workspace_evidence_controller.dart';
import 'package:evidence_vault/domain/evidence/captured_evidence.dart';
import 'package:evidence_vault/domain/evidence/captured_evidence_type.dart';
import 'package:evidence_vault/domain/evidence/supporting_evidence.dart';
import 'package:evidence_vault/domain/evidence/supporting_evidence_type.dart';
import 'package:evidence_vault/domain/incident/incident.dart';
import 'package:evidence_vault/domain/incident/incident_aggregate.dart';
import 'package:evidence_vault/domain/incident/incident_status.dart';
import 'package:evidence_vault/domain/relationship/relationship_group.dart';
import 'package:evidence_vault/domain/trust_package/trust_package.dart';
import 'package:evidence_vault/domain/trust_package/trust_package_assembler.dart';
import 'package:evidence_vault/models/evidence_relationship.dart';
import 'package:evidence_vault/models/relationship_type.dart';
import 'package:evidence_vault/models/verification_factory.dart';
import 'package:evidence_vault/models/workspace_evidence_item.dart';
import 'package:evidence_vault/repositories/incident_store.dart';
import 'package:evidence_vault/repositories/narrative_event_repository.dart';
import 'package:flutter_test/flutter_test.dart';

WorkspaceEvidenceItem _item({
  required String id,
  WorkspaceEvidenceKind kind = WorkspaceEvidenceKind.image,
  String? parentEvidenceId,
  String? notePreview,
  String? collectionId,
  bool isContextual = false,
}) {
  return WorkspaceEvidenceItem(
    id: id,
    kind: kind,
    title: 'Evidence $id',
    lastPreservedAt: DateTime(2026, 8, 15, 12),
    integrityVerified: true,
    verification: VerificationFactory.initial(),
    parentEvidenceId: parentEvidenceId,
    notePreview: notePreview,
    collectionId: collectionId,
    isContextual: isContextual,
  );
}

CapturedEvidence _captured({
  required String id,
  required String incidentId,
  CapturedEvidenceType type = CapturedEvidenceType.photo,
  String? notePreview,
  double? latitude,
  double? longitude,
  String? collectionId,
}) {
  return CapturedEvidence(
    id: id,
    incidentId: incidentId,
    type: type,
    capturedAt: DateTime(2026, 8, 15, 12),
    title: 'Captured $id',
    integrityVerified: true,
    verification: VerificationFactory.initial(),
    timelineAnchorId: 'anchor-$id',
    notePreview: notePreview,
    latitude: latitude,
    longitude: longitude,
    collectionId: collectionId,
  );
}

SupportingEvidence _supporting({
  required String id,
  required String incidentId,
  String? parentEvidenceId,
  String? notePreview,
  String? collectionId,
}) {
  return SupportingEvidence(
    id: id,
    incidentId: incidentId,
    type: SupportingEvidenceType.note,
    createdAt: DateTime(2026, 8, 15, 12),
    title: 'Note $id',
    integrityVerified: true,
    verification: VerificationFactory.initial(),
    parentEvidenceId: parentEvidenceId,
    notePreview: notePreview,
    collectionId: collectionId,
  );
}

IncidentAggregate _storeAggregate({
  String incidentId = 'inc-A',
  List<CapturedEvidence> captured = const [],
  List<SupportingEvidence> supporting = const [],
  List<EvidenceRelationship> relationships = const [],
  List<RelationshipGroup> groups = const [],
}) {
  final now = DateTime(2026, 8, 15, 12);
  return IncidentAggregate.fromStore(
    IncidentStore(
      incident: Incident(
        id: incidentId,
        title: 'Alpha',
        status: IncidentStatus.draft,
        createdAt: now,
        updatedAt: now,
      ),
      capturedEvidence: captured,
      supportingEvidence: supporting,
      relationships: relationships,
      relationshipGroups: groups,
    ),
  );
}

String _packageLanguage(TrustPackage package) {
  final stats = package.investigationSummary;
  return [
    stats.primaryChronologyStatement,
    stats.structuralSupportStatement,
    stats.recordedContextStatement,
    '${stats.witnessCount} witness-kind',
    '${stats.documentCount} note or document',
  ].join(' ');
}

void main() {
  const assembler = DefaultTrustPackageAssembler();

  setUp(() {
    InMemoryNarrativeEventRepository.resetForTests();
  });

  test('1. Photo + Video + Voice → primary count = 3', () {
    final controller = WorkspaceEvidenceController(
      initialState: WorkspaceEvidenceState(
        items: [
          _item(id: 'photo'),
          _item(id: 'video', kind: WorkspaceEvidenceKind.video),
          _item(id: 'voice', kind: WorkspaceEvidenceKind.voice),
        ],
      ),
    );
    final package = assembler.assemble(controller.aggregate);
    expect(package.investigationSummary.primaryEvidenceCount, 3);
    expect(
      package.investigationSummary.primaryChronologyStatement,
      '3 primary chronology items',
    );
    expect(
      _packageLanguage(package).toLowerCase(),
      isNot(contains('missing primary')),
    );
  });

  test('2–3. Standalone note is not support; parent-linked note is', () {
    final controller = WorkspaceEvidenceController(
      initialState: WorkspaceEvidenceState(
        items: [
          _item(id: 'photo'),
          _item(id: 'video', kind: WorkspaceEvidenceKind.video),
          _item(id: 'voice', kind: WorkspaceEvidenceKind.voice),
          _item(id: 'standalone', kind: WorkspaceEvidenceKind.note),
          _item(
            id: 'linked',
            kind: WorkspaceEvidenceKind.note,
            parentEvidenceId: 'photo',
          ),
        ],
      ),
    );
    final package = assembler.assemble(controller.aggregate);
    expect(package.investigationSummary.primaryEvidenceCount, 3);
    expect(package.investigationSummary.supportingEvidenceCount, 1);
    expect(package.investigationSummary.documentCount, 2);
    expect(
      package.investigationSummary.structuralSupportStatement,
      '1 item is structurally linked as supporting material',
    );
  });

  test('4. Explicit SUPPORTS counts as structural support', () {
    final package = assembler.assemble(
      _storeAggregate(
        captured: [_captured(id: 'photo', incidentId: 'inc-A')],
        supporting: [_supporting(id: 'note', incidentId: 'inc-A')],
        relationships: [
          EvidenceRelationship(
            id: 'rel-supports',
            sourceEvidenceId: 'note',
            targetEvidenceId: 'photo',
            type: RelationshipType.supports,
            createdAt: DateTime(2026, 8, 15),
            source: 'user',
          ),
        ],
      ),
    );
    expect(package.investigationSummary.primaryEvidenceCount, 1);
    expect(package.investigationSummary.supportingEvidenceCount, 1);
  });

  test('5. Suggested RELATED does not count as structural support', () {
    final package = assembler.assemble(
      _storeAggregate(
        captured: [_captured(id: 'photo', incidentId: 'inc-A')],
        supporting: [_supporting(id: 'note', incidentId: 'inc-A')],
        relationships: [
          EvidenceRelationship(
            id: 'rel-suggested',
            sourceEvidenceId: 'note',
            targetEvidenceId: 'photo',
            type: RelationshipType.relatedTo,
            createdAt: DateTime(2026, 8, 15),
            source: 'metadata',
            reason: 'Related because these were captured 12 seconds apart.',
          ),
        ],
      ),
    );
    expect(package.investigationSummary.supportingEvidenceCount, 0);
  });

  test('6. User RELATED does not count as structural support', () {
    final package = assembler.assemble(
      _storeAggregate(
        captured: [_captured(id: 'photo', incidentId: 'inc-A')],
        supporting: [_supporting(id: 'note', incidentId: 'inc-A')],
        relationships: [
          EvidenceRelationship(
            id: 'rel-user',
            sourceEvidenceId: 'note',
            targetEvidenceId: 'photo',
            type: RelationshipType.relatedTo,
            createdAt: DateTime(2026, 8, 15),
            source: 'user',
          ),
        ],
      ),
    );
    expect(package.investigationSummary.supportingEvidenceCount, 0);
  });

  test('7. Collection membership does not count as structural support', () {
    final package = assembler.assemble(
      _storeAggregate(
        captured: [
          _captured(
            id: 'photo',
            incidentId: 'inc-A',
            collectionId: 'col-1',
          ),
        ],
        supporting: [
          _supporting(
            id: 'note',
            incidentId: 'inc-A',
            collectionId: 'col-1',
          ),
        ],
      ),
    );
    expect(package.investigationSummary.supportingEvidenceCount, 0);
  });

  test('8. Group membership does not count as structural support', () {
    final controller = WorkspaceEvidenceController(
      initialState: WorkspaceEvidenceState(
        items: [
          _item(id: 'photo'),
          _item(id: 'standalone', kind: WorkspaceEvidenceKind.note),
        ],
      ),
    );
    controller.commitRelationshipGroup(evidenceIds: ['photo', 'standalone']);
    final package = assembler.assemble(controller.aggregate);
    expect(package.investigationSummary.supportingEvidenceCount, 0);
    expect(package.investigationSummary.documentCount, 1);
  });

  test('9. Timestamp alone does not count as context', () {
    final controller = WorkspaceEvidenceController(
      initialState: WorkspaceEvidenceState(items: [_item(id: 'photo')]),
    );
    final package = assembler.assemble(controller.aggregate);
    expect(package.investigationSummary.contextEntryCount, 0);
    expect(
      package.investigationSummary.recordedContextStatement,
      'No recorded location or written context is currently attached',
    );
  });

  test('10. Location counts as location context', () {
    final package = assembler.assemble(
      _storeAggregate(
        captured: [
          _captured(
            id: 'photo',
            incidentId: 'inc-A',
            latitude: 27.7,
            longitude: 85.3,
          ),
        ],
      ),
    );
    expect(package.investigationSummary.contextEntryCount, 1);
    expect(
      package.investigationSummary.recordedContextStatement,
      'Location or written context is recorded',
    );
    expect(
      package.evidenceAppendix.entries.single.context,
      'Location information is recorded',
    );
  });

  test('11. Written description counts as written context', () {
    final controller = WorkspaceEvidenceController(
      initialState: WorkspaceEvidenceState(
        items: [_item(id: 'photo', notePreview: 'Door was unlocked.')],
      ),
    );
    final package = assembler.assemble(controller.aggregate);
    expect(package.investigationSummary.contextEntryCount, 1);
    expect(
      package.evidenceAppendix.entries.single.context,
      'Door was unlocked.',
    );
  });

  test('12. Parent linkage alone does not mean context', () {
    final controller = WorkspaceEvidenceController(
      initialState: WorkspaceEvidenceState(
        items: [
          _item(id: 'photo'),
          _item(
            id: 'linked',
            kind: WorkspaceEvidenceKind.note,
            parentEvidenceId: 'photo',
          ),
        ],
      ),
    );
    final package = assembler.assemble(controller.aggregate);
    expect(package.investigationSummary.supportingEvidenceCount, 1);
    expect(package.investigationSummary.contextEntryCount, 0);
    expect(
      package.evidenceAppendix.entries
          .firstWhere((entry) => entry.evidenceId == 'linked')
          .context,
      isNull,
    );
  });

  test('13. Foreign incident evidence is rejected from Trust Package', () {
    final package = assembler.assemble(
      _storeAggregate(
        incidentId: 'inc-A',
        captured: [
          _captured(id: 'photo-a', incidentId: 'inc-A'),
          _captured(id: 'photo-b', incidentId: 'inc-B'),
        ],
        supporting: [
          _supporting(
            id: 'note-b',
            incidentId: 'inc-B',
            parentEvidenceId: 'photo-b',
          ),
        ],
      ),
    );
    expect(package.investigationSummary.primaryEvidenceCount, 1);
    expect(package.investigationSummary.supportingEvidenceCount, 0);
    expect(
      package.evidenceAppendix.entries.map((entry) => entry.evidenceId),
      ['photo-a'],
    );
  });

  test('14–15. Language is factual and does not confuse kind with support', () {
    final controller = WorkspaceEvidenceController(
      initialState: WorkspaceEvidenceState(
        items: [
          _item(id: 'photo'),
          _item(id: 'video', kind: WorkspaceEvidenceKind.video),
          _item(id: 'voice', kind: WorkspaceEvidenceKind.voice),
          _item(id: 'standalone', kind: WorkspaceEvidenceKind.note),
          _item(
            id: 'linked',
            kind: WorkspaceEvidenceKind.note,
            parentEvidenceId: 'photo',
          ),
        ],
      ),
    );
    final package = assembler.assemble(controller.aggregate);
    final language = _packageLanguage(package).toLowerCase();
    expect(language, isNot(contains('corroborat')));
    expect(language, isNot(contains('verified')));
    expect(language, isNot(contains('proven')));
    expect(language, isNot(contains('confirmed')));
    expect(language, isNot(contains('weak evidence')));
    expect(language, isNot(contains('missing primary')));
    expect(language, isNot(contains('missing witness')));
    expect(package.investigationSummary.documentCount, 2);
    expect(package.investigationSummary.supportingEvidenceCount, 1);
    expect(
      language,
      contains('structurally linked as supporting material'),
    );
    expect(language, contains('note or document'));
  });
}
