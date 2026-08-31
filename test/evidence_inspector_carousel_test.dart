import 'package:evidence_vault/controllers/workspace_evidence_controller.dart';
import 'package:evidence_vault/models/evidence_relationship.dart';
import 'package:evidence_vault/models/verification_factory.dart';
import 'package:evidence_vault/models/workspace_evidence_item.dart';
import 'package:evidence_vault/widgets/capture/live_evidence_timeline.dart';
import 'package:evidence_vault/widgets/evidence_inspector/evidence_inspector_preview.dart';
import 'package:evidence_vault/widgets/evidence_inspector/evidence_spatial_carousel.dart';
import 'package:evidence_vault/widgets/investigation/investigation_evidence_inspector_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

WorkspaceEvidenceItem _item({
  required String id,
  DateTime? at,
  WorkspaceEvidenceKind kind = WorkspaceEvidenceKind.image,
  String? thumbnailPath,
  String? filePath,
}) {
  return WorkspaceEvidenceItem(
    id: id,
    kind: kind,
    title: 'Evidence $id',
    lastPreservedAt: at ?? DateTime(2026, 8, 12, 10),
    integrityVerified: true,
    verification: VerificationFactory.initial(),
    thumbnailPath: thumbnailPath,
    filePath: filePath,
  );
}

List<WorkspaceEvidenceItem> _nItems(int count) {
  return List.generate(
    count,
    (i) => _item(
      id: 'e$i',
      at: DateTime(2026, 8, 12, 10, i),
      kind: i.isEven
          ? WorkspaceEvidenceKind.image
          : WorkspaceEvidenceKind.note,
    ),
  );
}

