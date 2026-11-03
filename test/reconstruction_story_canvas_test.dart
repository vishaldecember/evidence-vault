import 'package:evidence_vault/domain/collection/evidence_collection.dart';
import 'package:evidence_vault/domain/organize/organize_context_anchor.dart';
import 'package:evidence_vault/models/verification_factory.dart';
import 'package:evidence_vault/models/workspace_evidence_item.dart';
import 'package:evidence_vault/services/investigation/reconstruction_canvas_layout.dart';
import 'package:evidence_vault/services/investigation/reconstruction_location_label_store.dart';
import 'package:evidence_vault/widgets/investigation/investigation_evidence_mark.dart';
import 'package:evidence_vault/widgets/investigation/reconstruction_story_canvas.dart';
import 'package:evidence_vault/utils/evidence_formatters.dart';
import 'package:evidence_vault/widgets/investigation/gps_coordinate_title_box.dart';
import 'package:evidence_vault/widgets/investigation/reconstruction_workspace.dart';
import 'package:evidence_vault/widgets/reconstruction/narrative/narrative_event_card.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

WorkspaceEvidenceItem _item({
  required String id,
  WorkspaceEvidenceKind kind = WorkspaceEvidenceKind.image,
  DateTime? capturedAt,
  double? latitude,
  double? longitude,
}) {
  return WorkspaceEvidenceItem(
    id: id,
    kind: kind,
    title: 'Evidence $id',
    lastPreservedAt: capturedAt ?? DateTime.utc(2026, 8, 28, 4, 42),
    capturedAt: capturedAt,
    integrityVerified: true,
    verification: VerificationFactory.initial(),
    incidentId: 'inc-A',
    latitude: latitude,
    longitude: longitude,
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ReconstructionLocationLabelStore.instance.resetForTests();
  });

  Future<void> pumpCanvas(
    WidgetTester tester, {
    required List<WorkspaceEvidenceItem> evidence,
    List<OrganizeContextAnchor> anchors = const [],
    List<EvidenceCollection> collections = const [],
    Set<String> organizeCreatedIds = const {},
    ValueChanged<WorkspaceEvidenceItem>? onTap,
  }) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(412, 915));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReconstructionWorkspace(
            incidentId: 'inc-A',
            evidence: evidence,
            collections: collections,
            organizeCreatedIds: organizeCreatedIds,
            contextAnchors: anchors,
            onEvidenceTap: onTap ?? (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> expectLocationNotEditable(WidgetTester tester) async {
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Save'), findsNothing);
    expect(find.text('Cancel'), findsNothing);
    expect(find.text('Where did this happen?'), findsNothing);
    expect(find.text('Add location'), findsNothing);
  }

  testWidgets('unknown location is a read-only system fact', (tester) async {
    await pumpCanvas(
      tester,
      evidence: [
        _item(id: 'photo', capturedAt: DateTime.utc(2026, 8, 28, 4, 42)),
      ],
    );

    expect(
      find.text(ReconstructionCanvasLayout.locationUnavailableLabel),
      findsOneWidget,
    );
    final pin = tester.widget<Icon>(find.byIcon(Icons.place_rounded));
    expect(pin.color, ReconstructionStoryCanvas.locationRed);

    await tester.tap(
      find.text(ReconstructionCanvasLayout.locationUnavailableLabel),
    );
    await tester.pumpAndSettle();
    await expectLocationNotEditable(tester);
    expect(
      find.byKey(ReconstructionStoryCanvas.gpsCoordinateTitleKey),
      findsNothing,
    );
    expect(find.byType(GpsCoordinateTitleBox), findsNothing);
  });

  testWidgets('recognized location name is displayed and not editable', (
    tester,
  ) async {
    await pumpCanvas(
      tester,
      evidence: [
        _item(
          id: 'photo',
          capturedAt: DateTime.utc(2026, 8, 28, 4, 42),
          latitude: 27.7172,
          longitude: 85.3240,
        ),
      ],
      collections: [
        EvidenceCollection(
          id: 'loc-1',
          incidentId: 'inc-A',
          name: 'Café ABC',
          systemGenerated: false,
          displayOrder: 0,
          createdAt: DateTime.utc(2026, 8, 28),
          updatedAt: DateTime.utc(2026, 8, 28),
          category: 'location',
          memberEvidenceIds: const ['photo'],
        ),
      ],
    );

    expect(find.text('Café ABC'), findsOneWidget);
    expect(
      find.byKey(ReconstructionStoryCanvas.gpsCoordinateTitleKey),
      findsNothing,
    );

    await tester.tap(find.text('Café ABC'));
    await tester.pumpAndSettle();
    await expectLocationNotEditable(tester);
    final namedPair = EvidenceFormatters.coordinates(27.7172, 85.3240);
    expect(find.byType(GpsCoordinateTitleBox), findsOneWidget);
    expect(find.text(namedPair), findsOneWidget);

    await tester.tap(find.text('Café ABC'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(ReconstructionStoryCanvas.gpsCoordinateTitleKey),
      findsNothing,
    );
  });

  testWidgets('unrecognized GPS shows coordinates and is not editable', (
    tester,
  ) async {
    await pumpCanvas(
      tester,
      evidence: [
        _item(
          id: 'photo',
          capturedAt: DateTime.utc(2026, 8, 28, 4, 42),
          latitude: 27.7172,
          longitude: 85.3240,
        ),
      ],
    );

    expect(find.textContaining('27.7172°'), findsOneWidget);
    expect(
      find.byKey(ReconstructionStoryCanvas.gpsCoordinateTitleKey),
      findsNothing,
    );

    await tester.tap(find.textContaining('27.7172°'));
    await tester.pumpAndSettle();
    await expectLocationNotEditable(tester);
    final pair = EvidenceFormatters.coordinates(27.7172, 85.3240);
    expect(find.byType(GpsCoordinateTitleBox), findsOneWidget);
    expect(find.text(pair), findsOneWidget);

    await tester.tap(find.textContaining('27.7172°'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(ReconstructionStoryCanvas.gpsCoordinateTitleKey),
      findsNothing,
    );
  });

  testWidgets(
    'location tap reveals the same complete GPS pair as Graph',
    (tester) async {
      const latitude = 30.086731;
      const longitude = 78.267608;
      final pair = EvidenceFormatters.coordinates(latitude, longitude);
      WorkspaceEvidenceItem? tapped;

      await pumpCanvas(
        tester,
        evidence: [
          _item(
            id: 'photo',
            capturedAt: DateTime.utc(2026, 8, 28, 4, 42),
            latitude: latitude,
            longitude: longitude,
          ),
        ],
        onTap: (item) => tapped = item,
      );

      expect(pair, '30.08673, 78.26761');
      expect(find.text(pair), findsNothing);
      expect(
        find.byKey(ReconstructionStoryCanvas.gpsCoordinateTitleKey),
        findsNothing,
      );

      await tester.tap(
        find.byKey(
          ReconstructionStoryCanvas.locationBandKey('geo:30.0867,78.2676'),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(ReconstructionStoryCanvas.gpsCoordinateTitleKey),
        findsOneWidget,
      );
      expect(find.text(pair), findsOneWidget);
      expect(tapped, isNull);
      await expectLocationNotEditable(tester);

      await tester.tap(find.byKey(ReconstructionWorkspace.nodeKey('photo')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(ReconstructionStoryCanvas.gpsCoordinateTitleKey),
        findsNothing,
      );
      expect(tapped?.id, 'photo');
    },
  );

  testWidgets(
    'user-supplied reconstruct labels never replace system location',
    (tester) async {
      await ReconstructionLocationLabelStore.instance.save(
        incidentId: 'inc-A',
        locationKey: 'geo:27.7172,85.3240',
        label: 'User Cafe',
      );
      await ReconstructionLocationLabelStore.instance.save(
        incidentId: 'inc-A',
        locationKey: ReconstructionCanvasLayout.unknownKey,
        label: 'Typed place',
      );

      await pumpCanvas(
        tester,
        evidence: [
          _item(
            id: 'photo',
            capturedAt: DateTime.utc(2026, 8, 28, 4, 42),
            latitude: 27.7172,
            longitude: 85.3240,
          ),
        ],
      );

      expect(find.text('User Cafe'), findsNothing);
      expect(find.text('Typed place'), findsNothing);
      expect(find.textContaining('27.7172°'), findsOneWidget);
      await expectLocationNotEditable(tester);
    },
  );

  testWidgets(
    'context uses a distinct color and tapping a node reports the item',
    (tester) async {
      WorkspaceEvidenceItem? tapped;
      await pumpCanvas(
        tester,
        evidence: [
          _item(
            id: 'photo',
            capturedAt: DateTime.utc(2026, 8, 28, 4, 42),
            latitude: 27.7172,
            longitude: 85.3240,
          ),
          _item(
            id: 'note',
            kind: WorkspaceEvidenceKind.note,
            capturedAt: DateTime.utc(2026, 8, 28, 9, 0),
          ),
        ],
        organizeCreatedIds: const {'note'},
        anchors: const [
          OrganizeContextAnchor(
            contextEvidenceId: 'note',
            capturedEvidenceId: 'photo',
          ),
        ],
        onTap: (item) => tapped = item,
      );

      final marks = tester.widgetList<InvestigationEvidenceMark>(
        find.byType(InvestigationEvidenceMark),
      );
      expect(marks, hasLength(2));
      expect(
        marks.any(
          (mark) => mark.color == ReconstructionStoryCanvas.evidenceColor,
        ),
        isTrue,
      );
      expect(
        marks.any(
          (mark) => mark.color == ReconstructionStoryCanvas.contextColor,
        ),
        isTrue,
      );

      await tester.tap(find.byKey(ReconstructionWorkspace.nodeKey('photo')));
      await tester.pumpAndSettle();
      expect(tapped?.id, 'photo');
    },
  );

  testWidgets(
    'double-tap a sole connected context opens it without changing anchors',
    (tester) async {
      WorkspaceEvidenceItem? tapped;
      const anchors = [
        OrganizeContextAnchor(
          contextEvidenceId: 'note',
          capturedEvidenceId: 'photo',
        ),
      ];
      await pumpCanvas(
        tester,
        evidence: [
          _item(
            id: 'photo',
            capturedAt: DateTime.utc(2026, 8, 28, 4, 42),
            latitude: 27.7172,
            longitude: 85.3240,
          ),
          _item(
            id: 'note',
            kind: WorkspaceEvidenceKind.note,
            capturedAt: DateTime.utc(2026, 8, 28, 9, 0),
          ),
        ],
        organizeCreatedIds: const {'note'},
        anchors: anchors,
        onTap: (item) => tapped = item,
      );

      await tester.tap(find.byKey(ReconstructionWorkspace.nodeKey('note')));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byKey(ReconstructionWorkspace.nodeKey('note')));
      await tester.pump();
      await tester.pump(kDoubleTapTimeout);

      expect(tapped?.id, 'note');
      expect(anchors, hasLength(1));
      expect(anchors.single.contextEvidenceId, 'note');
      expect(anchors.single.capturedEvidenceId, 'photo');
    },
  );

  testWidgets(
    'canvas width stops after the last evidence plus trailing margin',
    (tester) async {
      final evidence = [
        _item(
          id: 'early',
          capturedAt: DateTime.utc(2026, 8, 28, 4, 42),
          latitude: 27.7172,
          longitude: 85.3240,
        ),
        _item(
          id: 'late',
          capturedAt: DateTime.utc(2026, 8, 28, 18, 10),
          latitude: 27.7172,
          longitude: 85.3240,
        ),
      ];
      await pumpCanvas(tester, evidence: evidence);

      final plot = ReconstructionCanvasLayout.fromEvidence(
        evidence: evidence,
        viewport: const Size(412, 915),
      );
      var rightmost = plot.origin.dx;
      for (final node in plot.nodes) {
        if (node.position.dx > rightmost) {
          rightmost = node.position.dx;
        }
      }
      final canvas = tester.renderObject<RenderBox>(
        find.byKey(ReconstructionStoryCanvas.canvasKey),
      );
      expect(
        canvas.size.width,
        closeTo(
          rightmost +
              ReconstructionCanvasLayout.markSize / 2 +
              ReconstructionCanvasLayout.rightPad,
          1,
        ),
      );
      expect(canvas.size.width, closeTo(plot.size.width, 0.5));
      expect(canvas.size.width.isFinite, isTrue);
    },
  );

  testWidgets(
    'CASE D: 8000px right drag cannot cross empty space; left and vertical stay locked',
    (tester) async {
      await pumpCanvas(
        tester,
        evidence: [
          _item(
            id: 'a',
            capturedAt: DateTime.utc(2026, 8, 28, 10, 0, 0),
            latitude: 27.7172,
            longitude: 85.3240,
          ),
          _item(
            id: 'b',
            capturedAt: DateTime.utc(2026, 8, 28, 10, 0, 1),
            latitude: 27.7172,
            longitude: 85.3240,
          ),
          _item(
            id: 'c',
            capturedAt: DateTime.utc(2026, 8, 28, 18, 0, 0),
            latitude: 27.7172,
            longitude: 85.3240,
          ),
        ],
      );

      final viewer = find.byType(InteractiveViewer);
      final canvas = tester.getSize(
        find.byKey(ReconstructionStoryCanvas.canvasKey),
      );
      final viewport = tester.getSize(viewer);
      expect(canvas.width.isFinite, isTrue);
      expect(canvas.width, lessThan(viewport.width * 3));

      Offset translation() {
        final transform = tester.widget<Transform>(
          find.descendant(
            of: viewer,
            matching: find.byType(Transform),
          ),
        );
        final t = transform.transform.getTranslation();
        return Offset(t.x, t.y);
      }

      await tester.timedDrag(
        viewer,
        const Offset(-8000, 0),
        const Duration(milliseconds: 500),
      );
      await tester.pumpAndSettle();
      expect(translation().dx.abs(), lessThan(viewport.width));

      await tester.timedDrag(
        viewer,
        const Offset(8000, 0),
        const Duration(milliseconds: 500),
      );
      await tester.pumpAndSettle();
      expect(translation().dx.abs(), lessThanOrEqualTo(48));

      await tester.timedDrag(
        viewer,
        const Offset(0, -8000),
        const Duration(milliseconds: 500),
      );
      await tester.pumpAndSettle();
      expect(translation().dy.abs(), lessThanOrEqualTo(48));
    },
  );

  testWidgets('does not render cards, people, or participant chrome', (
    tester,
  ) async {
    await pumpCanvas(
      tester,
      evidence: [
        _item(
          id: 'photo',
          capturedAt: DateTime.utc(2026, 8, 28, 4, 42),
          latitude: 27.7172,
          longitude: 85.3240,
        ),
      ],
    );

    expect(find.byType(NarrativeEventCard), findsNothing);
    expect(find.text('People'), findsNothing);
    expect(find.text('Participants'), findsNothing);
    expect(find.byIcon(Icons.person_outline_rounded), findsNothing);
    expect(find.byType(ReconstructionStoryCanvas), findsOneWidget);
    expect(find.textContaining('27.7172°'), findsOneWidget);
    expect(find.text('Where'), findsNothing);
    expect(find.text('WHERE'), findsNothing);
  });
}
