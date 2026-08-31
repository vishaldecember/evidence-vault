import 'package:evidence_vault/domain/evidence/captured_evidence.dart';
import 'package:evidence_vault/domain/evidence/captured_evidence_type.dart';
import 'package:evidence_vault/domain/evidence/evidence_record_type.dart';
import 'package:evidence_vault/domain/evidence/evidence_sync_status.dart';
import 'package:evidence_vault/domain/incident/incident.dart';
import 'package:evidence_vault/domain/incident/incident_status.dart';
import 'package:evidence_vault/models/verification_factory.dart';
import 'package:evidence_vault/presentation/incident_cover_resolver.dart';
import 'package:evidence_vault/repositories/firebase/firestore_serializers.dart';
import 'package:evidence_vault/repositories/incident_repository.dart';
import 'package:evidence_vault/repositories/incident_store.dart';
import 'package:evidence_vault/services/storage/cached_evidence_entry.dart';
import 'package:evidence_vault/widgets/vault/incident_cover_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Incident _incident({
  String id = 'incident-a',
  String? coverEvidenceId,
}) {
  return Incident(
    id: id,
    title: 'Alpha',
    status: IncidentStatus.active,
    createdAt: DateTime.utc(2026, 8, 20),
    updatedAt: DateTime.utc(2026, 8, 21),
    coverEvidenceId: coverEvidenceId,
  );
}

CapturedEvidence _evidence({
  required String id,
  required String incidentId,
  String? thumbnailPath,
  String? contentHash,
}) {
  final now = DateTime.utc(2026, 8, 20, 12);
  return CapturedEvidence(
    id: id,
    incidentId: incidentId,
    type: CapturedEvidenceType.photo,
    capturedAt: now,
    title: 'Photo',
    integrityVerified: true,
    verification: VerificationFactory.initial(),
    timelineAnchorId: 'anchor-$id',
    thumbnailPath: thumbnailPath,
    filePath: '/evidence/$id.jpg',
    contentHash: contentHash,
    timelineOrder: 1,
  );
}

CachedEvidenceEntry _cached({
  required String evidenceId,
  required String incidentId,
  String? thumbnailPath,
  String? localFilePath,
  String? hash,
}) {
  final now = DateTime.utc(2026, 8, 20, 12);
  return CachedEvidenceEntry(
    evidenceId: evidenceId,
    incidentId: incidentId,
    userId: 'user-a',
    evidenceType: EvidenceRecordType.photo,
    createdAt: now,
    capturedAt: now,
    syncStatus: EvidenceSyncStatus.localCaptured,
    thumbnailPath: thumbnailPath,
    localFilePath: localFilePath,
    hash: hash,
  );
}

