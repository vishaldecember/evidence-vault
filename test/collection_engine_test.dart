import 'package:evidence_vault/controllers/workspace_evidence_controller.dart';
import 'package:evidence_vault/domain/collection/evidence_collection.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/models/workspace_evidence_factory.dart';
import 'package:evidence_vault/services/collection/collection_engine.dart';
import 'package:evidence_vault/services/collection/collection_suggestion_provider.dart';
import 'package:evidence_vault/services/collection/heuristic_collection_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    WorkspaceEvidenceFactory.resetForTests();
  });

  tearDown(() {
    WorkspaceEvidenceFactory.useProductionIds();
  });

  test(
    'heuristics group by capture type into Media / Voice / Documents / Notes',
    () {
      final controller = WorkspaceEvidenceController();
      controller.preserveEvidenceAndReturnId(WorkspaceCaptureMode.photo);
      controller.preserveEvidenceAndReturnId(WorkspaceCaptureMode.video);
      controller.preserveEvidenceAndReturnId(WorkspaceCaptureMode.voice);
      controller.preserveEvidenceAndReturnId(WorkspaceCaptureMode.file);
      controller.preserveEvidenceAndReturnId(WorkspaceCaptureMode.note);

      final collections = controller.ensureEvidenceCollections();
      final names = collections.map((c) => c.name).toSet();

      expect(
        names,
        containsAll(['Media', 'Voice Notes', 'Documents', 'Notes']),
      );
      expect(collections.fold<int>(0, (sum, c) => sum + c.count), 5);
      for (final collection in collections) {
        expect(collection.systemGenerated, isTrue);
        expect(collection.pending, isTrue);
        expect(collection.isPendingSuggestion, isTrue);
      }
      for (final item in controller.currentIncident.evidence) {
        expect(item.collectionId, isNotNull);
      }
    },
  );

  test('rename marks collection as user-refined', () {
    final controller = WorkspaceEvidenceController();
    controller.preserveEvidenceAndReturnId(WorkspaceCaptureMode.photo);
    final collections = controller.ensureEvidenceCollections();
    final id = collections.first.id;

    controller.renameEvidenceCollection(collectionId: id, name: 'Vehicle');
    final renamed = controller.evidenceCollections.firstWhere(
      (c) => c.id == id,
    );
    expect(renamed.name, 'Vehicle');
    expect(renamed.systemGenerated, isFalse);
    expect(renamed.pending, isFalse);
  });

  test('accepting a suggestion confirms the same collection in place', () {
    final controller = WorkspaceEvidenceController();
    controller.preserveEvidenceAndReturnId(WorkspaceCaptureMode.photo);
    final collections = controller.ensureEvidenceCollections();
    final id = collections.first.id;
    final members = List<String>.from(collections.first.memberEvidenceIds);

    final accepted = controller.acceptEvidenceCollection(id);
    expect(accepted, isNotNull);
    expect(accepted!.id, id);
    expect(accepted.memberEvidenceIds, members);
    expect(accepted.pending, isFalse);
    expect(accepted.systemGenerated, isFalse);
    expect(controller.evidenceCollections, hasLength(1));
    expect(controller.currentIncident.relationshipGroups, isEmpty);
  });

  test(
    'user create collection is confirmed and is not a RelationshipGroup',
    () {
      final controller = WorkspaceEvidenceController();
      final photo = controller.preserveEvidenceAndReturnId(
        WorkspaceCaptureMode.photo,
      );
      final video = controller.preserveEvidenceAndReturnId(
        WorkspaceCaptureMode.video,
      );
      controller.ensureEvidenceCollections();
      final beforeGroups = controller.currentIncident.relationshipGroups.length;

      final created = controller.createUserEvidenceCollection(
        evidenceIds: [photo, video],
      );
      expect(created, isNotNull);
      expect(created!.systemGenerated, isFalse);
      expect(created.pending, isFalse);
      expect(created.memberEvidenceIds.toSet(), {photo, video});
      expect(
        controller.currentIncident.relationshipGroups,
        hasLength(beforeGroups),
      );
      expect(
        controller.evidenceCollections.where((c) => c.id == created.id),
        hasLength(1),
      );
    },
  );

  test('dismiss keeps the collection and records the id', () {
    final controller = WorkspaceEvidenceController();
    controller.preserveEvidenceAndReturnId(WorkspaceCaptureMode.photo);
    final collections = controller.ensureEvidenceCollections();
    final id = collections.first.id;

    controller.dismissPendingEvidenceCollection(id);
    expect(controller.evidenceCollections.any((c) => c.id == id), isTrue);
    expect(
      CollectionEngine.instance.isPendingDismissed(
        store: controller.aggregate.store,
        collectionId: id,
      ),
      isTrue,
    );

    controller.restorePendingEvidenceCollection(id);
    final restored = controller.evidenceCollections.firstWhere(
      (c) => c.id == id,
    );
    expect(restored.pending, isTrue);
    expect(restored.systemGenerated, isTrue);
    expect(
      CollectionEngine.instance.isPendingDismissed(
        store: controller.aggregate.store,
        collectionId: id,
      ),
      isFalse,
    );
  });

  test('merge and move preserve membership on evidence.collectionId', () {
    final controller = WorkspaceEvidenceController();
    controller.preserveEvidenceAndReturnId(WorkspaceCaptureMode.photo);
    controller.preserveEvidenceAndReturnId(WorkspaceCaptureMode.voice);
    final collections = controller.ensureEvidenceCollections();
    expect(collections.length, greaterThanOrEqualTo(2));

    final primary = collections.first;
    final secondary = collections[1];
    final merged = controller.mergeEvidenceCollections(
      primaryId: primary.id,
      secondaryId: secondary.id,
    );
    expect(merged, isNotNull);
    expect(controller.evidenceCollections.length, collections.length - 1);

    for (final id in merged!.memberEvidenceIds) {
      final item = controller.currentIncident.evidenceById(id);
      expect(item?.collectionId, merged.id);
    }
  });

  test('CollectionSuggestionProvider can be swapped for future AI', () {
    final engine = CollectionEngine(provider: _FixedProvider());
    final controller = WorkspaceEvidenceController();
    controller.preserveEvidenceAndReturnId(WorkspaceCaptureMode.photo);
    final suggested = engine.ensureCollections(
      store: controller.aggregate.store,
    );
    expect(suggested.single.name, 'AI Reserved');
  });

  test('HeuristicCollectionProvider splits sessions by time gap', () {
    final provider = HeuristicCollectionProvider();
    final now = DateTime(2026, 8, 7, 10);
    final collections = provider.suggest(
      incidentId: 'i1',
      signals: [
        CollectionEvidenceSignal(
          evidenceId: 'a',
          kindLabel: 'photo',
          capturedAt: now,
        ),
        CollectionEvidenceSignal(
          evidenceId: 'b',
          kindLabel: 'photo',
          capturedAt: now.add(const Duration(hours: 3)),
        ),
      ],
    );
    expect(collections, hasLength(2));
    expect(collections.first.name, 'Media 1');
    expect(collections.last.name, 'Media 2');
  });

  test(
    'commitCustomGroupComposition stores IDs and deletes empty custom groups',
    () {
      final controller = WorkspaceEvidenceController();
      final photo = controller.preserveEvidenceAndReturnId(
        WorkspaceCaptureMode.photo,
      );
      final video = controller.preserveEvidenceAndReturnId(
        WorkspaceCaptureMode.video,
      );
      final evidenceCount = controller.currentIncident.evidence.length;

      expect(
        controller.commitCustomGroupComposition(
          name: 'Night',
          evidenceIds: const [],
        ),
        isNull,
      );
      expect(controller.currentIncident.evidence, hasLength(evidenceCount));

      final created = controller.commitCustomGroupComposition(
        name: 'Night',
        evidenceIds: [photo, video],
      );
      expect(created, isNotNull);
      expect(created!.memberEvidenceIds, [photo, video]);
      expect(created.category, 'custom');
      expect(controller.currentIncident.evidence, hasLength(evidenceCount));

      final reduced = controller.commitCustomGroupComposition(
        name: 'Night',
        evidenceIds: [photo],
        collectionId: created.id,
      );
      expect(reduced, isNotNull);
      expect(reduced!.memberEvidenceIds, [photo]);
      expect(
        controller.evidenceCollections
            .firstWhere((collection) => collection.id == created.id)
            .memberEvidenceIds,
        [photo],
      );

      expect(
        controller.commitCustomGroupComposition(
          name: 'Night',
          evidenceIds: const [],
          collectionId: created.id,
        ),
        isNull,
      );
      expect(
        controller.evidenceCollections.any(
          (collection) => collection.id == created.id,
        ),
        isFalse,
      );
      expect(controller.currentIncident.evidence, hasLength(evidenceCount));
    },
  );

  test('deleteUserCustomGroup never removes a system-generated group', () {
    final controller = WorkspaceEvidenceController();
    controller.preserveEvidenceAndReturnId(WorkspaceCaptureMode.photo);
    controller.preserveEvidenceAndReturnId(WorkspaceCaptureMode.video);
    final system = controller.ensureEvidenceCollections().firstWhere(
      (collection) => collection.systemGenerated,
    );
    final evidenceCount = controller.currentIncident.evidence.length;

    expect(controller.deleteUserCustomGroup(system.id), isFalse);
    expect(
      controller.evidenceCollections.any(
        (collection) => collection.id == system.id,
      ),
      isTrue,
    );
    expect(controller.currentIncident.evidence, hasLength(evidenceCount));
  });
}

class _FixedProvider implements CollectionSuggestionProvider {
  @override
  List<EvidenceCollection> suggest({
    required String incidentId,
    required List<CollectionEvidenceSignal> signals,
  }) {
    final now = DateTime.now();
    return [
      EvidenceCollection(
        id: 'col_ai',
        incidentId: incidentId,
        name: 'AI Reserved',
        systemGenerated: true,
        pending: true,
        displayOrder: 0,
        createdAt: now,
        updatedAt: now,
        memberEvidenceIds: [for (final s in signals) s.evidenceId],
      ),
    ];
  }
}