Future<void> _openInspector(
  WidgetTester tester, {
  required List<WorkspaceEvidenceItem> items,
  required WorkspaceEvidenceItem selected,
  WorkspaceEvidenceController? controller,
}) async {
  final c = controller ??
      WorkspaceEvidenceController(
        initialState: WorkspaceEvidenceState(items: items),
      );
  final ordered = evidenceInspectorOrder(items);

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
                    evidence: selected,
                    controller: c,
                    orderedEvidence: ordered,
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
  testWidgets('A timeline tap opens Evidence Inspector', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(412, 915));

    final items = _nItems(2);
    final controller = WorkspaceEvidenceController(
      initialState: WorkspaceEvidenceState(items: items),
    );
    final incidentIdBefore = controller.currentIncident.id;
    final ordered = evidenceInspectorOrder(items);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: LiveEvidenceTimeline(
                items: ordered,
                onEvidenceTap: (item) {
                  showInvestigationEvidenceInspectorModal(
                    context: context,
                    evidence: item,
                    controller: controller,
                    orderedEvidence: ordered,
                  );
                },
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LiveEvidenceTimeline), findsOneWidget);
    await tester.tap(find.byKey(Key('live_timeline_item_${items.first.id}')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Evidence Inspector'), findsOneWidget);
    expect(find.byType(EvidenceSpatialCarousel), findsOneWidget);
    // B — incident id unchanged
    expect(controller.currentIncident.id, incidentIdBefore);
  });

  testWidgets('C initial evidence selected shows correct position',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(412, 915));

    final items = _nItems(3);
    await _openInspector(
      tester,
      items: items,
      selected: items[1],
    );

    expect(find.byKey(const Key('evidence_inspector_position')), findsOneWidget);
    expect(find.text('2 / 3'), findsOneWidget);
  });

  testWidgets('D one item inspector', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(412, 915));

    final items = _nItems(1);
    await _openInspector(tester, items: items, selected: items.first);

    expect(find.text('Evidence Inspector'), findsOneWidget);
    expect(find.text('1 / 1'), findsOneWidget);
    expect(find.byType(EvidenceSpatialCarousel), findsOneWidget);
    expect(find.byType(EvidenceInspectorPreview), findsOneWidget);
  });

  testWidgets('E two items inspector', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(412, 915));

    final items = _nItems(2);
    await _openInspector(tester, items: items, selected: items.first);

    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.byType(EvidenceSpatialCarousel), findsOneWidget);
  });

  testWidgets('F five items inspector', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(412, 915));

    final items = _nItems(5);
    await _openInspector(tester, items: items, selected: items[2]);

    expect(find.text('3 / 5'), findsOneWidget);
  });

  testWidgets('G H I carousel onSelected updates active evidence and preview',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(412, 915));

    final items = _nItems(5);
    await _openInspector(tester, items: items, selected: items.first);

    expect(find.text('1 / 5'), findsOneWidget);
    final previewBefore = tester
        .widget<EvidenceInspectorPreview>(find.byType(EvidenceInspectorPreview));
    expect(previewBefore.key, ValueKey(items.first.id));

    final carousel = tester.widget<EvidenceSpatialCarousel>(
      find.byType(EvidenceSpatialCarousel),
    );
    carousel.onSelected(3);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // H — position indicator updates
    expect(find.text('4 / 5'), findsOneWidget);

    // I — large preview key changes with active evidence
    final previewAfter = tester
        .widget<EvidenceInspectorPreview>(find.byType(EvidenceInspectorPreview));
    expect(previewAfter.key, ValueKey(items[3].id));
  });

  testWidgets('J close returns / pops inspector', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(412, 915));

    final items = _nItems(2);
    await _openInspector(tester, items: items, selected: items.first);

    expect(find.text('Evidence Inspector'), findsOneWidget);
    await tester.tap(find.text('Close').last);
    await tester.pumpAndSettle();
    expect(find.text('Evidence Inspector'), findsNothing);
  });

  testWidgets('K L evidence and incident IDs unchanged after browse',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(412, 915));

    final items = _nItems(3);
    final controller = WorkspaceEvidenceController(
      initialState: WorkspaceEvidenceState(items: items),
    );
    final incidentId = controller.currentIncident.id;
    final evidenceIds = controller.state.items.map((e) => e.id).toList();

    await _openInspector(
      tester,
      items: items,
      selected: items.first,
      controller: controller,
    );

    final carousel = tester.widget<EvidenceSpatialCarousel>(
      find.byType(EvidenceSpatialCarousel),
    );
    carousel.onSelected(2);
    await tester.pump();

    expect(controller.currentIncident.id, incidentId);
    expect(
      controller.state.items.map((e) => e.id).toList(),
      evidenceIds,
    );
  });

  test('M evidenceInspectorOrder is chronological ascending', () {
    final a = _item(id: 'late', at: DateTime(2026, 8, 12, 12));
    final b = _item(id: 'early', at: DateTime(2026, 8, 12, 9));
    final c = _item(id: 'mid', at: DateTime(2026, 8, 12, 10));
    final ordered = evidenceInspectorOrder([a, b, c]);
    expect(ordered.map((e) => e.id).toList(), ['early', 'mid', 'late']);
  });

  testWidgets('N missing thumbnail does not break inspector', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(412, 915));

    final item = _item(
      id: 'missing-thumb',
      kind: WorkspaceEvidenceKind.image,
      thumbnailPath: r'C:\does\not\exist\thumb.jpg',
      filePath: r'C:\does\not\exist\photo.jpg',
    );
    await _openInspector(tester, items: [item], selected: item);

    expect(tester.takeException(), isNull);
    expect(find.text('Evidence Inspector'), findsOneWidget);
    expect(find.byType(EvidenceInspectorPreview), findsOneWidget);
  });

  testWidgets('O P Q smoke: inspector does not invoke capture/file flows',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(412, 915));

    final items = _nItems(2);
    await _openInspector(tester, items: items, selected: items.first);

    // Lightweight smoke: inspector UI present; capture/file affordances absent.
    expect(find.text('Evidence Inspector'), findsOneWidget);
    expect(find.text('Capture Now'), findsNothing);
    expect(find.text('Attach File'), findsNothing);
    expect(find.text('Choose File'), findsNothing);
  });

  testWidgets('swipe changes active evidence and n / total', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(412, 915));

    final items = _nItems(5);
    await _openInspector(tester, items: items, selected: items.first);

    expect(find.text('1 / 5'), findsOneWidget);

    await tester.drag(
      find.byType(EvidenceSpatialCarousel),
      const Offset(-72, 0),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 280));
    await tester.pumpAndSettle();

    expect(find.text('2 / 5'), findsOneWidget);
    final preview = tester.widget<EvidenceInspectorPreview>(
      find.byType(EvidenceInspectorPreview),
    );
    expect(preview.key, ValueKey(items[1].id));
  });

  testWidgets('thumbnails remain visually distinct', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(412, 915));

    final items = _nItems(5);
    await _openInspector(tester, items: items, selected: items[2]);

    final visibleIds = items
        .map((item) => item.id)
        .where(
          (id) => find.byKey(Key('evidence_inspector_thumb_$id')).evaluate().isNotEmpty,
        )
        .toList();
    expect(visibleIds.length, greaterThanOrEqualTo(3));

    final rects = [
      for (final id in visibleIds)
        tester.getRect(find.byKey(Key('evidence_inspector_thumb_$id'))),
    ]..sort((a, b) => a.left.compareTo(b.left));

    for (var i = 0; i < rects.length - 1; i++) {
      expect(
        rects[i].right,
        lessThanOrEqualTo(rects[i + 1].left + 1),
        reason: 'thumbnail $i overlaps the next thumb',
      );
    }
  });

  testWidgets('close is the only bottom action and Save is absent',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(412, 915));

    final items = _nItems(2);
    await _openInspector(tester, items: items, selected: items.first);

    expect(find.text('Save'), findsNothing);
    expect(find.byKey(const Key('evidence_inspector_close')), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsNothing);
  });
}