import 'package:evidence_vault/domain/organize/organize_context_anchor.dart';
import 'package:evidence_vault/models/verification_factory.dart';
import 'package:evidence_vault/models/workspace_evidence_item.dart';
import 'package:evidence_vault/services/investigation/reconstruction_location_label_store.dart';
import 'package:evidence_vault/widgets/investigation/investigation_evidence_mark.dart';
import 'package:evidence_vault/widgets/investigation/reconstruction_story_canvas.dart';
import 'package:evidence_vault/widgets/investigation/reconstruction_workspace.dart';
import 'package:evidence_vault/widgets/reconstruction/narrative/narrative_event_card.dart';
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
            organizeCreatedIds: organizeCreatedIds,
            contextAnchors: anchors,
            onEvidenceTap: onTap ?? (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('unknown location keeps a red pin and can be named by the user', (
    tester,
  ) async {
    await pumpCanvas(
      tester,
      evidence: [
        _item(id: 'photo', capturedAt: DateTime.utc(2026, 8, 28, 4, 42)),
      ],
    );

    expect(find.text('Add location'), findsOneWidget);
    final pin = tester.widget<Icon>(find.byIcon(Icons.place_rounded));
    expect(pin.color, ReconstructionStoryCanvas.locationRed);

    await tester.tap(find.text('Add location'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Café ABC');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Café ABC'), findsOneWidget);
    expect(find.byIcon(Icons.place_rounded), findsOneWidget);
  });

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
