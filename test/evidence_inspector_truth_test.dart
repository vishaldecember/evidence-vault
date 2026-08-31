import 'package:evidence_vault/controllers/workspace_evidence_controller.dart';
import 'package:evidence_vault/domain/evidence/captured_evidence.dart';
import 'package:evidence_vault/domain/evidence/captured_evidence_type.dart';
import 'package:evidence_vault/domain/incident/incident.dart';
import 'package:evidence_vault/domain/incident/incident_status.dart';
import 'package:evidence_vault/mappers/evidence_projection.dart';
import 'package:evidence_vault/models/evidence_record_model.dart';
import 'package:evidence_vault/models/trust_summary_model.dart';
import 'package:evidence_vault/models/verification_factory.dart';
import 'package:evidence_vault/models/verification_model.dart';
import 'package:evidence_vault/models/workspace_capture_mode.dart';
import 'package:evidence_vault/models/workspace_evidence_item.dart';
import 'package:evidence_vault/presentation/evidence_inspector_semantics.dart';
import 'package:evidence_vault/repositories/incident_store.dart';
import 'package:evidence_vault/screens/evidence_record_screen.dart';
import 'package:evidence_vault/utils/workspace_evidence_formatters.dart';
import 'package:evidence_vault/widgets/evidence_inspector/evidence_spatial_carousel.dart';
import 'package:evidence_vault/widgets/investigation/inspector_context_section.dart';
import 'package:evidence_vault/widgets/investigation/investigation_evidence_inspector_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

WorkspaceEvidenceItem _photo({
  DateTime? capturedAt,
  DateTime? recordedAt,
  DateTime? updatedAt,
  DateTime? lastPreservedAt,
  VerificationModel? verification,
  bool integrityVerified = true,
}) {
  final captured = capturedAt ?? DateTime.utc(2026, 8, 20, 12, 0, 0);
  return WorkspaceEvidenceItem(
    id: 'evidence-a1',
    kind: WorkspaceEvidenceKind.image,
    title: 'Street photo',
    lastPreservedAt: lastPreservedAt ?? captured,
    capturedAt: capturedAt,
    recordedAt: recordedAt,
    updatedAt: updatedAt,
    integrityVerified: integrityVerified,
    verification: verification ?? VerificationFactory.initial(),
    incidentId: 'incident-a',
  );
}

