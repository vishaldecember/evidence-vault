import 'package:evidence_vault/domain/incident/current_incident.dart';
import 'package:evidence_vault/domain/incident/incident_status.dart';
import 'package:evidence_vault/models/journey_stage.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/widgets/capture/capture_sticky_bar.dart';
import 'package:evidence_vault/widgets/common/capture_mode_icon.dart';
import 'package:evidence_vault/widgets/home/quick_capture_button.dart';
import 'package:evidence_vault/widgets/home/quick_capture_section.dart';
import 'package:evidence_vault/widgets/workspace/capture_action_button.dart';
import 'package:evidence_vault/widgets/workspace/evidence_composition_guide.dart';
import 'package:evidence_vault/widgets/workspace/organize_workspace_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

CurrentIncident _incident() {
  return CurrentIncident(
    id: 'inc-icons',
    title: 'Case',
    status: IncidentStatus.active,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    manuallyComplete: false,
    journeyStage: JourneyStage.building,
    captureProgressPercent: 0,
    timelineAnchorCount: 0,
    relationshipGroupCount: 0,
    narrativeEventCount: 0,
    evidence: const [],
    journeyEvidence: const [],
    relationshipGroups: const [],
    evidenceCollections: const [],
    trustPackageReady: false,
    trustPackageProgressPercent: 0,
  );
}

