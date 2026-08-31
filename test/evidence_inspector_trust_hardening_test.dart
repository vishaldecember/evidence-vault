import 'package:evidence_vault/controllers/workspace_evidence_controller.dart';
import 'package:evidence_vault/domain/incident/incident_aggregate.dart';
import 'package:evidence_vault/domain/participant/evidence_person_relationship.dart';
import 'package:evidence_vault/domain/participant/related_person_metadata.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/models/workspace_evidence_item.dart';
import 'package:evidence_vault/repositories/firebase/firestore_serializers.dart';
import 'package:evidence_vault/repositories/incident_store.dart';
import 'package:evidence_vault/services/storage/cached_evidence_entry.dart';
import 'package:evidence_vault/domain/evidence/evidence_record_type.dart';
import 'package:evidence_vault/domain/evidence/evidence_sync_status.dart';
import 'package:evidence_vault/utils/instant_codec.dart';
import 'package:evidence_vault/utils/workspace_evidence_formatters.dart';
import 'package:evidence_vault/widgets/evidence_inspector/evidence_inspector_preview.dart';
import 'package:evidence_vault/widgets/evidence_inspector/evidence_spatial_carousel.dart';
import 'package:evidence_vault/widgets/investigation/investigation_evidence_inspector_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

Future<void> _openInspector(
  WidgetTester tester, {
  required WorkspaceEvidenceController controller,
  required WorkspaceEvidenceItem evidence,
  List<WorkspaceEvidenceItem>? ordered,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          return Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () {
                  showInvestigationEvidenceInspectorModal(
                    context: context,
                    evidence: evidence,
                    controller: controller,
                    orderedEvidence: ordered ??
                        evidenceInspectorOrder(controller.journeyEvidenceItems),
                  );
                },
                child: const Text('Open Inspector'),
              ),
            ),
          );
        },
      ),
    ),
  );
  await tester.tap(find.text('Open Inspector'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pumpAndSettle();
}

WorkspaceEvidenceController _hydrateLikeRestart(
  WorkspaceEvidenceController source,
) {
  final captured = [
    for (final item in source.evidenceRepository.capturedEvidence)
      FirestoreSerializers.capturedFromMap(
        FirestoreSerializers.capturedToMap(
          item,
          userId: 'uid-1',
          timelineOrder: 0,
          supportingEvidenceIds: const [],
        ),
      )!,
  ];
  final supporting = [
    for (final item in source.evidenceRepository.supportingEvidence)
      FirestoreSerializers.supportingFromMap(
        FirestoreSerializers.supportingToMap(
          item,
          userId: 'uid-1',
          timelineOrder: 0,
          supportingEvidenceIds: const [],
        ),
      )!,
  ];
  final participants = [
    for (final participant in source.participantRepository.getByIncident())
      FirestoreSerializers.participantFromMap(
        FirestoreSerializers.participantToMap(participant),
        participant.id,
      ),
  ];
  return WorkspaceEvidenceController(
    aggregate: IncidentAggregate.fromStore(
      IncidentStore(
        incident: source.aggregate.incident,
        capturedEvidence: captured,
        supportingEvidence: supporting,
        participants: participants,
        timelineAnchors: List.of(source.aggregate.store.timelineAnchors),
      ),
    ),
  );
}

void main() {
  group('timestamp codec + Inspector clock', () {
    test('stores UTC with Z and decodes the same instant', () {
      final original = DateTime.utc(2026, 8, 13, 14, 58, 17, 321);
      final encoded = InstantCodec.encode(original);
      expect(encoded.endsWith('Z'), isTrue);
      final decoded = InstantCodec.decode(encoded)!;
      expect(decoded.isUtc, isTrue);
      expect(decoded.millisecondsSinceEpoch, original.millisecondsSinceEpoch);
    });

    test('naive legacy ISO is treated as local then stored as UTC instant', () {
      final local = DateTime(2026, 8, 13, 20, 43, 17);
      final naive = local.toIso8601String();
      expect(naive.contains('Z'), isFalse);
      final decoded = InstantCodec.decode(naive)!;
      expect(decoded.toLocal().hour, local.hour);
      expect(decoded.toLocal().minute, local.minute);
      expect(decoded.toLocal().second, local.second);
    });

    test('UTC → local conversion occurs exactly once', () {
      final utc = DateTime.utc(2026, 8, 13, 14, 58, 17);
      final once = InstantCodec.toLocal(utc);
      final twice = InstantCodec.toLocal(once);
      expect(once, twice);
      expect(
        WorkspaceEvidenceFormatters.inspectorTimestamp(utc),
        WorkspaceEvidenceFormatters.inspectorTimestamp(once),
      );
      final localClock = DateFormat('HH:mm:ss').format(once);
      expect(
        WorkspaceEvidenceFormatters.inspectorTimestamp(utc),
        contains(localClock),
      );
      if (DateTime.now().timeZoneOffset != Duration.zero) {
        expect(
          WorkspaceEvidenceFormatters.inspectorTimestamp(utc),
          isNot(contains(DateFormat('HH:mm:ss').format(utc))),
        );
      }
    });

    test('Nepal UTC+05:45 maps 14:58:17 UTC to 20:43:17 wall clock', () {
      const nepal = Duration(hours: 5, minutes: 45);
      final utc = DateTime.utc(2026, 8, 13, 14, 58, 17);
      final wall = utc.add(nepal);
      expect(DateFormat('HH:mm:ss').format(wall), '20:43:17');
      if (DateTime.now().timeZoneOffset == nepal) {
        expect(
          WorkspaceEvidenceFormatters.inspectorTimestamp(utc),
          contains('20:43:17'),
        );
      }
    });

    test('Inspector timestamp includes seconds', () {
      final utc = DateTime.utc(2026, 8, 12, 12, 4, 39);
      final formatted = WorkspaceEvidenceFormatters.inspectorTimestamp(
        utc,
        now: DateTime.utc(2026, 8, 13, 12),
      );
      expect(formatted, contains(RegExp(r'\d{2}:\d{2}:\d{2}')));
      expect(formatted.contains(RegExp(r'• \d{2}:\d{2}$')), isFalse);
    });

    test('hydration preserves capture timestamp through Firestore maps', () {
      final controller = WorkspaceEvidenceController();
      final captured = controller.evidenceRepository.addCapturedFromCaptureMode(
        WorkspaceCaptureMode.photo,
      );
      final map = FirestoreSerializers.capturedToMap(
        captured,
        userId: 'uid-1',
        timelineOrder: 0,
        supportingEvidenceIds: const [],
      );
      expect((map['capturedAt'] as String).endsWith('Z'), isTrue);
      final restored = FirestoreSerializers.capturedFromMap(map)!;
      expect(restored.id, captured.id);
      expect(restored.incidentId, captured.incidentId);
      expect(
        restored.capturedAt.toUtc().millisecondsSinceEpoch,
        captured.capturedAt.toUtc().millisecondsSinceEpoch,
      );
    });

    test('local cache round-trip preserves capture instant', () {
      final capturedAt = DateTime.utc(2026, 8, 13, 14, 58, 17, 500);
      final entry = CachedEvidenceEntry(
        evidenceId: 'ev-1',
        incidentId: 'inc-1',
        userId: 'uid-1',
        evidenceType: EvidenceRecordType.photo,
        createdAt: capturedAt,
        capturedAt: capturedAt,
        syncStatus: EvidenceSyncStatus.localCaptured,
      );
      final restored = CachedEvidenceEntry.fromJson(entry.toJson());
      expect(
        restored.capturedAt.toUtc().millisecondsSinceEpoch,
        capturedAt.millisecondsSinceEpoch,
      );
    });

    test('independent evidence items keep independent timestamps', () {
      final controller = WorkspaceEvidenceController();
      final first = controller.evidenceRepository.addCapturedFromCaptureMode(
        WorkspaceCaptureMode.photo,
      );
      final second = controller.evidenceRepository.addCapturedFromCaptureMode(
        WorkspaceCaptureMode.photo,
      );
      expect(first.capturedAt, isNot(second.capturedAt));
      expect(
        first.capturedAt.microsecondsSinceEpoch,
        isNot(second.capturedAt.microsecondsSinceEpoch),
      );
    });
  });

  group('description timestamps', () {
    test('description created/updated stamps are independent of capture time',
        () async {
      final controller = WorkspaceEvidenceController();
      final captured = controller.evidenceRepository.addCapturedFromCaptureMode(
        WorkspaceCaptureMode.photo,
      );
      final captureAt = captured.capturedAt;
      await Future<void>.delayed(const Duration(milliseconds: 8));
      final noteId = controller.addContextTextNote(
        parentEvidenceId: captured.id,
        text: 'Jsydidks',
      );
      expect(noteId, isNotNull);
      final created = controller.evidenceRepository.supportingById(noteId!)!;
      expect(created.createdAt, isNot(captureAt));
      expect(created.updatedAt, isNull);

      await Future<void>.delayed(const Duration(milliseconds: 8));
      controller.updateEvidenceNoteText(
        evidenceId: noteId,
        text: 'Jsydidks — person entered from the north side.',
      );
      final updated = controller.evidenceRepository.supportingById(noteId)!;
      expect(updated.createdAt, created.createdAt);
      expect(updated.updatedAt, isNotNull);
      expect(updated.updatedAt!.isAfter(updated.createdAt), isTrue);
      expect(
        controller.evidenceRepository.capturedById(captured.id)!.capturedAt,
        captureAt,
      );
    });

    test('description hydrates after simulated restart', () {
      final source = WorkspaceEvidenceController();
      final captured = source.evidenceRepository.addCapturedFromCaptureMode(
        WorkspaceCaptureMode.photo,
      );
      final noteId = source.addContextTextNote(
        parentEvidenceId: captured.id,
        text: 'Persisted observation',
      )!;
      source.updateEvidenceNoteText(
        evidenceId: noteId,
        text: 'Persisted observation — edited',
      );
      final hydrated = _hydrateLikeRestart(source);
      final restoredNote =
          hydrated.evidenceRepository.supportingById(noteId)!;
      expect(restoredNote.notePreview, 'Persisted observation — edited');
      expect(restoredNote.updatedAt, isNotNull);
      expect(hydrated.currentIncident.id, source.currentIncident.id);
      expect(hydrated.evidenceRepository.capturedById(captured.id)!.id, captured.id);
    });
  });

  group('related person persistence', () {
    test('person + relationship persist on the evidence item', () {
      final controller = WorkspaceEvidenceController();
      final first = controller.evidenceRepository.addCapturedFromCaptureMode(
        WorkspaceCaptureMode.photo,
      );
      final second = controller.evidenceRepository.addCapturedFromCaptureMode(
        WorkspaceCaptureMode.photo,
      );
      final incidentId = controller.currentIncident.id;

      controller.assignRelatedPersonToEvidence(
        evidenceId: first.id,
        displayName: 'John Doe',
        relationship: EvidencePersonRelationship.witness,
      );
      controller.assignRelatedPersonToEvidence(
        evidenceId: second.id,
        displayName: 'Ada Cole',
        relationship: EvidencePersonRelationship.colleague,
      );

      final firstItem =
          controller.state.items.singleWhere((item) => item.id == first.id);
      final secondItem =
          controller.state.items.singleWhere((item) => item.id == second.id);
      expect(firstItem.relatedPersonName, 'John Doe');
      expect(firstItem.relatedPersonRole, 'witness');
      expect(secondItem.relatedPersonName, 'Ada Cole');
      expect(secondItem.relatedPersonRole, 'colleague');
      expect(firstItem.participantId, isNot(secondItem.participantId));
      expect(controller.currentIncident.id, incidentId);
      expect(firstItem.id, first.id);
    });

    test('same person can hold independent relationships per evidence', () {
      final controller = WorkspaceEvidenceController();
      final first = controller.evidenceRepository.addCapturedFromCaptureMode(
        WorkspaceCaptureMode.photo,
      );
      final second = controller.evidenceRepository.addCapturedFromCaptureMode(
        WorkspaceCaptureMode.photo,
      );
      controller.assignRelatedPersonToEvidence(
        evidenceId: first.id,
        displayName: 'John Doe',
        relationship: EvidencePersonRelationship.witness,
      );
      controller.assignRelatedPersonToEvidence(
        evidenceId: second.id,
        displayName: 'John Doe',
        relationship: EvidencePersonRelationship.colleague,
      );
      final firstItem =
          controller.state.items.singleWhere((item) => item.id == first.id);
      final secondItem =
          controller.state.items.singleWhere((item) => item.id == second.id);
      expect(firstItem.participantId, secondItem.participantId);
      expect(firstItem.relatedPersonRole, 'witness');
      expect(secondItem.relatedPersonRole, 'colleague');
    });

    test('person + relationship survive serializer restart', () {
      final source = WorkspaceEvidenceController();
      final captured = source.evidenceRepository.addCapturedFromCaptureMode(
        WorkspaceCaptureMode.photo,
      );
      source.assignRelatedPersonToEvidence(
        evidenceId: captured.id,
        displayName: 'John Doe',
        relationship: EvidencePersonRelationship.witness,
      );
      final hydrated = _hydrateLikeRestart(source);
      final restored =
          hydrated.state.items.singleWhere((item) => item.id == captured.id);
      expect(restored.relatedPersonName, 'John Doe');
      expect(restored.relatedPersonRole, 'witness');
      expect(restored.participantId, isNotNull);
      expect(
        RelatedPersonMetadata.nameOf(
          hydrated.evidenceRepository.capturedById(captured.id)!.metadata,
        ),
        'John Doe',
      );
    });
  });

  group('Inspector widgets', () {
    testWidgets('timestamp displays local time with seconds', (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(412, 915));

      final controller = WorkspaceEvidenceController();
      controller.preserveEvidence(WorkspaceCaptureMode.photo);
      final evidence = controller.journeyEvidenceItems.first;
      final expected = WorkspaceEvidenceFormatters.inspectorTimestamp(
        evidence.lastPreservedAt,
      );

      await _openInspector(tester, controller: controller, evidence: evidence);
      await tester.ensureVisible(find.byKey(const Key('evidence_inspector_timestamp')));
      expect(find.byKey(const Key('evidence_inspector_timestamp')), findsOneWidget);
      expect(find.text(expected), findsOneWidget);
      expect(expected, contains(RegExp(r'\d{2}:\d{2}:\d{2}')));
    });

    testWidgets('description stamp Added then Updated, isolated per evidence',
        (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(412, 915));

      final controller = WorkspaceEvidenceController();
      controller.preserveEvidence(WorkspaceCaptureMode.photo);
      controller.preserveEvidence(WorkspaceCaptureMode.photo);
      final ordered = evidenceInspectorOrder(controller.journeyEvidenceItems);
      final first = ordered.first;
      final noteId = controller.addContextTextNote(
        parentEvidenceId: first.id,
        text: 'Jsydidks',
      )!;

      await _openInspector(
        tester,
        controller: controller,
        evidence: first,
        ordered: ordered,
      );

      expect(find.text('Jsydidks'), findsWidgets);
      expect(
        find.byKey(const Key('evidence_inspector_description_stamp')),
        findsOneWidget,
      );
      expect(find.textContaining('Added today at'), findsOneWidget);

      controller.updateEvidenceNoteText(
        evidenceId: noteId,
        text: 'Jsydidks — person entered from the north side.',
      );
      expect(
        controller.evidenceRepository.supportingById(noteId)!.updatedAt,
        isNotNull,
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const Key('evidence_inspector_description_stamp')),
          matching: find.textContaining('Updated today at'),
        ),
        findsOneWidget,
      );

      tester
          .widget<EvidenceSpatialCarousel>(find.byType(EvidenceSpatialCarousel))
          .onSelected(1);
      await tester.pumpAndSettle();

      expect(find.text('Jsydidks — person entered from the north side.'), findsNothing);
      expect(find.text('Jsydidks'), findsNothing);
      expect(find.text('2 / 2'), findsOneWidget);
      expect(
        find.byKey(const Key('evidence_inspector_description_stamp')),
        findsNothing,
      );
    });

    testWidgets('related person displays immediately and does not bleed',
        (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(412, 915));

      final controller = WorkspaceEvidenceController();
      controller.preserveEvidence(WorkspaceCaptureMode.photo);
      controller.preserveEvidence(WorkspaceCaptureMode.photo);
      controller.preserveEvidence(WorkspaceCaptureMode.photo);
      final ordered = evidenceInspectorOrder(controller.journeyEvidenceItems);
      final incidentId = controller.currentIncident.id;
      final firstId = ordered[0].id;
      final secondId = ordered[1].id;

      controller.assignRelatedPersonToEvidence(
        evidenceId: firstId,
        displayName: 'John Doe',
        relationship: EvidencePersonRelationship.witness,
      );

      await _openInspector(
        tester,
        controller: controller,
        evidence: ordered[0],
        ordered: ordered,
      );

      expect(find.text('John Doe'), findsWidgets);
      expect(find.text('Witness'), findsOneWidget);
      expect(controller.currentIncident.id, incidentId);
      expect(
        controller.state.items.singleWhere((item) => item.id == firstId).id,
        firstId,
      );

      tester
          .widget<EvidenceSpatialCarousel>(find.byType(EvidenceSpatialCarousel))
          .onSelected(1);
      await tester.pumpAndSettle();

      expect(find.text('John Doe'), findsNothing);
      expect(find.text('Witness'), findsNothing);
      expect(find.text('Add Person'), findsOneWidget);
      expect(
        controller.state.items.singleWhere((item) => item.id == secondId)
            .relatedPersonName,
        isNull,
      );
    });

    testWidgets('preview frame wraps the complete container', (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(412, 915));

      final controller = WorkspaceEvidenceController();
      controller.preserveEvidence(WorkspaceCaptureMode.photo);
      await _openInspector(
        tester,
        controller: controller,
        evidence: controller.journeyEvidenceItems.first,
      );

      final frame = tester.widget<DecoratedBox>(
        find.byKey(const Key('evidence_inspector_preview_frame')),
      );
      final decoration = frame.decoration as BoxDecoration;
      expect(decoration.border, isNotNull);
      expect(find.byType(EvidenceInspectorPreview), findsOneWidget);
      expect(find.text('Photo evidence'), findsOneWidget);
      expect(tester.takeException(), isNull);

      final previewSize = tester.getSize(find.byType(EvidenceInspectorPreview));
      expect(previewSize.height, greaterThanOrEqualTo(180));
      for (final image in tester.widgetList<Image>(find.byType(Image))) {
        expect(image.fit, BoxFit.contain);
      }
    });

    testWidgets('description/metadata spacing stays compact and Close is 48px',
        (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(412, 915));

      final controller = WorkspaceEvidenceController();
      controller.preserveEvidence(WorkspaceCaptureMode.photo);
      await _openInspector(
        tester,
        controller: controller,
        evidence: controller.journeyEvidenceItems.first,
      );

      final descriptionLabel =
          tester.getBottomLeft(find.text('Your observation').first);
      final affordanceTop = tester.getTopLeft(
        find.byKey(const Key('evidence_inspector_add_observation')),
      );
      expect(affordanceTop.dy - descriptionLabel.dy, lessThan(28));

      await tester.ensureVisible(find.text('Related People'));
      final relatedLabel = tester.getBottomLeft(find.text('Related People'));
      final addPerson = tester.getTopLeft(find.text('Add Person'));
      expect(addPerson.dy - relatedLabel.dy, lessThan(36));

      final close = tester.getSize(find.byKey(const Key('evidence_inspector_close')));
      expect(close.height, greaterThanOrEqualTo(48));
      expect(find.byKey(const Key('evidence_inspector_close')), findsOneWidget);
    });
  });
}
