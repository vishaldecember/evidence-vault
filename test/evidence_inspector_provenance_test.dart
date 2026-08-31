import 'package:evidence_vault/controllers/workspace_evidence_controller.dart';
import 'package:evidence_vault/models/evidence_relationship.dart';
import 'package:evidence_vault/models/verification_factory.dart';
import 'package:evidence_vault/models/workspace_evidence_item.dart';
import 'package:evidence_vault/presentation/evidence_inspector_semantics.dart';
import 'package:evidence_vault/services/metadata_service.dart';
import 'package:evidence_vault/theme/app_colors.dart';
import 'package:evidence_vault/widgets/evidence_inspector/evidence_spatial_carousel.dart';
import 'package:evidence_vault/widgets/investigation/investigation_evidence_inspector_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

WorkspaceEvidenceItem _item({
  required String id,
  required WorkspaceEvidenceKind kind,
  String? contentHash,
  String? deviceModel,
  double? latitude,
  double? longitude,
}) {
  final captured = DateTime.utc(2026, 8, 20, 12);
  return WorkspaceEvidenceItem(
    id: id,
    kind: kind,
    title: 'Evidence $id',
    lastPreservedAt: captured,
    capturedAt: captured,
    integrityVerified: true,
    verification: VerificationFactory.initial(),
    contentHash: contentHash,
    deviceModel: deviceModel,
    latitude: latitude,
    longitude: longitude,
    incidentId: 'incident-1',
  );
}