void main() {
  test('coverEvidenceId round-trips and old documents stay valid', () {
    final withCover = _incident(coverEvidenceId: 'evidence-a1');
    final map = FirestoreSerializers.incidentToMap(
      incident: withCover,
      ownerId: 'user-a',
      timelineCount: 1,
      relationshipCount: 0,
      narrativeCount: 0,
      reconstructionHealth: 40,
    );
    expect(map['coverEvidenceId'], 'evidence-a1');
    expect(map.containsKey('title'), isTrue);
    expect(map.containsKey('thumbnailPath'), isFalse);
    expect(map.containsKey('thumbnailUrl'), isFalse);

    final restored = FirestoreSerializers.incidentFromMap(map, withCover.id);
    expect(restored.coverEvidenceId, 'evidence-a1');
    expect(restored.id, withCover.id);
    expect(restored.title, withCover.title);
    expect(restored.createdAt, withCover.createdAt);
    expect(restored.status, withCover.status);

    final legacy = FirestoreSerializers.incidentFromMap(
      {
        'incidentId': 'incident-legacy',
        'title': 'Legacy',
        'status': 'draft',
        'createdAt': DateTime.utc(2026, 1, 1).toIso8601String(),
        'updatedAt': DateTime.utc(2026, 1, 2).toIso8601String(),
      },
      'incident-legacy',
    );
    expect(legacy.coverEvidenceId, isNull);
    expect(legacy.id, 'incident-legacy');
    expect(legacy.title, 'Legacy');
  });

  test('blank coverEvidenceId deserializes as unset', () {
    final incident = FirestoreSerializers.incidentFromMap(
      {
        'incidentId': 'incident-a',
        'title': 'Alpha',
        'status': 'active',
        'coverEvidenceId': '  ',
        'createdAt': DateTime.utc(2026, 8, 20).toIso8601String(),
        'updatedAt': DateTime.utc(2026, 8, 21).toIso8601String(),
      },
      'incident-a',
    );
    expect(incident.coverEvidenceId, isNull);
  });

  test('valid same-incident cover resolves existing thumbnail', () async {
    final resolution = await IncidentCoverResolver.resolve(
      incidentId: 'incident-a',
      coverEvidenceId: 'evidence-a1',
      cachedEntry: _cached(
        evidenceId: 'evidence-a1',
        incidentId: 'incident-a',
        thumbnailPath: '/cache/incident-a/evidence-a1_thumb.jpg',
        localFilePath: '/cache/incident-a/evidence-a1.jpg',
      ),
    );
    expect(resolution.hasThumbnail, isTrue);
    expect(
      resolution.thumbnailPath,
      '/cache/incident-a/evidence-a1_thumb.jpg',
    );
  });

  test('cross-incident cover does not resolve', () async {
    final resolution = await IncidentCoverResolver.resolve(
      incidentId: 'incident-a',
      coverEvidenceId: 'evidence-b1',
      cachedEntry: _cached(
        evidenceId: 'evidence-b1',
        incidentId: 'incident-b',
        thumbnailPath: '/cache/incident-b/evidence-b1_thumb.jpg',
      ),
    );
    expect(resolution.hasThumbnail, isFalse);
    expect(resolution.thumbnailPath, isNull);
  });

  test('missing evidence and missing thumbnail fall back', () async {
    expect(
      (await IncidentCoverResolver.resolve(
        incidentId: 'incident-a',
        coverEvidenceId: 'missing',
      ))
          .hasThumbnail,
      isFalse,
    );
    expect(
      (await IncidentCoverResolver.resolve(
        incidentId: 'incident-a',
        coverEvidenceId: 'evidence-a1',
        cachedEntry: _cached(
          evidenceId: 'evidence-a1',
          incidentId: 'incident-a',
        ),
      ))
          .hasThumbnail,
      isFalse,
    );
    expect(
      (await IncidentCoverResolver.resolve(
        incidentId: 'incident-a',
        coverEvidenceId: 'evidence-a1',
        cachedEntry: _cached(
          evidenceId: 'evidence-a1',
          incidentId: 'incident-a',
          thumbnailPath: '/cache/incident-a/evidence-a1.jpg',
          localFilePath: '/cache/incident-a/evidence-a1.jpg',
        ),
      ))
          .hasThumbnail,
      isFalse,
    );
    expect(
      (await IncidentCoverResolver.resolve(
        incidentId: 'incident-a',
      ))
          .hasThumbnail,
      isFalse,
    );
  });

  test('setCoverEvidenceId does not mutate evidence or incident timestamps', () {
    final evidence = _evidence(
      id: 'evidence-a1',
      incidentId: 'incident-a',
      thumbnailPath: '/thumbs/a1.jpg',
      contentHash: 'hash-a1',
    );
    final store = IncidentStore(
      incident: _incident(),
      capturedEvidence: [evidence],
    );
    final repository = InMemoryIncidentRepository(store);
    final before = store.capturedEvidence.single;

    repository.setCoverEvidenceId('evidence-a1');

    expect(store.incident.coverEvidenceId, 'evidence-a1');
    expect(store.incident.updatedAt, DateTime.utc(2026, 8, 21));
    expect(store.incident.createdAt, DateTime.utc(2026, 8, 20));
    expect(store.incident.title, 'Alpha');
    expect(store.incident.status, IncidentStatus.active);
    expect(identical(store.capturedEvidence.single, before), isTrue);
    expect(store.capturedEvidence.single.contentHash, 'hash-a1');
    expect(store.capturedEvidence.single.capturedAt, before.capturedAt);
    expect(store.capturedEvidence.single.timelineOrder, 1);
    expect(store.capturedEvidence.single.filePath, before.filePath);
    expect(store.capturedEvidence.single.thumbnailPath, before.thumbnailPath);
    expect(store.timelineAnchors, isEmpty);
  });

  test('setCoverEvidenceId rejects evidence owned by another incident', () {
    final store = IncidentStore(
      incident: _incident(),
      capturedEvidence: [
        _evidence(id: 'evidence-b1', incidentId: 'incident-b'),
      ],
    );
    InMemoryIncidentRepository(store).setCoverEvidenceId('evidence-b1');
    expect(store.incident.coverEvidenceId, isNull);
  });

  test('cover pointer survives serializer reload', () {
    final store = IncidentStore(incident: _incident());
    InMemoryIncidentRepository(store).setCoverEvidenceId('evidence-a1');
    final map = FirestoreSerializers.incidentToMap(
      incident: store.incident,
      ownerId: 'user-a',
      timelineCount: 0,
      relationshipCount: 0,
      narrativeCount: 0,
      reconstructionHealth: 0,
    );
    final reloaded = FirestoreSerializers.incidentFromMap(map, 'incident-a');
    expect(reloaded.coverEvidenceId, 'evidence-a1');
    expect(reloaded.title, 'Alpha');
  });

  testWidgets('preview shows resolved thumb and hides fallback', (tester) async {
    final resolved = await IncidentCoverResolver.resolve(
      incidentId: 'incident-a',
      coverEvidenceId: 'evidence-a1',
      cachedEntry: _cached(
        evidenceId: 'evidence-a1',
        incidentId: 'incident-a',
        thumbnailPath: '/cache/incident-a/evidence-a1_thumb.jpg',
        localFilePath: '/cache/incident-a/evidence-a1.jpg',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: IncidentCoverPreview(
          incidentId: 'incident-a',
          resolution: resolved,
        ),
      ),
    );
    expect(
      find.byKey(IncidentCoverPreview.resolvedKey('incident-a')),
      findsOneWidget,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: IncidentCoverPreview(
          incidentId: 'incident-a',
          resolution: IncidentCoverResolution.fallback,
        ),
      ),
    );
    expect(
      find.byKey(IncidentCoverPreview.fallbackKey('incident-a')),
      findsOneWidget,
    );
    expect(
      find.byKey(IncidentCoverPreview.resolvedKey('incident-a')),
      findsNothing,
    );
  });
}
