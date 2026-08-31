import 'package:evidence_vault/controllers/workspace_evidence_controller.dart';
import 'package:evidence_vault/domain/incident/incident.dart';
import 'package:evidence_vault/domain/incident/incident_aggregate.dart';
import 'package:evidence_vault/domain/incident/incident_status.dart';
import 'package:evidence_vault/domain/vault/incident_collection.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/repositories/firebase/firestore_paths.dart';
import 'package:evidence_vault/repositories/firebase/firestore_serializers.dart';
import 'package:evidence_vault/services/vault/incident_collection_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('IncidentCollection model', () {
    test('constructs with normalized unique membership in first-seen order', () {
      final created = DateTime.utc(2026, 8, 23, 12);
      final collection = IncidentCollection(
        id: 'collection-1',
        title: 'Building Issues',
        createdAt: created,
        updatedAt: created,
        memberIncidentIds: const [
          ' incident-A ',
          'incident-B',
          'incident-A',
          '',
          'incident-C',
        ],
      );

      expect(collection.id, 'collection-1');
      expect(collection.title, 'Building Issues');
      expect(collection.memberIncidentIds, ['incident-A', 'incident-B', 'incident-C']);
      expect(collection.count, 3);
      expect(collection.contains('incident-A'), isTrue);
    });

    test('serialization round-trips with equality', () {
      final collection = IncidentCollection(
        id: 'collection-round',
        title: 'Building Issues',
        createdAt: DateTime.utc(2026, 8, 23, 10, 42, 15),
        updatedAt: DateTime.utc(2026, 8, 23, 11, 5, 0),
        memberIncidentIds: const ['incident-A', 'incident-B'],
      );

      final map = FirestoreSerializers.incidentCollectionToMap(collection);
      expect(map.keys.toSet(), {
        'collectionId',
        'title',
        'memberIncidentIds',
        'createdAt',
        'updatedAt',
      });
      expect(map.containsKey('status'), isFalse);
      expect(map.containsKey('evidenceCount'), isFalse);
      expect(map.containsKey('coverEvidenceId'), isFalse);

      final restored = FirestoreSerializers.incidentCollectionFromMap(
        map,
        'collection-round',
      );
      expect(restored, collection);
    });

    test('fromMap prefers collectionId then falls back to document id', () {
      final restored = FirestoreSerializers.incidentCollectionFromMap(
        {
          'title': 'Orphans',
          'memberIncidentIds': <String>['incident-Z'],
        },
        'collection-doc',
      );
      expect(restored.id, 'collection-doc');
      expect(restored.memberIncidentIds, ['incident-Z']);
    });
  });

  group('IncidentCollection membership', () {
    final created = DateTime.utc(2026, 8, 23, 9);

    IncidentCollection seed() => IncidentCollection(
          id: 'collection-mem',
          title: 'Building Issues',
          createdAt: created,
          updatedAt: created,
        );

    test('add, duplicate add, remove, and non-member remove are safe', () {
      var collection = seed();
      final t1 = DateTime.utc(2026, 8, 23, 9, 1);
      collection = collection.withMember('incident-C', updatedAt: t1);
      collection = collection.withMember('incident-A', updatedAt: t1);
      collection = collection.withMember('incident-B', updatedAt: t1);
      expect(
        collection.memberIncidentIds,
        ['incident-C', 'incident-A', 'incident-B'],
      );

      final afterDuplicate = collection.withMember(
        'incident-A',
        updatedAt: DateTime.utc(2026, 8, 23, 10),
      );
      expect(identical(afterDuplicate, collection), isTrue);
      expect(
        afterDuplicate.memberIncidentIds,
        ['incident-C', 'incident-A', 'incident-B'],
      );

      final afterMissingRemove = collection.withoutMember('incident-X');
      expect(identical(afterMissingRemove, collection), isTrue);

      final afterRemove = collection.withoutMember(
        'incident-A',
        updatedAt: DateTime.utc(2026, 8, 23, 9, 2),
      );
      expect(afterRemove.memberIncidentIds, ['incident-C', 'incident-B']);
    });
  });

  group('IncidentCollectionStore', () {
    late IncidentCollectionStore store;

    setUp(() {
      store = IncidentCollectionStore();
    });

    test('create, read, list, title update, membership, and delete', () async {
      const userId = 'user-1';
      final created = await store.create(
        userId: userId,
        title: ' Building Issues ',
        memberIncidentIds: const ['incident-A'],
      );
      expect(created.title, 'Building Issues');
      expect(created.memberIncidentIds, ['incident-A']);
      expect(
        FirestorePaths.incidentCollection(userId, created.id),
        'users/user-1/incidentCollections/${created.id}',
      );

      expect(
        await store.get(userId: userId, collectionId: created.id),
        created,
      );

      final listed = await store.list(userId: userId);
      expect(listed.map((c) => c.id), [created.id]);

      final renamed = await store.updateTitle(
        userId: userId,
        collectionId: created.id,
        title: '  Site issues  ',
      );
      expect(renamed!.title, 'Site issues');
      expect(renamed.createdAt, created.createdAt);
      expect(renamed.memberIncidentIds, ['incident-A']);

      final withB = await store.addMember(
        userId: userId,
        collectionId: created.id,
        incidentId: 'incident-B',
      );
      final duplicate = await store.addMember(
        userId: userId,
        collectionId: created.id,
        incidentId: 'incident-B',
      );
      expect(identical(duplicate, withB), isTrue);
      expect(withB!.memberIncidentIds, ['incident-A', 'incident-B']);

      final missingRemove = await store.removeMember(
        userId: userId,
        collectionId: created.id,
        incidentId: 'incident-Z',
      );
      expect(identical(missingRemove, withB), isTrue);

      final removed = await store.removeMember(
        userId: userId,
        collectionId: created.id,
        incidentId: 'incident-A',
      );
      expect(removed!.memberIncidentIds, ['incident-B']);

      await store.delete(userId: userId, collectionId: created.id);
      expect(await store.get(userId: userId, collectionId: created.id), isNull);
      expect(await store.list(userId: userId), isEmpty);
    });

    test('membership and delete do not alter incident, evidence, or archive',
        () async {
      final archived = Incident(
        id: 'incident-archived',
        title: 'Old leak',
        status: IncidentStatus.archived,
        createdAt: DateTime.utc(2026, 8, 1),
        updatedAt: DateTime.utc(2026, 8, 2),
      );
      final controller = WorkspaceEvidenceController(
        aggregate: IncidentAggregate.shell(
          id: 'incident-active',
          title: 'Lobby camera',
        ),
      );
      controller.preserveEvidence(WorkspaceCaptureMode.photo);
      controller.preserveEvidence(WorkspaceCaptureMode.note);

      Incident snapshotIncident() => controller.currentIncident.incident;
      final incidentBefore = snapshotIncident();
      final evidenceBefore = [
        for (final item in controller.currentIncident.evidence)
          (
            item.id,
            item.lastPreservedAt,
            item.parentEvidenceId,
            item.kind,
          ),
      ];
      final statusBefore = incidentBefore.status;
      final archiveBefore = archived.status;
      final chronologyBefore = controller.currentIncident.evidence
          .map((e) => e.lastPreservedAt)
          .toList();

      final collection = await store.create(
        userId: 'user-iso',
        title: 'Building Issues',
        memberIncidentIds: [incidentBefore.id, archived.id],
      );
      await store.addMember(
        userId: 'user-iso',
        collectionId: collection.id,
        incidentId: incidentBefore.id,
      );
      await store.removeMember(
        userId: 'user-iso',
        collectionId: collection.id,
        incidentId: archived.id,
      );
      await store.delete(userId: 'user-iso', collectionId: collection.id);

      final incidentAfter = snapshotIncident();
      expect(incidentAfter.id, incidentBefore.id);
      expect(incidentAfter.title, incidentBefore.title);
      expect(incidentAfter.status, statusBefore);
      expect(incidentAfter.createdAt, incidentBefore.createdAt);
      expect(incidentAfter.updatedAt, incidentBefore.updatedAt);
      expect(incidentAfter.manuallyComplete, incidentBefore.manuallyComplete);
      expect(archived.status, archiveBefore);
      expect(archived.title, 'Old leak');
      expect(
        [
          for (final item in controller.currentIncident.evidence)
            (
              item.id,
              item.lastPreservedAt,
              item.parentEvidenceId,
              item.kind,
            ),
        ],
        evidenceBefore,
      );
      expect(
        controller.currentIncident.evidence.map((e) => e.lastPreservedAt),
        chronologyBefore,
      );
      expect(controller.currentIncident.relationshipGroups, isEmpty);
    });

    test('users do not share collections', () async {
      final a = await store.create(
        userId: 'user-a',
        title: 'A',
        memberIncidentIds: const ['incident-1'],
      );
      expect(await store.list(userId: 'user-b'), isEmpty);
      expect(await store.get(userId: 'user-b', collectionId: a.id), isNull);
    });
  });
}
