import 'package:evidence_vault/controllers/workspace_evidence_controller.dart';
import 'package:evidence_vault/domain/incident/current_incident.dart';
import 'package:evidence_vault/domain/incident/incident_aggregate.dart';
import 'package:evidence_vault/domain/incident/incident_status.dart';
import 'package:evidence_vault/domain/organize/organize_context_anchor.dart';
import 'package:evidence_vault/models/journey_stage.dart';
import 'package:evidence_vault/models/verification_factory.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/models/workspace_evidence_item.dart';
import 'package:evidence_vault/utils/workspace_evidence_formatters.dart';
import 'package:evidence_vault/widgets/evidence_inspector/evidence_spatial_carousel.dart';
import 'package:evidence_vault/widgets/common/thumbnail_atmosphere_surface.dart';
import 'package:evidence_vault/widgets/workspace/organize_chronology_canvas.dart';
import 'package:evidence_vault/widgets/workspace/organize_suggestion_rail.dart';
import 'package:evidence_vault/widgets/workspace/organize_workspace_view.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

WorkspaceEvidenceItem _item({
  required String id,
  required WorkspaceEvidenceKind kind,
  required DateTime at,
  String? notePreview,
  String? fileName,
}) {
  return WorkspaceEvidenceItem(
    id: id,
    kind: kind,
    title: kind.label,
    lastPreservedAt: at,
    capturedAt: kind.isPrimaryChronology ? at : null,
    recordedAt: kind.isPrimaryChronology ? null : at,
    integrityVerified: true,
    verification: VerificationFactory.initial(),
    incidentId: 'inc-chrono',
    notePreview: notePreview,
    fileName: fileName,
  );
}

