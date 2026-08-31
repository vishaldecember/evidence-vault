import 'package:evidence_vault/controllers/workspace_evidence_controller.dart';
import 'package:evidence_vault/controllers/workspace_session.dart';
import 'package:evidence_vault/models/verification_factory.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/models/workspace_evidence_factory.dart';
import 'package:evidence_vault/models/workspace_evidence_item.dart';
import 'package:evidence_vault/repositories/workspace_evidence_repository.dart';
import 'package:evidence_vault/screens/evidence_workspace_screen.dart';
import 'package:evidence_vault/widgets/workspace/journey_evidence_thumbnail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    WorkspaceSession.instance.reset();
    WorkspaceEvidenceFactory.resetForTests();
  });

  group('WorkspaceEvidenceRepository', () {
    test('journeySequence preserves capture order including supporting', () {
      final items = [
        WorkspaceEvidenceItem(
          id: 'photo',
          kind: WorkspaceEvidenceKind.image,
          title: 'Photo',
          lastPreservedAt: DateTime(2026, 7, 28, 9),
          integrityVerified: true,
          verification: VerificationFactory.initial(),
        ),
        WorkspaceEvidenceItem(
          id: 'voice',
          kind: WorkspaceEvidenceKind.voice,
          title: 'Voice',
          lastPreservedAt: DateTime(2026, 7, 28, 10),
          integrityVerified: true,
          verification: VerificationFactory.initial(),
        ),
        WorkspaceEvidenceItem(
          id: 'note',
          kind: WorkspaceEvidenceKind.note,
          title: 'Note',
          lastPreservedAt: DateTime(2026, 7, 28, 11),
          integrityVerified: true,
          verification: VerificationFactory.initial(),
        ),
        WorkspaceEvidenceItem(
          id: 'ctx',
          kind: WorkspaceEvidenceKind.note,
          title: 'Context',
          lastPreservedAt: DateTime(2026, 7, 28, 12),
          integrityVerified: true,
          verification: VerificationFactory.initial(),
          isContextual: true,
          parentEvidenceId: 'voice',
        ),
      ];

      final sequence = WorkspaceEvidenceRepository.journeySequenceFromItems(items);

      expect(
        sequence.map((item) => item.id),
        ['photo', 'voice', 'note', 'ctx'],
      );
    });
  });

  group('WorkspaceEvidenceController journey evidence', () {
    test('journeyEvidenceItems updates immediately after preserve', () {
      final controller = WorkspaceEvidenceController();

      expect(controller.journeyEvidenceItems, isEmpty);

      controller.preserveEvidence(WorkspaceCaptureMode.photo);
      expect(controller.journeyEvidenceItems, hasLength(1));
      expect(controller.journeyEvidenceItems.first.kind, WorkspaceEvidenceKind.image);

      controller.preserveEvidence(WorkspaceCaptureMode.voice);
      expect(controller.journeyEvidenceItems, hasLength(2));
      expect(
        controller.journeyEvidenceItems.map((item) => item.kind),
        [
          WorkspaceEvidenceKind.image,
          WorkspaceEvidenceKind.voice,
        ],
      );
    });
  });

  group('Incident Journey immediate rendering', () {
    testWidgets('initial quick capture appears without navigation',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: EvidenceWorkspaceScreen(
            initialCaptureMode: WorkspaceCaptureMode.photo,
          ),
        ),
      );

      // Capture is deferred off the mount frame so CurrentIncident can notify
      // observers safely; one settle delivers the shared evidence collection.
      await tester.pumpAndSettle();

      expect(find.byType(JourneyEvidenceThumbnail), findsOneWidget);
    });

    testWidgets('workspace capture updates journey without extra delay',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: EvidenceWorkspaceScreen()),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Photo').first);
      await tester.pump();

      expect(find.byType(JourneyEvidenceThumbnail), findsOneWidget);

      await tester.tap(find.text('Note').last);
      await tester.pump();

      // Sprint 4G.1: Captured lane renders primary only; notes await 4G.2.
      expect(find.byType(JourneyEvidenceThumbnail), findsOneWidget);
      expect(find.text('Text Note'), findsOneWidget);
    });
  });
}