void main() {
  testWidgets('Capture Now, sticky bar, and Organize share CaptureModeIcon', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(390, 844));

    var nowTapped = QuickCaptureType.photo;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuickCaptureSection(onCaptureTap: (type) => nowTapped = type),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);

    for (final mode in WorkspaceCaptureMode.values) {
      expect(find.byKey(CaptureModeIcon.keyFor(mode)), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(CaptureModeIcon.keyFor(mode)),
          matching: find.image(AssetImage(CaptureModeIcon.assetFor(mode))),
        ),
        findsOneWidget,
      );
    }
    expect(find.byType(CaptureModeIcon), findsNWidgets(5));
    expect(find.byType(PinnedCaptureModeIcon), findsNWidgets(5));
    final nowIcon = tester.getRect(
      find.byKey(CaptureModeIcon.keyFor(WorkspaceCaptureMode.photo)),
    );
    final nowSlot = tester.getRect(find.byType(PinnedCaptureModeIcon).first);
    final nowLabel = tester.getRect(find.text('Photo'));
    expect(nowIcon.width, closeTo(46, 0.5));
    expect(nowIcon.height, closeTo(46, 0.5));
    expect(nowSlot.width, closeTo(42, 0.5));
    expect(nowSlot.height, closeTo(42, 0.5));
    expect(nowIcon.bottom, closeTo(nowSlot.bottom, 0.5));
    expect(nowLabel.top, closeTo(nowSlot.bottom + 6, 0.5));
    expect(
      CaptureModeIconAssets.all,
      WorkspaceCaptureMode.values.map(CaptureModeIcon.assetFor),
    );
    expect(find.byIcon(Icons.photo_camera_outlined), findsNothing);
    expect(find.byIcon(Icons.videocam_outlined), findsNothing);
    expect(find.byIcon(Icons.mic_outlined), findsNothing);
    expect(find.byIcon(Icons.edit_note_outlined), findsNothing);
    expect(find.byIcon(Icons.attach_file_outlined), findsNothing);

    await tester.tap(find.text('Video'));
    await tester.pump();
    expect(nowTapped, QuickCaptureType.video);

    var stickyMode = WorkspaceCaptureMode.photo;
    var noteTapped = false;
    var fileTapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CaptureStickyBar(
            onModalitySelected: (mode) => stickyMode = mode,
            onNoteTap: () => noteTapped = true,
            onFileTap: () => fileTapped = true,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(CaptureModeIcon), findsNWidgets(5));
    for (final mode in WorkspaceCaptureMode.values) {
      expect(find.byKey(CaptureModeIcon.keyFor(mode)), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(CaptureModeIcon.keyFor(mode)),
          matching: find.image(AssetImage(CaptureModeIcon.assetFor(mode))),
        ),
        findsOneWidget,
      );
    }
    expect(find.byType(PinnedCaptureModeIcon), findsNWidgets(5));
    final stickyIcon = tester.getRect(
      find.byKey(CaptureModeIcon.keyFor(WorkspaceCaptureMode.photo)),
    );
    final stickySlot = tester.getRect(find.byType(PinnedCaptureModeIcon).first);
    final stickyLabel = tester.getRect(find.text('Photo'));
    expect(stickyIcon.width, closeTo(31, 0.5));
    expect(stickyIcon.height, closeTo(31, 0.5));
    expect(stickySlot.width, closeTo(28, 0.5));
    expect(stickySlot.height, closeTo(28, 0.5));
    expect(stickyIcon.bottom, closeTo(stickySlot.bottom, 0.5));
    expect(stickyLabel.top, closeTo(stickySlot.bottom + 2, 0.5));
    await tester.tap(find.byKey(const Key('capture_action_voice')));
    await tester.pump();
    expect(stickyMode, WorkspaceCaptureMode.voice);
    await tester.tap(find.byKey(const Key('capture_action_note')));
    await tester.pump();
    expect(noteTapped, isTrue);
    await tester.tap(find.byKey(const Key('capture_action_file')));
    await tester.pump();
    expect(fileTapped, isTrue);

    var organizeMode = WorkspaceCaptureMode.voice;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OrganizeWorkspaceView(
            incident: _incident(),
            onEvidenceSelected: (_) {},
            onAddOrganizeContext: (mode) => organizeMode = mode,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    final bar = find.byKey(OrganizeWorkspaceView.addContextBarKey);
    expect(bar, findsOneWidget);
    expect(
      find.descendant(of: bar, matching: find.byType(CaptureModeIcon)),
      findsNWidgets(3),
    );
    expect(
      find.descendant(of: bar, matching: find.byType(PinnedCaptureModeIcon)),
      findsNothing,
    );
    final organizeIcon = tester.getSize(
      find.descendant(
        of: bar,
        matching: find.byKey(
          CaptureModeIcon.keyFor(WorkspaceCaptureMode.voice),
        ),
      ),
    );
    expect(organizeIcon.width, closeTo(30, 0.5));
    expect(organizeIcon.height, closeTo(30, 0.5));
    expect(
      find.descendant(
        of: bar,
        matching: find.byKey(
          CaptureModeIcon.keyFor(WorkspaceCaptureMode.voice),
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: bar,
        matching: find.byKey(CaptureModeIcon.keyFor(WorkspaceCaptureMode.note)),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: bar,
        matching: find.byKey(CaptureModeIcon.keyFor(WorkspaceCaptureMode.file)),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: bar,
        matching: find.image(
          AssetImage(CaptureModeIcon.assetFor(WorkspaceCaptureMode.voice)),
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: bar,
        matching: find.image(
          AssetImage(CaptureModeIcon.assetFor(WorkspaceCaptureMode.note)),
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: bar,
        matching: find.image(
          AssetImage(CaptureModeIcon.assetFor(WorkspaceCaptureMode.file)),
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: bar, matching: find.byType(CaptureActionButton)),
      findsNWidgets(3),
    );
    await tester.tap(
      find.descendant(
        of: bar,
        matching: find.byKey(CaptureModeIcon.keyFor(WorkspaceCaptureMode.note)),
      ),
    );
    await tester.pump();
    expect(organizeMode, WorkspaceCaptureMode.note);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: EvidenceCompositionGuide()),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(
      find.descendant(
        of: find.byKey(EvidenceCompositionGuide.guideKey),
        matching: find.byType(CaptureModeIcon),
      ),
      findsWidgets,
    );
    for (final mode in const [
      WorkspaceCaptureMode.photo,
      WorkspaceCaptureMode.video,
      WorkspaceCaptureMode.voice,
      WorkspaceCaptureMode.note,
    ]) {
      expect(
        find.descendant(
          of: find.byKey(EvidenceCompositionGuide.guideKey),
          matching: find.image(AssetImage(CaptureModeIcon.assetFor(mode))),
        ),
        findsWidgets,
      );
    }
    expect(
      find.descendant(
        of: find.byKey(EvidenceCompositionGuide.guideKey),
        matching: find.image(
          AssetImage(CaptureModeIcon.assetFor(WorkspaceCaptureMode.file)),
        ),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(EvidenceCompositionGuide.guideKey),
        matching: find.byIcon(Icons.person_outline),
      ),
      findsWidgets,
    );
    final guideIcon = tester.getSize(
      find.descendant(
        of: find.byKey(EvidenceCompositionGuide.guideKey),
        matching: find.byKey(CaptureModeIcon.keyFor(WorkspaceCaptureMode.photo)),
      ).first,
    );
    expect(guideIcon.width, closeTo(16, 0.5));
    expect(guideIcon.height, closeTo(16, 0.5));
  });
}
