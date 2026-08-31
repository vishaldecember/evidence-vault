import 'package:evidence_vault/models/library_incident_summary.dart';
import 'package:evidence_vault/widgets/capture/cockpit_voice_visualizer.dart';
import 'package:evidence_vault/widgets/capture/voice_preview_panel.dart';
import 'package:evidence_vault/widgets/home/library_incident_summary_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Library tile shows Case readiness Good/Building (not Integrity Verified ✓)',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LibraryIncidentSummaryTile(
            incident: LibraryIncidentSummary(
              id: 'inc-1',
              title: 'Case A',
              evidenceCount: 2,
              contextEnrichedCount: 0,
              integrityVerified: true,
              lastPreserved: 'Just now',
              isInProgress: false,
              updatedAt: DateTime.utc(2026, 1, 1),
            ),
          ),
        ),
      ),
    );

    expect(find.textContaining('Case readiness'), findsOneWidget);
    expect(find.textContaining('Good'), findsOneWidget);
    expect(find.textContaining('Integrity Verified'), findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LibraryIncidentSummaryTile(
            incident: LibraryIncidentSummary(
              id: 'inc-2',
              title: 'Case B',
              evidenceCount: 1,
              contextEnrichedCount: 0,
              integrityVerified: false,
              lastPreserved: 'Yesterday',
              isInProgress: false,
              updatedAt: DateTime.utc(2026, 1, 1),
            ),
          ),
        ),
      ),
    );

    expect(find.textContaining('Building'), findsOneWidget);
  });

  testWidgets('CockpitVoiceVisualizer paints without throwing', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 280,
            height: 280,
            child: CockpitVoiceVisualizer(
              level: 0.55,
              active: true,
              idleMotion: false,
            ),
          ),
        ),
      ),
    );
    expect(find.byType(CockpitVoiceVisualizer), findsOneWidget);
  });

  testWidgets('VoicePreviewPanel uses translucent surface (not solid navy card)',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VoicePreviewPanel(
            levels: const [0.2, 0.4, 0.3],
            durationLabel: '0:12',
            isPlaying: false,
            onPlayPause: () {},
            onAccept: () {},
            onDiscard: () {},
          ),
        ),
      ),
    );

    final decorated = tester.widgetList<DecoratedBox>(find.byType(DecoratedBox));
    final surfaces = decorated
        .map((w) => w.decoration)
        .whereType<BoxDecoration>()
        .where((d) => d.borderRadius != null);
    expect(surfaces, isNotEmpty);
    final surface = surfaces.first;
    final color = surface.color!;
    expect(color.a, lessThan(1.0), reason: 'preview surface should be translucent');
  });
}
