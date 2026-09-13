import 'package:evidence_vault/constants/app_spacing.dart';
import 'package:evidence_vault/models/library_incident_summary.dart';
import 'package:evidence_vault/services/memory/deterministic_memory_recall_provider.dart';
import 'package:evidence_vault/services/memory/memory_recall_provider.dart';
import 'package:evidence_vault/widgets/vault/memory_recall_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

LibraryIncidentSummary _fixture() {
  return LibraryIncidentSummary(
    id: 'incident-a',
    title: 'Street Fight',
    evidenceCount: 3,
    contextEnrichedCount: 1,
    integrityVerified: false,
    lastPreserved: 'Today',
    isInProgress: true,
    isArchived: false,
    createdAt: DateTime.utc(2026, 8, 20),
    updatedAt: DateTime.utc(2026, 8, 21),
  );
}

void main() {
  const provider = DeterministicMemoryRecallProvider();

  Future<void> pumpRecall(
    WidgetTester tester, {
    required DateTime now,
  }) async {
    final items = await provider.load(
      MemoryRecallContext(incidents: [_fixture()], now: now),
    );
    final item = items.isEmpty ? null : items.first;
    debugPrint(
      'DIAG now=$now count=${items.length} '
      'type=${item?.type} '
      'action=${item?.actionLabel} '
      'headline=${item?.headline} '
      'reason=${item?.reason} '
      'age=${item?.ageLabel}',
    );

    final previousOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      debugPrint('DIAG FlutterError: ${details.exceptionAsString()}');
    };
    addTearDown(() => FlutterError.onError = previousOnError);

    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(412, 915));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenHorizontal,
              vertical: AppSpacing.lg,
            ),
            child: MemoryRecallSection(
              items: items,
              onAction: (_) {},
              onDismiss: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    debugPrint(
      'DIAG texts=${find.byType(Text).evaluate().map((e) {
        final w = e.widget;
        return w is Text ? w.data : null;
      }).whereType<String>().toList()}',
    );
    debugPrint('DIAG takeException=${tester.takeException()}');
  }

  testWidgets('green-baseline clock 2026-08-31', (tester) async {
    await pumpRecall(tester, now: DateTime.utc(2026, 8, 31, 23, 44, 42));
  });

  testWidgets('current clock 2026-09-06', (tester) async {
    await pumpRecall(tester, now: DateTime.utc(2026, 9, 6, 12));
  });

  testWidgets('inside 14-day window 2026-08-25', (tester) async {
    await pumpRecall(tester, now: DateTime.utc(2026, 8, 25, 12));
  });
}
