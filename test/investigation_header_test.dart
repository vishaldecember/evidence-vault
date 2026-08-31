import 'package:evidence_vault/models/journey_stage.dart';
import 'package:evidence_vault/services/narrative_validation_service.dart';
import 'package:evidence_vault/theme/app_colors.dart';
import 'package:evidence_vault/widgets/investigation/investigation_header.dart';
import 'package:evidence_vault/widgets/investigation/investigation_workspace_navigation_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

NarrativeReconstructionHealth _health({
  ReconstructionHealthStatus status = ReconstructionHealthStatus.incomplete,
}) {
  return NarrativeReconstructionHealth(
    status: status,
    label: status.label,
    coverageLabel: 'Supported by 0 of 0 events',
    supportedEventCount: 0,
    totalEventCount: 0,
  );
}

Widget _harness({
  String incidentName = '',
  JourneyStage journeyStage = JourneyStage.empty,
  int timelineAnchorCount = 1,
  int relationshipGroupCount = 2,
  int narrativeEventCount = 3,
  NarrativeReconstructionHealth? reconstructionHealth,
  ValueChanged<String>? onIncidentNameChanged,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: InvestigationHeader(
          incidentName: incidentName,
          journeyStage: journeyStage,
          timelineAnchorCount: timelineAnchorCount,
          relationshipGroupCount: relationshipGroupCount,
          narrativeEventCount: narrativeEventCount,
          reconstructionHealth: reconstructionHealth ?? _health(),
          onIncidentNameChanged: onIncidentNameChanged,
        ),
      ),
    ),
  );
}

Future<void> _enterTitleEdit(WidgetTester tester) async {
  await tester.tap(find.text(InvestigationHeader.untitledPlaceholder));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
}

void main() {
  group('InvestigationHeader', () {
    testWidgets('shows premium untitled case header with rename hint',
        (tester) async {
      await tester.pumpWidget(_harness(onIncidentNameChanged: (_) {}));

      expect(find.text('Untitled Incident'), findsOneWidget);
      expect(find.text('Tap to rename incident'), findsOneWidget);
      expect(find.byIcon(Icons.folder_outlined), findsOneWidget);
      expect(find.byType(TextField), findsNothing);

      final title = tester.widget<Text>(find.text('Untitled Incident'));
      final pageTitle = InvestigationWorkspaceNavigationHeader.titleStyle;
      expect(title.style?.fontSize, pageTitle.fontSize);
      expect(title.style?.fontWeight, pageTitle.fontWeight);
      expect(title.style?.color, InvestigationHeader.untitledTitleColor);
      expect(title.textAlign, TextAlign.center);

      expect(find.byType(ClipPath), findsWidgets);
      expect(find.byType(ColoredBox), findsWidgets);
      final field = tester.widget<ColoredBox>(
        find
            .descendant(
              of: find.byType(ClipPath).first,
              matching: find.byType(ColoredBox),
            )
            .first,
      );
      expect(field.color, AppColors.canvasAtmosphere);
      expect(find.byIcon(Icons.folder_outlined), findsOneWidget);
      final icon = tester.widget<Icon>(find.byIcon(Icons.folder_outlined));
      expect(icon.size, InvestigationHeader.titleIconSize);
    });

    testWidgets('tap transitions into edit mode and renames inline',
        (tester) async {
      var name = '';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return SingleChildScrollView(
                  child: InvestigationHeader(
                    incidentName: name,
                    journeyStage: JourneyStage.empty,
                    timelineAnchorCount: 1,
                    relationshipGroupCount: 2,
                    narrativeEventCount: 3,
                    reconstructionHealth: _health(),
                    onIncidentNameChanged: (value) {
                      setState(() => name = value);
                    },
                  ),
                );
              },
            ),
          ),
        ),
      );

      await _enterTitleEdit(tester);

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Tap to rename incident'), findsNothing);

      await tester.enterText(find.byType(TextField), 'Case Alpha');
      await tester.pump();

      expect(name, 'Case Alpha');
      expect(find.byType(AlertDialog), findsNothing);

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.byType(TextField), findsNothing);
      expect(find.text('Case Alpha'), findsOneWidget);
      expect(find.text('Tap to rename incident'), findsNothing);
    });

    testWidgets('named incident shows value without rename subtitle',
        (tester) async {
      await tester.pumpWidget(
        _harness(
          incidentName: 'Case Alpha',
          onIncidentNameChanged: (_) {},
        ),
      );

      expect(find.text('Case Alpha'), findsOneWidget);
      expect(find.text('Tap to rename incident'), findsNothing);
      expect(find.byIcon(Icons.folder_outlined), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('shows Incident Status once in the metrics grid',
        (tester) async {
      await tester.pumpWidget(_harness(journeyStage: JourneyStage.building));

      expect(find.text('Journey Status'), findsNothing);
      expect(find.text('Incident Status'), findsOneWidget);
      expect(find.text('BUILDING'), findsOneWidget);
      expect(find.text('Building'), findsNothing);
      expect(find.text('Relationship Groups'), findsOneWidget);
      expect(find.text('Primary Evidence'), findsOneWidget);
      expect(find.text('Narrative Events'), findsOneWidget);
    });

    testWidgets('maps status colours for EMPTY BUILDING RICH', (tester) async {
      expect(
        InvestigationHeader.statusColorFor(JourneyStage.empty),
        AppColors.strengthGood,
      );
      expect(
        InvestigationHeader.statusColorFor(JourneyStage.building),
        AppColors.warning,
      );
      expect(
        InvestigationHeader.statusColorFor(JourneyStage.rich),
        AppColors.success,
      );
    });

    testWidgets('shows Healthy for excellent reconstruction health',
        (tester) async {
      await tester.pumpWidget(
        _harness(
          journeyStage: JourneyStage.rich,
          reconstructionHealth: _health(
            status: ReconstructionHealthStatus.excellent,
          ),
        ),
      );

      expect(find.text('Reconstruction Health'), findsOneWidget);
      expect(find.text('READY'), findsWidgets);
      expect(find.text('Healthy'), findsNothing);
      expect(find.text('Excellent'), findsNothing);
    });

    testWidgets('metric titles stay muted while values use status colour',
        (tester) async {
      await tester.pumpWidget(_harness(journeyStage: JourneyStage.empty));

      final statusTitle = tester.widget<Text>(
        find.text('Primary Evidence'),
      );
      expect(statusTitle.style?.color, AppColors.textMuted);

      final value = tester.widget<Text>(find.text('1').first);
      expect(value.style?.color, AppColors.strengthGood);
    });
  });
}
