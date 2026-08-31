import 'package:evidence_vault/models/library_incident_summary.dart';
import 'package:evidence_vault/widgets/home/library_incident_summary_tile.dart';
import 'package:evidence_vault/widgets/home/library_of_truth_section.dart';
import 'package:evidence_vault/widgets/home/library_preview_illustration.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const expectedTitles = [
    'Workplace Harassment',
    'Traffic Collision',
    'Wrong Item Delivered',
    'UPI Payment Disputed',
    'Ride Dispute',
    'Security Deposit Dispute',
    'Builder Promise vs Reality',
    'Service Complaint Unresolved',
    'Service vs What Was Promised',
    'Repeated Unwanted Contact',
  ];

  Future<void> pumpEmptyLibrary(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: LibraryOfTruthSection(
              incidents: [],
              onIncidentTap: _unusedTap,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('empty Library of Truth shows 10 frozen example cards in order',
      (tester) async {
    await pumpEmptyLibrary(tester);

    expect(find.byType(LibraryPreviewIllustration), findsOneWidget);
    expect(LibraryPreviewIllustration.previewIncidents, hasLength(10));
    expect(
      LibraryPreviewIllustration.previewIncidents.map((c) => c.title),
      expectedTitles,
    );

    for (final title in expectedTitles) {
      expect(find.text(title), findsOneWidget);
    }

    final orderedTops = [
      for (final incident in LibraryPreviewIllustration.previewIncidents)
        tester
            .getTopLeft(
              find.byKey(LibraryIncidentSummaryTile.cardKey(incident.id)),
            )
            .dy,
    ];
    for (var i = 1; i < orderedTops.length; i++) {
      expect(orderedTops[i], greaterThan(orderedTops[i - 1]));
    }
  });

  testWidgets('existing Workplace Harassment and Traffic Collision stay unchanged',
      (tester) async {
    await pumpEmptyLibrary(tester);

    final workplace = LibraryPreviewIllustration.previewIncidents[0];
    final traffic = LibraryPreviewIllustration.previewIncidents[1];

    expect(
      workplace,
      isA<LibraryIncidentSummary>()
          .having((c) => c.id, 'id', 'preview-workplace-harassment')
          .having((c) => c.title, 'title', 'Workplace Harassment')
          .having((c) => c.evidenceCount, 'evidenceCount', 12)
          .having((c) => c.contextEnrichedCount, 'contextEnrichedCount', 5)
          .having((c) => c.integrityVerified, 'integrityVerified', isTrue)
          .having((c) => c.lastPreserved, 'lastPreserved', 'Yesterday • 18:42'),
    );
    expect(
      traffic,
      isA<LibraryIncidentSummary>()
          .having((c) => c.id, 'id', 'preview-traffic-collision')
          .having((c) => c.title, 'title', 'Traffic Collision')
          .having((c) => c.evidenceCount, 'evidenceCount', 27)
          .having((c) => c.contextEnrichedCount, 'contextEnrichedCount', 8)
          .having((c) => c.integrityVerified, 'integrityVerified', isTrue)
          .having((c) => c.lastPreserved, 'lastPreserved', '2 days ago • 09:13'),
    );

    expect(find.text('Yesterday • 18:42'), findsOneWidget);
    expect(find.text('2 days ago • 09:13'), findsOneWidget);
    expect(find.textContaining('Evidence'), findsWidgets);
    expect(find.textContaining('12'), findsWidgets);
    expect(find.textContaining('27'), findsWidgets);
  });
}

void _unusedTap(String id) {}