void main() {
  test('minute bands follow evidenceInspectorOrder and lastPreservedAt', () {
    final t0 = DateTime(2026, 8, 22, 10, 42, 10);
    final items = [
      _item(
        id: 'note',
        kind: WorkspaceEvidenceKind.note,
        at: t0.add(const Duration(seconds: 20)),
      ),
      _item(id: 'photo', kind: WorkspaceEvidenceKind.image, at: t0),
      _item(
        id: 'voice',
        kind: WorkspaceEvidenceKind.voice,
        at: DateTime(2026, 8, 22, 10, 48),
      ),
      _item(
        id: 'file',
        kind: WorkspaceEvidenceKind.attachment,
        at: DateTime(2026, 8, 22, 10, 50),
      ),
      _item(
        id: 'video',
        kind: WorkspaceEvidenceKind.video,
        at: DateTime(2026, 8, 22, 10, 43),
      ),
    ];
    final ordered = evidenceInspectorOrder(items, incidentId: 'inc-chrono');
    expect(
      ordered.map((e) => e.id).toList(),
      ['photo', 'note', 'video', 'voice', 'file'],
    );

    final bands = OrganizeChronologyCanvas.minuteBands(ordered);
    expect(bands, hasLength(4));
    expect(bands[0].map((e) => e.id), ['photo', 'note']);
    expect(bands[1].map((e) => e.id), ['video']);
    expect(bands[2].map((e) => e.id), ['voice']);
    expect(bands[3].map((e) => e.id), ['file']);
    expect(OrganizeChronologyCanvas.isVisualCapture(ordered[0]), isTrue);
    expect(OrganizeChronologyCanvas.isVisualCapture(ordered[1]), isFalse);
  });

  testWidgets('canvas presents all supported kinds from the ordered list',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(390, 844));

    final t0 = DateTime(2026, 8, 22, 10, 42);
    final ordered = evidenceInspectorOrder(
      [
        _item(id: 'photo', kind: WorkspaceEvidenceKind.image, at: t0),
        _item(
          id: 'note',
          kind: WorkspaceEvidenceKind.note,
          at: t0.add(const Duration(seconds: 15)),
          notePreview: 'Saw the vehicle leave.',
        ),
        _item(
          id: 'video',
          kind: WorkspaceEvidenceKind.video,
          at: DateTime(2026, 8, 22, 10, 43),
        ),
        _item(
          id: 'voice',
          kind: WorkspaceEvidenceKind.voice,
          at: DateTime(2026, 8, 22, 10, 48),
        ),
        _item(
          id: 'file',
          kind: WorkspaceEvidenceKind.attachment,
          at: DateTime(2026, 8, 22, 10, 50),
          fileName: 'receipt.pdf',
        ),
      ],
      incidentId: 'inc-chrono',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.only(right: OrganizeSuggestionRail.width),
            child: OrganizeChronologyCanvas(
              ordered: ordered,
              allEvidence: ordered,
              onEvidenceSelected: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(OrganizeChronologyCanvas), findsOneWidget);
    for (final item in ordered) {
      expect(find.byKey(OrganizeWorkspaceView.rowKey(item.id)), findsOneWidget);
      expect(
        find.byKey(Key('organize_evidence_clock_${item.id}')),
        findsOneWidget,
      );
      expect(
        find.text(
          WorkspaceEvidenceFormatters.evidenceClock(item.lastPreservedAt),
        ),
        findsWidgets,
      );
    }
    expect(find.text('Photo'), findsWidgets);
    expect(find.text('Video'), findsWidgets);
    expect(find.text('Note'), findsWidgets);
    expect(find.text('Voice Note'), findsWidgets);
    expect(find.text('Attachment'), findsWidgets);
    expect(find.text('Saw the vehicle leave.'), findsWidgets);
    expect(tester.takeException(), isNull);
    for (final item in ordered) {
      expect(
        find.byKey(OrganizeChronologyCanvas.fixedTileKey(item.id)),
        findsOneWidget,
      );
      expect(
        find.byKey(OrganizeChronologyCanvas.contextTileKey(item.id)),
        findsNothing,
      );
    }
  });

  testWidgets('canvas does not change collection or relationship membership',
      (tester) async {
    final controller = WorkspaceEvidenceController(
      aggregate: IncidentAggregate.shell(id: 'inc-chrono', title: 'Case'),
    );
    controller.preserveEvidence(WorkspaceCaptureMode.photo);
    controller.preserveEvidence(WorkspaceCaptureMode.note);
    controller.ensureEvidenceCollections();
    final collectionsBefore = controller.evidenceCollections
        .map((c) => '${c.id}:${c.memberEvidenceIds.join(',')}')
        .toList();
    final groupsBefore = controller.currentIncident.relationshipGroups.length;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OrganizeWorkspaceView(
            incident: controller.currentIncident,
            dismissedCollectionIds: controller.dismissedCollectionIds,
            onEvidenceSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      controller.evidenceCollections
          .map((c) => '${c.id}:${c.memberEvidenceIds.join(',')}')
          .toList(),
      collectionsBefore,
    );
    expect(
      controller.currentIncident.relationshipGroups,
      hasLength(groupsBefore),
    );
  });

  test('spine membership follows Organize origin, not evidence kind', () {
    final photo = _item(
      id: 'photo',
      kind: WorkspaceEvidenceKind.image,
      at: DateTime(2026, 8, 22, 10),
    );
    final voice = _item(
      id: 'voice',
      kind: WorkspaceEvidenceKind.voice,
      at: DateTime(2026, 8, 22, 11),
    );
    final note = _item(
      id: 'note',
      kind: WorkspaceEvidenceKind.note,
      at: DateTime(2026, 8, 22, 12),
    );
    final file = _item(
      id: 'file',
      kind: WorkspaceEvidenceKind.attachment,
      at: DateTime(2026, 8, 22, 13),
    );
    const captured = <String>{};
    const organize = {'org-voice', 'org-note', 'org-file'};

    expect(
      OrganizeChronologyCanvas.isFixedSpineItem(photo, organizeCreatedIds: captured),
      isTrue,
    );
    expect(
      OrganizeChronologyCanvas.isFixedSpineItem(voice, organizeCreatedIds: captured),
      isTrue,
    );
    expect(
      OrganizeChronologyCanvas.isFixedSpineItem(note, organizeCreatedIds: captured),
      isTrue,
    );
    expect(
      OrganizeChronologyCanvas.isFixedSpineItem(file, organizeCreatedIds: captured),
      isTrue,
    );

    final orgVoice = _item(
      id: 'org-voice',
      kind: WorkspaceEvidenceKind.voice,
      at: DateTime(2026, 8, 22, 14),
    );
    final orgNote = _item(
      id: 'org-note',
      kind: WorkspaceEvidenceKind.note,
      at: DateTime(2026, 8, 22, 15),
    );
    final orgFile = _item(
      id: 'org-file',
      kind: WorkspaceEvidenceKind.attachment,
      at: DateTime(2026, 8, 22, 16),
    );
    expect(
      OrganizeChronologyCanvas.isContextSpineItem(
        orgVoice,
        organizeCreatedIds: organize,
      ),
      isTrue,
    );
    expect(
      OrganizeChronologyCanvas.isContextSpineItem(
        orgNote,
        organizeCreatedIds: organize,
      ),
      isTrue,
    );
    expect(
      OrganizeChronologyCanvas.isContextSpineItem(
        orgFile,
        organizeCreatedIds: organize,
      ),
      isTrue,
    );
    expect(
      OrganizeChronologyCanvas.isContextSpineItem(note, organizeCreatedIds: organize),
      isFalse,
    );
  });

  test('Capture-origin items never become floating contexts', () {
    final photo = _item(
      id: 'photo',
      kind: WorkspaceEvidenceKind.image,
      at: DateTime(2026, 8, 22, 10),
    );
    final video = _item(
      id: 'video',
      kind: WorkspaceEvidenceKind.video,
      at: DateTime(2026, 8, 22, 11),
    );
    final captureFile = _item(
      id: 'file',
      kind: WorkspaceEvidenceKind.attachment,
      at: DateTime(2026, 8, 22, 12),
    );
    final captureNote = _item(
      id: 'note',
      kind: WorkspaceEvidenceKind.note,
      at: DateTime(2026, 8, 22, 13),
    );
    const origin = {'org-voice', 'org-note', 'org-file'};
    for (final item in [photo, video, captureFile, captureNote]) {
      expect(
        OrganizeChronologyCanvas.isFixedSpineItem(
          item,
          organizeCreatedIds: origin,
        ),
        isTrue,
        reason: '${item.id} entered through Capture',
      );
      expect(
        OrganizeChronologyCanvas.isContextSpineItem(
          item,
          organizeCreatedIds: origin,
        ),
        isFalse,
      );
    }
  });

  testWidgets('lanes split captured chronology from unplaced context',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(390, 844));

    final t0 = DateTime(2026, 8, 22, 10, 42);
    final ordered = [
      _item(id: 'photo', kind: WorkspaceEvidenceKind.image, at: t0),
      _item(
        id: 'note',
        kind: WorkspaceEvidenceKind.note,
        at: t0.add(const Duration(seconds: 15)),
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OrganizeChronologyCanvas(
            ordered: ordered,
            allEvidence: ordered,
            organizeCreatedIds: const {'note'},
            onEvidenceSelected: (_) {},
            onSetContextAnchor: (_, _) {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(OrganizeChronologyCanvas.fixedSpineKey), findsOneWidget);
    expect(find.byKey(OrganizeChronologyCanvas.contextSpineKey), findsOneWidget);
    expect(
      find.byKey(OrganizeChronologyCanvas.fixedTileKey('photo')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(OrganizeChronologyCanvas.fixedTileKey('photo')),
        matching: find.byType(ThumbnailAtmosphereSurface),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(OrganizeChronologyCanvas.contextTileKey('note')),
      findsOneWidget,
    );
    expect(
      find.ancestor(
        of: find.byKey(OrganizeChronologyCanvas.fixedTileKey('photo')),
        matching: find.byType(LongPressDraggable<String>),
      ),
      findsNothing,
    );
    expect(
      find.ancestor(
        of: find.byKey(OrganizeChronologyCanvas.contextTileKey('note')),
        matching: find.byType(LongPressDraggable<String>),
      ),
      findsOneWidget,
    );
  });

  testWidgets('dragging a note onto a photo stores an Organize context anchor',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(390, 844));

    final t0 = DateTime(2026, 8, 22, 10, 42);
    final ordered = [
      _item(id: 'photo', kind: WorkspaceEvidenceKind.image, at: t0),
      _item(
        id: 'note',
        kind: WorkspaceEvidenceKind.note,
        at: t0.add(const Duration(seconds: 15)),
        notePreview: 'Saw the vehicle leave.',
      ),
    ];
    final anchors = <OrganizeContextAnchor>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return OrganizeChronologyCanvas(
                ordered: ordered,
                allEvidence: ordered,
                anchors: List<OrganizeContextAnchor>.from(anchors),
                organizeCreatedIds: const {'note'},
                onEvidenceSelected: (_) {},
                onSetContextAnchor: (contextId, capturedId) {
                  setState(() {
                    anchors
                      ..clear()
                      ..add(
                        OrganizeContextAnchor(
                          contextEvidenceId: contextId,
                          capturedEvidenceId: capturedId,
                        ),
                      );
                  });
                },
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();

    final noteFinder =
        find.byKey(OrganizeChronologyCanvas.contextTileKey('note'));
    final photoFinder =
        find.byKey(OrganizeChronologyCanvas.fixedTileKey('photo'));
    expect(noteFinder, findsOneWidget);
    expect(photoFinder, findsOneWidget);

    final gesture = await tester.startGesture(tester.getCenter(noteFinder));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    await gesture.moveTo(tester.getCenter(photoFinder));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(anchors, hasLength(1));
    expect(anchors.single.contextEvidenceId, 'note');
    expect(anchors.single.capturedEvidenceId, 'photo');
    expect(find.byKey(OrganizeChronologyCanvas.contextTileKey('note')),
        findsOneWidget);
  });

  testWidgets(
      'controller snap stores an anchor without Evidence Chain fields',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(390, 844));

    final controller = WorkspaceEvidenceController(
      aggregate: IncidentAggregate.shell(id: 'inc-snap', title: 'Case'),
    );
    final photo = controller.preserveEvidenceAndReturnId(
      WorkspaceCaptureMode.photo,
    );
    final note = controller.addOrganizeContextEvidence(
      WorkspaceCaptureMode.note,
    );
    controller.ensureEvidenceCollections();
    final parentBefore = controller.currentIncident.evidence
        .firstWhere((e) => e.id == note)
        .parentEvidenceId;
    final collectionsBefore = controller.evidenceCollections
        .map((c) => '${c.id}:${c.memberEvidenceIds.join(',')}')
        .toList();
    final relationshipsBefore = controller.state.relationships.length;
    final photoTime = controller.currentIncident.evidence
        .firstWhere((e) => e.id == photo)
        .lastPreservedAt;
    final noteTime = controller.currentIncident.evidence
        .firstWhere((e) => e.id == note)
        .lastPreservedAt;
    final ordered = evidenceInspectorOrder(
      controller.currentIncident.journeyEvidence,
      incidentId: controller.currentIncident.id,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListenableBuilder(
            listenable: controller,
            builder: (context, _) {
              return OrganizeChronologyCanvas(
                ordered: ordered,
                allEvidence: controller.currentIncident.evidence,
                anchors: controller.organizeContextAnchors,
                organizeCreatedIds: controller.organizeCreatedEvidenceIds,
                onEvidenceSelected: (_) {},
                onSetContextAnchor: (contextId, capturedId) {
                  controller.setOrganizeContextAnchor(
                    contextEvidenceId: contextId,
                    capturedEvidenceId: capturedId,
                  );
                },
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();

    final noteFinder =
        find.byKey(OrganizeChronologyCanvas.contextTileKey(note));
    final photoFinder =
        find.byKey(OrganizeChronologyCanvas.fixedTileKey(photo));

    final gesture = await tester.startGesture(tester.getCenter(noteFinder));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    await gesture.moveTo(tester.getCenter(photoFinder));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(controller.organizeContextAnchors, hasLength(1));
    expect(controller.organizeContextAnchors.single.contextEvidenceId, note);
    expect(controller.organizeContextAnchors.single.capturedEvidenceId, photo);

    final noteAfter =
        controller.currentIncident.evidence.firstWhere((e) => e.id == note);
    expect(noteAfter.parentEvidenceId, parentBefore);
    expect(noteAfter.lastPreservedAt, noteTime);
    expect(
      controller.currentIncident.evidence
          .firstWhere((e) => e.id == photo)
          .lastPreservedAt,
      photoTime,
    );
    expect(
      controller.evidenceCollections
          .map((c) => '${c.id}:${c.memberEvidenceIds.join(',')}')
          .toList(),
      collectionsBefore,
    );
    expect(controller.state.relationships, hasLength(relationshipsBefore));
  });

  testWidgets('anchored context keeps a lasting dotted arrow to the target',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(390, 844));

    final t0 = DateTime(2026, 8, 22, 10, 42);
    final ordered = [
      _item(id: 'photo', kind: WorkspaceEvidenceKind.image, at: t0),
      _item(
        id: 'note',
        kind: WorkspaceEvidenceKind.note,
        at: t0.add(const Duration(seconds: 15)),
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OrganizeChronologyCanvas(
            ordered: ordered,
            allEvidence: ordered,
            organizeCreatedIds: const {'note'},
            onEvidenceSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();
    expect(
      find.byKey(OrganizeChronologyCanvas.contextArrowKey('note')),
      findsNothing,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OrganizeChronologyCanvas(
            ordered: ordered,
            allEvidence: ordered,
            organizeCreatedIds: const {'note'},
            anchors: const [
              OrganizeContextAnchor(
                contextEvidenceId: 'note',
                capturedEvidenceId: 'photo',
              ),
            ],
            onEvidenceSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(OrganizeChronologyCanvas.contextArrowKey('note')),
      findsOneWidget,
    );
    expect(find.byKey(OrganizeChronologyCanvas.fixedTileKey('photo')),
        findsOneWidget);
    expect(find.byKey(OrganizeChronologyCanvas.contextTileKey('note')),
        findsOneWidget);
    expect(find.text('Photo'), findsWidgets);
    expect(find.byKey(OrganizeChronologyCanvas.contextTileKey('note')),
        findsOneWidget);
    expect(find.text(OrganizeChronologyCanvas.addedContextLabel), findsNothing);
  });

  testWidgets('successful snap reveals the context arrow without rewriting chronology',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(390, 844));

    final t0 = DateTime(2026, 8, 22, 10, 42);
    final photoTime = t0;
    final noteTime = t0.add(const Duration(seconds: 15));
    final ordered = [
      _item(id: 'photo', kind: WorkspaceEvidenceKind.image, at: photoTime),
      _item(
        id: 'note',
        kind: WorkspaceEvidenceKind.note,
        at: noteTime,
      ),
    ];
    final anchors = <OrganizeContextAnchor>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return OrganizeChronologyCanvas(
                ordered: ordered,
                allEvidence: ordered,
                anchors: List<OrganizeContextAnchor>.from(anchors),
                organizeCreatedIds: const {'note'},
                onEvidenceSelected: (_) {},
                onSetContextAnchor: (contextId, capturedId) {
                  setState(() {
                    anchors
                      ..clear()
                      ..add(
                        OrganizeContextAnchor(
                          contextEvidenceId: contextId,
                          capturedEvidenceId: capturedId,
                        ),
                      );
                  });
                },
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(OrganizeChronologyCanvas.contextTileKey('note'))),
    );
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    await gesture.moveTo(
      tester.getCenter(find.byKey(OrganizeChronologyCanvas.fixedTileKey('photo'))),
    );
    await tester.pump();
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(anchors, hasLength(1));
    expect(anchors.single.contextEvidenceId, 'note');
    expect(anchors.single.capturedEvidenceId, 'photo');
    expect(
      find.byKey(OrganizeChronologyCanvas.contextArrowKey('note')),
      findsOneWidget,
    );
    expect(
      find.byKey(Key('organize_evidence_clock_photo')),
      findsOneWidget,
    );
    expect(
      find.byKey(Key('organize_evidence_clock_note')),
      findsOneWidget,
    );
    expect(ordered[0].lastPreservedAt, photoTime);
    expect(ordered[1].lastPreservedAt, noteTime);
  });

  testWidgets('invalid unanchored drop stores nothing and draws no arrow',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(390, 844));

    final t0 = DateTime(2026, 8, 22, 10, 42);
    final photoTime = t0;
    final noteTime = t0.add(const Duration(seconds: 15));
    final ordered = [
      _item(id: 'photo', kind: WorkspaceEvidenceKind.image, at: photoTime),
      _item(id: 'note', kind: WorkspaceEvidenceKind.note, at: noteTime),
    ];
    final anchors = <OrganizeContextAnchor>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return OrganizeChronologyCanvas(
                ordered: ordered,
                allEvidence: ordered,
                anchors: List<OrganizeContextAnchor>.from(anchors),
                organizeCreatedIds: const {'note'},
                onEvidenceSelected: (_) {},
                onSetContextAnchor: (contextId, capturedId) {
                  setState(() {
                    anchors.add(
                      OrganizeContextAnchor(
                        contextEvidenceId: contextId,
                        capturedEvidenceId: capturedId,
                      ),
                    );
                  });
                },
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();

    final gesture = await tester.startGesture(
      tester.getCenter(
        find.byKey(OrganizeChronologyCanvas.contextTileKey('note')),
      ),
    );
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    await gesture.moveTo(const Offset(20, 820));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(anchors, isEmpty);
    expect(
      find.byKey(OrganizeChronologyCanvas.contextArrowKey('note')),
      findsNothing,
    );
    expect(ordered[0].lastPreservedAt, photoTime);
    expect(ordered[1].lastPreservedAt, noteTime);
  });

  testWidgets('drag-away from an anchored note unlinks the context',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(390, 844));

    final t0 = DateTime(2026, 8, 22, 10, 42);
    final ordered = [
      _item(id: 'photo', kind: WorkspaceEvidenceKind.image, at: t0),
      _item(
        id: 'note',
        kind: WorkspaceEvidenceKind.note,
        at: t0.add(const Duration(seconds: 20)),
      ),
    ];
    var anchors = [
      const OrganizeContextAnchor(
        contextEvidenceId: 'note',
        capturedEvidenceId: 'photo',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return OrganizeChronologyCanvas(
                ordered: ordered,
                allEvidence: ordered,
                anchors: List<OrganizeContextAnchor>.from(anchors),
                organizeCreatedIds: const {'note'},
                onEvidenceSelected: (_) {},
                onSetContextAnchor: (contextId, capturedId) {
                  setState(() {
                    anchors = [
                      OrganizeContextAnchor(
                        contextEvidenceId: contextId,
                        capturedEvidenceId: capturedId,
                      ),
                    ];
                  });
                },
                onClearContextAnchor: (id) {
                  setState(() {
                    anchors = [
                      for (final anchor in anchors)
                        if (anchor.contextEvidenceId != id) anchor,
                    ];
                  });
                },
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();
    expect(
      find.byKey(OrganizeChronologyCanvas.contextArrowKey('note')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(OrganizeChronologyCanvas.contextTileKey('note')),
    );
    await tester.pump();
    await tester.pump(kDoubleTapTimeout);
    final gesture = await tester.startGesture(
      tester.getCenter(
        find.byKey(OrganizeChronologyCanvas.contextTileKey('note')),
      ),
    );
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    await gesture.moveTo(const Offset(20, 820));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(anchors, isEmpty);
    expect(
      find.byKey(OrganizeChronologyCanvas.contextArrowKey('note')),
      findsNothing,
    );
  });

  testWidgets('repositioning a note replaces the derived arrow target',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(390, 844));

    final t0 = DateTime(2026, 8, 22, 10, 42);
    final ordered = [
      _item(id: 'photoX', kind: WorkspaceEvidenceKind.image, at: t0),
      _item(
        id: 'photoY',
        kind: WorkspaceEvidenceKind.image,
        at: t0.add(const Duration(minutes: 3)),
      ),
      _item(
        id: 'note',
        kind: WorkspaceEvidenceKind.note,
        at: t0.add(const Duration(seconds: 20)),
      ),
    ];
    var anchors = [
      const OrganizeContextAnchor(
        contextEvidenceId: 'note',
        capturedEvidenceId: 'photoX',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return OrganizeChronologyCanvas(
                ordered: ordered,
                allEvidence: ordered,
                anchors: List<OrganizeContextAnchor>.from(anchors),
                organizeCreatedIds: const {'note'},
                onEvidenceSelected: (_) {},
                onSetContextAnchor: (contextId, capturedId) {
                  setState(() {
                    anchors = [
                      OrganizeContextAnchor(
                        contextEvidenceId: contextId,
                        capturedEvidenceId: capturedId,
                      ),
                    ];
                  });
                },
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(
      find.byKey(OrganizeChronologyCanvas.contextTileKey('note')),
    );
    await tester.pump();
    await tester.pump(kDoubleTapTimeout);
    final gesture = await tester.startGesture(
      tester.getCenter(
        find.byKey(OrganizeChronologyCanvas.contextTileKey('note')),
      ),
    );
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    await gesture.moveTo(
      tester.getCenter(
        find.byKey(OrganizeChronologyCanvas.fixedTileKey('photoY')),
      ),
    );
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(anchors, hasLength(1));
    expect(anchors.single.contextEvidenceId, 'note');
    expect(anchors.single.capturedEvidenceId, 'photoY');
    expect(
      find.byKey(OrganizeChronologyCanvas.contextArrowKey('note')),
      findsOneWidget,
    );
  });

  testWidgets('multiple contexts on one captured collect into a cluster',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(390, 844));

    final t0 = DateTime(2026, 8, 22, 10, 42);
    final ordered = [
      _item(id: 'photo', kind: WorkspaceEvidenceKind.image, at: t0),
      _item(
        id: 'noteA',
        kind: WorkspaceEvidenceKind.note,
        at: t0.add(const Duration(seconds: 10)),
      ),
      _item(
        id: 'noteB',
        kind: WorkspaceEvidenceKind.note,
        at: t0.add(const Duration(seconds: 20)),
      ),
      _item(
        id: 'file',
        kind: WorkspaceEvidenceKind.attachment,
        at: t0.add(const Duration(seconds: 30)),
        fileName: 'receipt.pdf',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OrganizeChronologyCanvas(
            ordered: ordered,
            allEvidence: ordered,
            organizeCreatedIds: const {'noteA', 'noteB', 'file'},
            anchors: const [
              OrganizeContextAnchor(
                contextEvidenceId: 'noteA',
                capturedEvidenceId: 'photo',
              ),
              OrganizeContextAnchor(
                contextEvidenceId: 'noteB',
                capturedEvidenceId: 'photo',
              ),
              OrganizeContextAnchor(
                contextEvidenceId: 'file',
                capturedEvidenceId: 'photo',
              ),
            ],
            onEvidenceSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(OrganizeChronologyCanvas.clusterKey('photo')),
      findsOneWidget,
    );
    expect(
      find.byKey(OrganizeChronologyCanvas.clusterArrowKey('photo')),
      findsOneWidget,
    );
    expect(
      find.byKey(OrganizeChronologyCanvas.contextArrowKey('noteA')),
      findsNothing,
    );
    expect(
      find.byKey(OrganizeChronologyCanvas.contextTileKey('noteA')),
      findsNothing,
    );
    expect(
      find.byKey(OrganizeChronologyCanvas.contextTileKey('noteB')),
      findsNothing,
    );
    expect(
      find.byKey(OrganizeChronologyCanvas.contextTileKey('file')),
      findsNothing,
    );
  });

  testWidgets(
    'unattached context: single tap keeps wobble; double tap opens once',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(390, 844));

      final t0 = DateTime(2026, 8, 22, 10, 42);
      final ordered = [
        _item(id: 'photo', kind: WorkspaceEvidenceKind.image, at: t0),
        _item(
          id: 'note',
          kind: WorkspaceEvidenceKind.note,
          at: t0.add(const Duration(seconds: 15)),
        ),
        _item(
          id: 'voice',
          kind: WorkspaceEvidenceKind.voice,
          at: t0.add(const Duration(seconds: 30)),
        ),
      ];
      final selected = <String>[];
      final anchors = <OrganizeContextAnchor>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OrganizeChronologyCanvas(
              ordered: ordered,
              allEvidence: ordered,
              organizeCreatedIds: const {'note', 'voice'},
              onEvidenceSelected: (item) => selected.add(item.id),
              onSetContextAnchor: (contextId, capturedId) {
                anchors.add(
                  OrganizeContextAnchor(
                    contextEvidenceId: contextId,
                    capturedEvidenceId: capturedId,
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pump();

      final note = find.byKey(OrganizeWorkspaceView.rowKey('note'));
      await tester.tap(note);
      await tester.pump();
      await tester.pump(kDoubleTapTimeout);

      expect(selected, isEmpty);
      expect(anchors, isEmpty);
      expect(
        tester
            .widget<OrganizePlacementWobble>(
              find.byKey(
                OrganizeChronologyCanvas.awaitingPlacementKey('note'),
              ),
            )
            .active,
        isTrue,
      );

      await tester.tap(note);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(note);
      await tester.pump();

      expect(selected, ['note']);
      expect(anchors, isEmpty);

      await tester.tap(find.byKey(OrganizeWorkspaceView.rowKey('voice')));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byKey(OrganizeWorkspaceView.rowKey('voice')));
      await tester.pump();
      await tester.pump(kDoubleTapTimeout);

      expect(selected, ['note', 'voice']);
    },
  );

  testWidgets(
    'wobbling appended context: single tap stays; double tap opens once',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(390, 844));

      final t0 = DateTime(2026, 8, 22, 10, 42);
      final ordered = [
        _item(id: 'photo', kind: WorkspaceEvidenceKind.image, at: t0),
        _item(
          id: 'note',
          kind: WorkspaceEvidenceKind.note,
          at: t0.add(const Duration(seconds: 15)),
        ),
      ];
      final selected = <String>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OrganizeChronologyCanvas(
              ordered: ordered,
              allEvidence: ordered,
              organizeCreatedIds: const {'note'},
              anchors: const [
                OrganizeContextAnchor(
                  contextEvidenceId: 'note',
                  capturedEvidenceId: 'photo',
                ),
              ],
              onEvidenceSelected: (item) => selected.add(item.id),
              onSetContextAnchor: (_, _) {},
              onClearContextAnchor: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();

      final note = find.byKey(OrganizeWorkspaceView.rowKey('note'));
      await tester.tap(note);
      await tester.pump();
      await tester.pump(kDoubleTapTimeout);

      expect(selected, isEmpty);
      expect(
        tester
            .widget<OrganizePlacementWobble>(
              find.byKey(
                OrganizeChronologyCanvas.awaitingPlacementKey('note'),
              ),
            )
            .active,
        isTrue,
      );

      await tester.tap(note);
      await tester.pump();
      await tester.pump(kDoubleTapTimeout);
      expect(selected, isEmpty);

      await tester.tap(note);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(note);
      await tester.pump();
      await tester.pump(kDoubleTapTimeout);

      expect(selected, ['note']);
    },
  );

  testWidgets(
    'sole connected context: double tap opens without clearing the anchor',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(390, 844));

      final t0 = DateTime(2026, 8, 22, 10, 42);
      final ordered = [
        _item(id: 'photo', kind: WorkspaceEvidenceKind.image, at: t0),
        _item(
          id: 'note',
          kind: WorkspaceEvidenceKind.note,
          at: t0.add(const Duration(seconds: 15)),
        ),
      ];
      final selected = <String>[];
      final cleared = <String>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OrganizeChronologyCanvas(
              ordered: ordered,
              allEvidence: ordered,
              organizeCreatedIds: const {'note'},
              anchors: const [
                OrganizeContextAnchor(
                  contextEvidenceId: 'note',
                  capturedEvidenceId: 'photo',
                ),
              ],
              onEvidenceSelected: (item) => selected.add(item.id),
              onSetContextAnchor: (_, _) {},
              onClearContextAnchor: cleared.add,
            ),
          ),
        ),
      );
      await tester.pump();

      final note = find.byKey(OrganizeWorkspaceView.rowKey('note'));
      await tester.tap(note);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(note);
      await tester.pump();
      await tester.pump(kDoubleTapTimeout);

      expect(selected, ['note']);
      expect(cleared, isEmpty);
      expect(
        find.byKey(OrganizeChronologyCanvas.contextArrowKey('note')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<OrganizePlacementWobble>(
              find.byKey(
                OrganizeChronologyCanvas.awaitingPlacementKey('note'),
              ),
            )
            .active,
        isFalse,
      );
    },
  );

  testWidgets(
    'overlay floating context: single tap stays; double tap opens once',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(390, 844));

      final t0 = DateTime(2026, 8, 22, 10, 42);
      final ordered = [
        _item(id: 'photo', kind: WorkspaceEvidenceKind.image, at: t0),
        _item(
          id: 'note',
          kind: WorkspaceEvidenceKind.note,
          at: t0.add(const Duration(seconds: 15)),
        ),
      ];
      final selected = <String>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OrganizeWorkspaceView(
              incident: CurrentIncident(
                id: 'inc-chrono',
                title: 'Case',
                status: IncidentStatus.active,
                createdAt: t0,
                updatedAt: t0,
                manuallyComplete: false,
                journeyStage: JourneyStage.building,
                captureProgressPercent: 0,
                timelineAnchorCount: 1,
                relationshipGroupCount: 0,
                narrativeEventCount: 0,
                evidence: ordered,
                journeyEvidence: ordered,
                relationshipGroups: const [],
                evidenceCollections: const [],
                trustPackageReady: true,
                trustPackageProgressPercent: 40,
              ),
              orderedCapturedEvidenceIds: const ['photo'],
              organizeCreatedIds: const {'note'},
              onEvidenceSelected: (item) => selected.add(item.id),
              onAddOrganizeContext: (_) {},
              onSetContextAnchor: (_, _) {},
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final note = find.byKey(OrganizeWorkspaceView.rowKey('note'));
      await tester.tap(note);
      await tester.pump();
      await tester.pump(kDoubleTapTimeout);
      expect(selected, isEmpty);

      await tester.tap(note);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(note);
      await tester.pump();
      await tester.pump(kDoubleTapTimeout);
      expect(selected, ['note']);
    },
  );

  testWidgets('captured voice, note, and file stay on the fixed spine',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(390, 844));

    final controller = WorkspaceEvidenceController(
      aggregate: IncidentAggregate.shell(id: 'inc-fixed', title: 'Case'),
    );
    final voice = controller.preserveEvidenceAndReturnId(
      WorkspaceCaptureMode.voice,
    );
    final note = controller.preserveEvidenceAndReturnId(
      WorkspaceCaptureMode.note,
    );
    final file = controller.preserveEvidenceAndReturnId(
      WorkspaceCaptureMode.file,
    );
    final ordered = evidenceInspectorOrder(
      controller.currentIncident.journeyEvidence,
      incidentId: controller.currentIncident.id,
    );
    final orderBefore = ordered.map((e) => e.id).toList();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OrganizeChronologyCanvas(
            ordered: ordered,
            allEvidence: controller.currentIncident.evidence,
            organizeCreatedIds: controller.organizeCreatedEvidenceIds,
            onEvidenceSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(OrganizeChronologyCanvas.fixedTileKey(voice)),
        findsOneWidget);
    expect(find.byKey(OrganizeChronologyCanvas.fixedTileKey(note)),
        findsOneWidget);
    expect(find.byKey(OrganizeChronologyCanvas.fixedTileKey(file)),
        findsOneWidget);
    expect(find.byKey(OrganizeChronologyCanvas.contextTileKey(voice)),
        findsNothing);
    expect(find.byKey(OrganizeChronologyCanvas.contextTileKey(note)),
        findsNothing);
    expect(find.byKey(OrganizeChronologyCanvas.contextTileKey(file)),
        findsNothing);
    expect(
      evidenceInspectorOrder(
        controller.currentIncident.journeyEvidence,
        incidentId: controller.currentIncident.id,
      ).map((e) => e.id),
      orderBefore,
    );
  });

  testWidgets('Organize-created voice, note, and file sit on the flexible spine',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(390, 844));

    final controller = WorkspaceEvidenceController(
      aggregate: IncidentAggregate.shell(id: 'inc-flex', title: 'Case'),
    );
    final photo = controller.preserveEvidenceAndReturnId(
      WorkspaceCaptureMode.photo,
    );
    final capturedTimes = {
      for (final item in controller.currentIncident.evidence)
        item.id: item.lastPreservedAt,
    };
    final orderBefore = evidenceInspectorOrder(
      controller.currentIncident.journeyEvidence,
      incidentId: controller.currentIncident.id,
    ).map((e) => e.id).toList();

    final orgVoice = controller.addOrganizeContextEvidence(
      WorkspaceCaptureMode.voice,
    );
    final orgNote = controller.addOrganizeContextEvidence(
      WorkspaceCaptureMode.note,
    );
    final orgFile = controller.addOrganizeContextEvidence(
      WorkspaceCaptureMode.file,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListenableBuilder(
            listenable: controller,
            builder: (context, _) {
              return OrganizeChronologyCanvas(
                ordered: evidenceInspectorOrder(
                  controller.currentIncident.journeyEvidence,
                  incidentId: controller.currentIncident.id,
                ),
                allEvidence: controller.currentIncident.evidence,
                anchors: controller.organizeContextAnchors,
                organizeCreatedIds: controller.organizeCreatedEvidenceIds,
                onEvidenceSelected: (_) {},
                onSetContextAnchor: (contextId, capturedId) {
                  controller.setOrganizeContextAnchor(
                    contextEvidenceId: contextId,
                    capturedEvidenceId: capturedId,
                  );
                },
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(OrganizeChronologyCanvas.fixedTileKey(photo)),
        findsOneWidget);
    expect(find.byKey(OrganizeChronologyCanvas.contextTileKey(orgVoice)),
        findsOneWidget);
    expect(find.byKey(OrganizeChronologyCanvas.contextTileKey(orgNote)),
        findsOneWidget);
    expect(find.byKey(OrganizeChronologyCanvas.contextTileKey(orgFile)),
        findsOneWidget);
    expect(find.byKey(OrganizeChronologyCanvas.fixedTileKey(orgVoice)),
        findsNothing);
    expect(find.byKey(OrganizeChronologyCanvas.fixedTileKey(orgNote)),
        findsNothing);
    expect(find.byKey(OrganizeChronologyCanvas.fixedTileKey(orgFile)),
        findsNothing);

    for (final entry in capturedTimes.entries) {
      expect(
        controller.currentIncident.evidence
            .firstWhere((e) => e.id == entry.key)
            .lastPreservedAt,
        entry.value,
      );
    }
    expect(orderBefore, [photo]);
    expect(
      evidenceInspectorOrder(
        [
          for (final item in controller.currentIncident.journeyEvidence)
            if (!controller.organizeCreatedEvidenceIds.contains(item.id)) item,
        ],
        incidentId: controller.currentIncident.id,
      ).map((e) => e.id),
      orderBefore,
    );

    final gesture = await tester.startGesture(
      tester.getCenter(
        find.byKey(OrganizeChronologyCanvas.contextTileKey(orgNote)),
      ),
    );
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    expect(find.byKey(OrganizeChronologyCanvas.dragAuraKey), findsOneWidget);
    await gesture.moveTo(
      tester.getCenter(find.byKey(OrganizeChronologyCanvas.fixedTileKey(photo))),
    );
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(controller.organizeContextAnchors, hasLength(1));
    expect(controller.organizeContextAnchors.single.contextEvidenceId, orgNote);
    expect(controller.organizeContextAnchors.single.capturedEvidenceId, photo);
    expect(
      find.byKey(OrganizeChronologyCanvas.contextArrowKey(orgNote)),
      findsOneWidget,
    );
  });
}
