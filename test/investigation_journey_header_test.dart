import 'package:evidence_vault/controllers/workspace_evidence_controller.dart';
import 'package:evidence_vault/models/evidence_relationship.dart';
import 'package:evidence_vault/models/investigation_methodology_stage.dart';
import 'package:evidence_vault/models/investigation_workspace_tab.dart';
import 'package:evidence_vault/models/verification_factory.dart';
import 'package:evidence_vault/models/workspace_evidence_item.dart';
import 'package:evidence_vault/screens/evidence_workspace_screen.dart';
import 'package:evidence_vault/theme/app_colors.dart';
import 'package:evidence_vault/widgets/investigation/investigation_journey_header.dart';
import 'package:evidence_vault/widgets/investigation/investigation_stage_header.dart';
import 'package:evidence_vault/widgets/investigation/investigation_workspace_tab_bar.dart';
import 'package:evidence_vault/screens/incident_workspace_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

WorkspaceEvidenceItem _item({required String id}) {
  return WorkspaceEvidenceItem(
    id: id,
    kind: WorkspaceEvidenceKind.image,
    title: 'Evidence $id',
    lastPreservedAt: DateTime(2026, 7, 28),
    integrityVerified: true,
    verification: VerificationFactory.initial(),
  );
}

void main() {
  group('InvestigationJourneyHeader', () {
    testWidgets('shows four methodology stages', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InvestigationJourneyHeader(
              activeStage: InvestigationMethodologyStage.capture,
              onStageSelected: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Capture'), findsOneWidget);
      expect(find.text('Organize'), findsOneWidget);
      expect(find.text('Investigate'), findsOneWidget);
      expect(find.text('Trust Package'), findsOneWidget);
    });

    testWidgets('shows only active stage subtitle', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InvestigationJourneyHeader(
              activeStage: InvestigationMethodologyStage.investigation,
              onStageSelected: (_) {},
            ),
          ),
        ),
      );

      expect(
        find.text('Understand chronology and relationships'),
        findsOneWidget,
      );
      expect(find.text('Capture what happened clearly'), findsNothing);
      expect(find.text('Organize and enrich your records'), findsNothing);
      expect(
        find.text('Generate a professional evidence package'),
        findsNothing,
      );
    });

    testWidgets('does not render completion indicators', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InvestigationJourneyHeader(
              activeStage: InvestigationMethodologyStage.evidence,
              onStageSelected: (_) {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.check), findsNothing);
      expect(find.byIcon(Icons.check_circle), findsNothing);
      expect(find.textContaining('%'), findsNothing);
    });

    testWidgets('highlights active stage in platform accent blue', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InvestigationJourneyHeader(
              activeStage: InvestigationMethodologyStage.trustPackage,
              onStageSelected: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final activeInkWell = find.ancestor(
        of: find.text('Trust Package'),
        matching: find.byType(InkWell),
      );
      final activeUnderline = find.descendant(
        of: activeInkWell,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is AnimatedContainer &&
              widget.decoration is BoxDecoration &&
              (widget.decoration! as BoxDecoration).color == AppColors.onCanvas,
        ),
      );
      expect(activeUnderline, findsOneWidget);

      final inactiveInkWell = find.ancestor(
        of: find.text('Capture'),
        matching: find.byType(InkWell),
      );
      final inactiveUnderline = find.descendant(
        of: inactiveInkWell,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is AnimatedContainer &&
              widget.decoration is BoxDecoration &&
              (widget.decoration! as BoxDecoration).color == AppColors.onCanvas,
        ),
      );
      expect(inactiveUnderline, findsNothing);
    });

    testWidgets('stage labels stay on a single line', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InvestigationJourneyHeader(
              activeStage: InvestigationMethodologyStage.capture,
              onStageSelected: (_) {},
            ),
          ),
        ),
      );

      for (final stage in InvestigationMethodologyStage.journeyOrder) {
        final text = tester.widget<Text>(find.text(stage.label));
        expect(text.maxLines, 1);
        expect(text.softWrap, isFalse);
      }
    });

    testWidgets('stage slots occupy equal horizontal width', (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(390, 844));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: InvestigationJourneyHeader(
                activeStage: InvestigationMethodologyStage.investigation,
                onStageSelected: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final widths = InvestigationMethodologyStage.journeyOrder
          .map(
            (stage) => tester
                .getSize(
                  find.ancestor(
                    of: find.text(stage.label),
                    matching: find.byType(InkWell),
                  ),
                )
                .width,
          )
          .toList(growable: false);

      expect(widths, hasLength(4));
      for (final width in widths.skip(1)) {
        expect(width, moreOrLessEquals(widths.first, epsilon: 0.5));
      }
    });

    testWidgets('stage labels use identical typography for all tabs',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InvestigationJourneyHeader(
              activeStage: InvestigationMethodologyStage.capture,
              onStageSelected: (_) {},
            ),
          ),
        ),
      );

      final styles = <TextStyle>[];
      for (final stage in InvestigationMethodologyStage.journeyOrder) {
        final inkWell = find.ancestor(
          of: find.text(stage.label),
          matching: find.byType(InkWell),
        );
        final style = tester.widget<AnimatedDefaultTextStyle>(
          find.descendant(
            of: inkWell,
            matching: find.byType(AnimatedDefaultTextStyle),
          ),
        );
        styles.add(style.style);
      }

      final sharedSize = styles.first.fontSize;
      final sharedWeight = styles.first.fontWeight;
      final sharedHeight = styles.first.height;
      expect(sharedSize, isNotNull);
      expect(find.byType(FittedBox), findsNothing);

      for (final style in styles) {
        expect(style.fontSize, sharedSize);
        expect(style.fontWeight, sharedWeight);
        expect(style.height, sharedHeight);
      }

      expect(styles[0].color, AppColors.onCanvas);
      expect(styles[1].color, AppColors.onCanvasSecondary);
      expect(styles[2].color, AppColors.onCanvasSecondary);
      expect(styles[3].color, AppColors.onCanvasSecondary);
    });

    testWidgets('subtitle is a single-line dark navy caption', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InvestigationJourneyHeader(
              activeStage: InvestigationMethodologyStage.evidence,
              onStageSelected: (_) {},
            ),
          ),
        ),
      );

      final subtitle = tester.widget<Text>(
        find.text('Organize and enrich your records'),
      );
      expect(subtitle.maxLines, 1);
      expect(subtitle.style?.fontSize, 12);
      expect(subtitle.style?.fontWeight, FontWeight.w400);
      expect(subtitle.style?.color, AppColors.navy);
    });

    testWidgets('all stage subtitles share copy style and typography',
        (tester) async {
      for (final stage in InvestigationMethodologyStage.journeyOrder) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: InvestigationJourneyHeader(
                activeStage: stage,
                onStageSelected: (_) {},
              ),
            ),
          ),
        );

        final subtitle = tester.widget<Text>(find.text(stage.subtitle));
        expect(stage.subtitle.contains('.'), isFalse);
        expect(subtitle.maxLines, 1);
        expect(subtitle.softWrap, isFalse);
        expect(subtitle.textAlign, TextAlign.center);
        expect(subtitle.style?.fontSize, 12);
        expect(subtitle.style?.fontWeight, FontWeight.w400);
        expect(subtitle.style?.height, 1.3);
        expect(subtitle.style?.color, AppColors.navy);
      }

      expect(
        InvestigationMethodologyStage.capture.subtitle,
        'Capture what happened clearly',
      );
      expect(
        InvestigationMethodologyStage.evidence.subtitle,
        'Organize and enrich your records',
      );
      expect(
        InvestigationMethodologyStage.investigation.subtitle,
        'Understand chronology and relationships',
      );
      expect(
        InvestigationMethodologyStage.trustPackage.subtitle,
        'Generate a professional evidence package',
      );
    });

    testWidgets('invokes stage selection callback', (tester) async {
      InvestigationMethodologyStage? selected;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InvestigationJourneyHeader(
              activeStage: InvestigationMethodologyStage.capture,
              onStageSelected: (stage) => selected = stage,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Investigate'));
      await tester.pump();

      expect(selected, InvestigationMethodologyStage.investigation);
    });
  });

  group('InvestigationStageHeader', () {
    testWidgets('shows investigation workspace title', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: InvestigationStageHeader(),
          ),
        ),
      );

      expect(find.text('Investigation Workspace'), findsOneWidget);
    });
  });

  group('Workspace integration', () {
    testWidgets('Evidence Workspace shows Capture as active stage', (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(412, 915));

      final controller = WorkspaceEvidenceController(
        initialState: WorkspaceEvidenceState(items: [_item(id: 'photo')]),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: EvidenceWorkspaceScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(InvestigationJourneyHeader), findsOneWidget);
      expect(find.text('Capture what happened clearly'), findsOneWidget);
    });

    testWidgets('Investigation stage shows tabs only under Investigation',
        (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(412, 915));

      final controller = WorkspaceEvidenceController(
        initialState: WorkspaceEvidenceState(
          items: [_item(id: 'photo'), _item(id: 'video')],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: IncidentWorkspaceShell(
            controller: controller,
            initialStage: InvestigationMethodologyStage.investigation,
            initialInvestigationTab: InvestigationWorkspaceTab.connections,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(InvestigationJourneyHeader), findsOneWidget);
      expect(find.text('Understand chronology and relationships'), findsOneWidget);
      expect(find.byType(InvestigationWorkspaceTabBar), findsOneWidget);
    });
  });
}