void main() {
  group('timestamp semantics', () {
    test('capturedAt is presented as Captured, not Recorded', () {
      final captured = DateTime.utc(2026, 8, 20, 15, 4, 5);
      final rows = EvidenceInspectorSemantics.instants(
        _photo(capturedAt: captured),
      );

      expect(rows, hasLength(1));
      expect(rows.single.label, EvidenceInspectorSemantics.capturedLabel);
      expect(rows.single.instant, captured);
      expect(rows.single.label, isNot('Timestamp'));
      expect(rows.single.label, isNot('Capture date'));
    });

    test('distinct recordedAt is not labeled as capture time', () {
      final captured = DateTime.utc(2026, 8, 20, 15, 4, 5);
      final recorded = DateTime.utc(2026, 8, 21, 9, 0, 0);
      final rows = EvidenceInspectorSemantics.instants(
        _photo(capturedAt: captured, recordedAt: recorded),
      );

      expect(rows, hasLength(2));
      expect(rows[0].label, EvidenceInspectorSemantics.capturedLabel);
      expect(rows[0].instant, captured);
      expect(rows[1].label, EvidenceInspectorSemantics.recordedLabel);
      expect(rows[1].instant, recorded);
    });

    test('updatedAt is not presented as capture or record time', () {
      final captured = DateTime.utc(2026, 8, 20, 15, 4, 5);
      final updated = DateTime.utc(2026, 8, 22, 18, 0, 0);
      final rows = EvidenceInspectorSemantics.instants(
        _photo(capturedAt: captured, updatedAt: updated),
      );

      expect(rows, hasLength(1));
      expect(rows.single.instant, captured);
      expect(rows.any((row) => row.instant == updated), isFalse);
    });

    test('identical captured and recorded instants are not duplicated', () {
      final at = DateTime.utc(2026, 8, 20, 15, 4, 5);
      final rows = EvidenceInspectorSemantics.instants(
        _photo(capturedAt: at, recordedAt: at.toLocal()),
      );

      expect(rows, hasLength(1));
      expect(rows.single.label, EvidenceInspectorSemantics.capturedLabel);
    });

    test('supporting items without capturedAt use Recorded', () {
      final recorded = DateTime.utc(2026, 8, 21, 10, 0, 0);
      final note = WorkspaceEvidenceItem(
        id: 'note-1',
        kind: WorkspaceEvidenceKind.note,
        title: 'Note',
        lastPreservedAt: recorded,
        recordedAt: recorded,
        integrityVerified: false,
        verification: VerificationFactory.initial(),
      );
      final rows = EvidenceInspectorSemantics.instants(note);

      expect(rows, hasLength(1));
      expect(rows.single.label, EvidenceInspectorSemantics.recordedLabel);
      expect(rows.single.instant, recorded);
    });

    test('legacy items without projected clocks still get one truthful label', () {
      final photo = WorkspaceEvidenceItem(
        id: 'legacy',
        kind: WorkspaceEvidenceKind.image,
        title: 'Legacy',
        lastPreservedAt: DateTime.utc(2026, 8, 1, 8),
        integrityVerified: false,
        verification: VerificationFactory.initial(),
      );
      final note = WorkspaceEvidenceItem(
        id: 'legacy-note',
        kind: WorkspaceEvidenceKind.note,
        title: 'Legacy note',
        lastPreservedAt: DateTime.utc(2026, 8, 1, 9),
        integrityVerified: false,
        verification: VerificationFactory.initial(),
      );

      expect(
        EvidenceInspectorSemantics.instants(photo).single.label,
        EvidenceInspectorSemantics.capturedLabel,
      );
      expect(
        EvidenceInspectorSemantics.instants(note).single.label,
        EvidenceInspectorSemantics.recordedLabel,
      );
    });

    test('timezone formatting does not change the underlying instant', () {
      final instant = DateTime.utc(2026, 8, 20, 15, 4, 5);
      final rows = EvidenceInspectorSemantics.instants(
        _photo(capturedAt: instant),
      );
      final formatted = WorkspaceEvidenceFormatters.inspectorTimestamp(instant);

      expect(rows.single.instant.isUtc, isTrue);
      expect(rows.single.instant, instant);
      expect(formatted.contains('15:04:05') || formatted.contains(':'), isTrue);
      expect(instant, DateTime.utc(2026, 8, 20, 15, 4, 5));
    });

    test('carousel order stays lastPreservedAt, independent of display labels', () {
      final early = _photo(
        capturedAt: DateTime.utc(2026, 8, 20, 10),
        lastPreservedAt: DateTime.utc(2026, 8, 20, 10),
      ).copyWith();
      final late = WorkspaceEvidenceItem(
        id: 'evidence-b',
        kind: WorkspaceEvidenceKind.image,
        title: 'Later',
        lastPreservedAt: DateTime.utc(2026, 8, 20, 12),
        capturedAt: DateTime.utc(2026, 8, 19, 8),
        integrityVerified: true,
        verification: VerificationFactory.initial(),
      );

      final ordered = evidenceInspectorOrder([late, early]);
      expect(ordered.map((item) => item.id), ['evidence-a1', 'evidence-b']);
      expect(
        EvidenceInspectorSemantics.instants(late).first.instant,
        DateTime.utc(2026, 8, 19, 8),
      );
    });
  });

  group('integrity semantics', () {
    test('integrityVerified flag is not treated as independent verification', () {
      final item = _photo(integrityVerified: true);
      expect(
        EvidenceInspectorSemantics.integrityStatus(item),
        EvidenceInspectorSemantics.integrityNotVerified,
      );
      expect(EvidenceInspectorSemantics.verifiedAt(item), isNull);

      final summary = TrustSummaryModel.fromRecord(
        EvidenceRecordModel.fromWorkspace(
          evidence: item,
          allItems: [item],
          relationships: const [],
        ),
      );
      expect(summary.entries.map((e) => e.value), [
        EvidenceInspectorSemantics.integrityNotVerified,
      ]);
      expect(summary.entries.any((e) => e.value == 'Verified'), isFalse);
      expect(summary.entries.any((e) => e.value == 'Original Preserved'), isFalse);
    });

    test('pending and verified use the verification model only', () {
      expect(
        EvidenceInspectorSemantics.integrityStatus(
          _photo(verification: VerificationModel.pending()),
        ),
        EvidenceInspectorSemantics.integrityPending,
      );

      final at = DateTime.utc(2026, 8, 23, 11);
      final verified = _photo(
        verification: VerificationModel.verified(verifiedAt: at),
      );
      expect(
        EvidenceInspectorSemantics.integrityStatus(verified),
        EvidenceInspectorSemantics.integrityVerified,
      );
      expect(EvidenceInspectorSemantics.verifiedAt(verified), at);
    });

    test('missing hash is not fabricated', () {
      final item = _photo();
      final summary = TrustSummaryModel.fromRecord(
        EvidenceRecordModel.fromWorkspace(
          evidence: item,
          allItems: [item],
          relationships: const [],
        ),
      );
      expect(
        summary.entries.any(
          (entry) =>
              entry.label.toLowerCase().contains('hash') ||
              entry.value.toLowerCase().contains('hash'),
        ),
        isFalse,
      );
    });
  });

  group('context authorship', () {
    test('observation copy is explicitly user-authored', () {
      expect(
        EvidenceInspectorSemantics.observationLabel,
        'Your observation',
      );
      expect(
        InspectorContextSection.placeholder,
        EvidenceInspectorSemantics.observationPlaceholder,
      );
      expect(
        EvidenceInspectorSemantics.observationPlaceholder
            .toLowerCase()
            .contains('shows'),
        isFalse,
      );
    });
  });

  group('projection and integrity', () {
    test('projection maps capturedAt/createdAt without mutating the domain item',
        () {
      final captured = DateTime.utc(2026, 8, 20, 12);
      final created = DateTime.utc(2026, 8, 20, 12, 0, 1);
      final evidence = CapturedEvidence(
        id: 'evidence-a1',
        incidentId: 'incident-a',
        type: CapturedEvidenceType.photo,
        capturedAt: captured,
        createdAt: created,
        title: 'Photo',
        integrityVerified: false,
        verification: VerificationFactory.initial(),
        timelineAnchorId: 'anchor-a1',
        contentHash: 'hash-a1',
        timelineOrder: 3,
        filePath: '/evidence/a1.jpg',
      );
      final store = IncidentStore(
        incident: Incident(
          id: 'incident-a',
          title: 'Alpha',
          status: IncidentStatus.active,
          createdAt: DateTime.utc(2026, 8, 20),
          updatedAt: DateTime.utc(2026, 8, 21),
        ),
        capturedEvidence: [evidence],
      );

      final projected = EvidenceProjection.toWorkspaceItems(store).single;
      expect(projected.capturedAt, captured);
      expect(projected.recordedAt, created);
      expect(projected.lastPreservedAt, captured);
      expect(projected.contentHash, 'hash-a1');

      expect(identical(store.capturedEvidence.single, evidence), isTrue);
      expect(store.capturedEvidence.single.contentHash, 'hash-a1');
      expect(store.capturedEvidence.single.capturedAt, captured);
      expect(store.capturedEvidence.single.createdAt, created);
      expect(store.capturedEvidence.single.timelineOrder, 3);
      expect(store.capturedEvidence.single.id, 'evidence-a1');
      expect(store.capturedEvidence.single.incidentId, 'incident-a');
      expect(store.capturedEvidence.single.filePath, '/evidence/a1.jpg');
      expect(store.timelineAnchors, isEmpty);
    });
  });

  testWidgets('inspector shows captured clock, quiet integrity, and observation',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(412, 915));
    final controller = WorkspaceEvidenceController();
    controller.preserveEvidence(WorkspaceCaptureMode.photo);
    final evidence = controller.journeyEvidenceItems.first;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () {
                  showInvestigationEvidenceInspectorModal(
                    context: context,
                    evidence: evidence,
                    controller: controller,
                    orderedEvidence: evidenceInspectorOrder(
                      controller.journeyEvidenceItems,
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Evidence Inspector'), findsOneWidget);
    expect(find.text('Captured'), findsWidgets);
    expect(find.text('Timestamp'), findsNothing);
    expect(find.text('Integrity Verified'), findsNothing);
    expect(find.text('Independent verification'), findsNothing);
    expect(find.text('Not performed'), findsNothing);
    expect(find.text('Verified'), findsOneWidget);
    expect(find.text('Your observation'), findsOneWidget);
    expect(find.text('Describe what this evidence shows...'), findsNothing);
    expect(find.byKey(const Key('evidence_inspector_timestamp')), findsOneWidget);
    expect(find.byKey(const Key('evidence_inspector_integrity')), findsOneWidget);

    expect(evidence.id, controller.journeyEvidenceItems.first.id);
    expect(
      evidence.lastPreservedAt,
      controller.journeyEvidenceItems.first.lastPreservedAt,
    );
  });

  testWidgets('complete record uses integrity wording, not theatrical verified',
      (tester) async {
    final photo = _photo(
      capturedAt: DateTime.utc(2026, 8, 20, 12),
      lastPreservedAt: DateTime.utc(2026, 8, 20, 12),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: EvidenceRecordScreen(
          evidenceId: photo.id,
          getItems: () => [photo],
          getRelationships: () => const [],
          onAddContext: (_, _) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Captured'), findsOneWidget);
    expect(find.text('Preserved'), findsNothing);
    expect(find.text('Timestamp'), findsNothing);
    expect(find.text('Capture date'), findsNothing);
    expect(find.text('Integrity'), findsOneWidget);
    expect(find.text('Not performed'), findsOneWidget);
    expect(find.text('Your observations'), findsOneWidget);
    expect(find.text('Original Preserved'), findsNothing);
  });
}