Future<void> _openInspector(
  WidgetTester tester, {
  required WorkspaceEvidenceController controller,
  required WorkspaceEvidenceItem evidence,
  Future<void> Function(WorkspaceEvidenceItem evidence)? onOpenAdvancedRecord,
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
                    orderedEvidence: evidenceInspectorOrder(
                      controller.journeyEvidenceItems,
                    ),
                    onOpenAdvancedRecord: onOpenAdvancedRecord,
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

void main() {
  group('capture modality', () {
    test('maps each capture kind without inventing a pathway', () {
      expect(
        EvidenceInspectorSemantics.captureModality(
          _item(id: 'photo', kind: WorkspaceEvidenceKind.image),
        ),
        'Device Camera',
      );
      expect(
        EvidenceInspectorSemantics.captureModality(
          _item(id: 'video', kind: WorkspaceEvidenceKind.video),
        ),
        'Device Camera',
      );
      expect(
        EvidenceInspectorSemantics.captureModality(
          _item(id: 'voice', kind: WorkspaceEvidenceKind.voice),
        ),
        'Device Microphone',
      );
      expect(
        EvidenceInspectorSemantics.captureModality(
          _item(id: 'note', kind: WorkspaceEvidenceKind.note),
        ),
        'Text Entry',
      );
      expect(
        EvidenceInspectorSemantics.captureModality(
          _item(id: 'file', kind: WorkspaceEvidenceKind.attachment),
        ),
        'File Import / Attachment',
      );
    });

    testWidgets('Inspector shows capture modality separately from type',
        (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(412, 915));
      final controller = WorkspaceEvidenceController(
        initialState: WorkspaceEvidenceState(
          items: [_item(id: 'voice', kind: WorkspaceEvidenceKind.voice)],
        ),
      );

      await _openInspector(
        tester,
        controller: controller,
        evidence: controller.journeyEvidenceItems.first,
      );

      expect(find.text('Type'), findsOneWidget);
      expect(find.text('Voice Note'), findsWidgets);
      expect(find.text('Capture modality'), findsOneWidget);
      expect(find.text('Device Microphone'), findsOneWidget);
      expect(
        find.byKey(const Key('evidence_inspector_capture_modality')),
        findsOneWidget,
      );
    });
  });

  group('device source', () {
    test('formats manufacturer and model without inventing a generic phone', () {
      expect(
        MetadataService.formatDeviceSource(
          manufacturer: 'motorola',
          model: 'moto g35 5G',
        ),
        'Motorola moto g35 5G',
      );
      expect(
        MetadataService.formatDeviceSource(
          manufacturer: 'Motorola',
          model: 'motorola moto g35 5G',
        ),
        'motorola moto g35 5G',
      );
      expect(
        MetadataService.formatDeviceSource(
          manufacturer: 'Google',
          model: 'Pixel 8',
        ),
        'Google Pixel 8',
      );
      expect(
        MetadataService.formatDeviceSource(
          manufacturer: '',
          model: '',
        ),
        '',
      );
    });
  });

  group('location at capture', () {
    testWidgets('shows Unavailable when capture coordinates were not stored',
        (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(412, 915));
      final controller = WorkspaceEvidenceController(
        initialState: WorkspaceEvidenceState(
          items: [
            _item(
              id: 'photo',
              kind: WorkspaceEvidenceKind.image,
              deviceModel: 'Motorola moto g35 5G',
            ),
          ],
        ),
      );

      await _openInspector(
        tester,
        controller: controller,
        evidence: controller.journeyEvidenceItems.first,
      );

      expect(find.text('Location'), findsOneWidget);
      expect(
        find.byKey(const Key('evidence_inspector_location')),
        findsOneWidget,
      );
      expect(find.text('Unavailable'), findsOneWidget);
      final unavailable = tester.widget<Text>(
        find.byKey(const Key('evidence_inspector_location')),
      );
      expect(unavailable.style?.color, AppColors.warning);
      expect(find.text('Recorded at capture'), findsNothing);
      expect(find.textContaining('Pokhara'), findsNothing);
      expect(find.text('0.0, 0.0'), findsNothing);
      expect(find.text('Device'), findsOneWidget);
      expect(find.text('Motorola moto g35 5G'), findsOneWidget);
    });

    testWidgets('shows Recorded at capture when coordinates exist on the item',
        (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(412, 915));
      final controller = WorkspaceEvidenceController(
        initialState: WorkspaceEvidenceState(
          items: [
            _item(
              id: 'photo',
              kind: WorkspaceEvidenceKind.image,
              latitude: 28.2096,
              longitude: 83.9856,
            ),
          ],
        ),
      );

      await _openInspector(
        tester,
        controller: controller,
        evidence: controller.journeyEvidenceItems.first,
      );

      expect(find.text('Recorded at capture'), findsOneWidget);
      expect(find.textContaining('Pokhara'), findsNothing);
      expect(find.text('28.2096'), findsNothing);
    });
  });

  group('verification presentation', () {
    testWidgets('app-captured photo shows a green Verified check', (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(412, 915));
      final controller = WorkspaceEvidenceController(
        initialState: WorkspaceEvidenceState(
          items: [_item(id: 'photo', kind: WorkspaceEvidenceKind.image)],
        ),
      );

      await _openInspector(
        tester,
        controller: controller,
        evidence: controller.journeyEvidenceItems.first,
      );

      expect(find.text('Independent verification'), findsNothing);
      expect(find.text('Verified'), findsOneWidget);
      final check = tester.widget<Icon>(
        find.descendant(
          of: find.byKey(const Key('evidence_inspector_verification')),
          matching: find.byIcon(Icons.check),
        ),
      );
      expect(check.color, AppColors.success);
    });
  });

  group('fingerprint', () {
    testWidgets('Inspector shows hash recorded without the SHA-256 string', (
      tester,
    ) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(412, 915));
      final hashed = _item(
        id: 'hashed',
        kind: WorkspaceEvidenceKind.note,
        contentHash: 'abcdef0123456789deadbeef42',
      );
      final controller = WorkspaceEvidenceController(
        initialState: WorkspaceEvidenceState(items: [hashed]),
      );

      await _openInspector(
        tester,
        controller: controller,
        evidence: controller.journeyEvidenceItems.first,
      );

      expect(find.text('SHA-256 recorded'), findsOneWidget);
      expect(find.text('abcdef0123456789deadbeef42'), findsNothing);
      expect(find.text('Independent verification'), findsNothing);
    });
  });

  group('sticky View complete record', () {
    testWidgets('stays above Close, outside the scroll, with on-canvas color',
        (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(412, 915));
      final controller = WorkspaceEvidenceController(
        initialState: WorkspaceEvidenceState(
          items: [_item(id: 'photo', kind: WorkspaceEvidenceKind.image)],
        ),
      );

      await _openInspector(
        tester,
        controller: controller,
        evidence: controller.journeyEvidenceItems.first,
        onOpenAdvancedRecord: (_) async {},
      );

      final record = find.byKey(const Key('evidence_inspector_open_full_record'));
      final close = find.byKey(const Key('evidence_inspector_close'));
      expect(find.text('View complete record →'), findsOneWidget);
      expect(record, findsOneWidget);
      expect(close, findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('evidence_inspector_body_scroll')),
          matching: record,
        ),
        findsNothing,
      );
      expect(
        tester.getTopLeft(record).dy,
        lessThan(tester.getTopLeft(close).dy),
      );

      final label = tester.widget<Text>(
        find.descendant(of: record, matching: find.byType(Text)),
      );
      expect(label.style?.color, AppColors.onCanvas);
    });
  });

  group('applyCaptureProvenance', () {
    test('stamps device and location without changing ids, hash, or chronology',
        () {
      const hash = 'abcdef0123456789deadbeef42';
      final controller = WorkspaceEvidenceController(
        initialState: WorkspaceEvidenceState(
          items: [
            _item(
              id: 'photo-a',
              kind: WorkspaceEvidenceKind.image,
              contentHash: hash,
            ),
            _item(id: 'photo-b', kind: WorkspaceEvidenceKind.image),
          ],
        ),
      );
      final before = controller.currentIncident.evidenceById('photo-a')!;
      final chronologyBefore =
          List<String>.from(controller.timelineRepository.orderedCapturedEvidenceIds());

      controller.applyCaptureProvenance(
        evidenceId: 'photo-a',
        deviceModel: 'Motorola moto g35 5G',
        latitude: 28.2096,
        longitude: 83.9856,
      );

      final after = controller.currentIncident.evidenceById('photo-a')!;
      expect(after.id, before.id);
      expect(after.contentHash, hash);
      expect(after.capturedAt, before.capturedAt);
      expect(after.lastPreservedAt, before.lastPreservedAt);
      expect(after.kind, before.kind);
      expect(after.deviceModel, 'Motorola moto g35 5G');
      expect(after.latitude, 28.2096);
      expect(after.longitude, 83.9856);
      expect(
        controller.timelineRepository.orderedCapturedEvidenceIds(),
        chronologyBefore,
      );
    });
  });
}
