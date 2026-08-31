import 'package:evidence_vault/models/investigation_workspace_tab.dart';
import 'package:evidence_vault/theme/app_colors.dart';
import 'package:evidence_vault/widgets/investigation/investigation_workspace_tab_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InvestigationWorkspaceTabBar', () {
    testWidgets('renders three equal segments with selected styling',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InvestigationWorkspaceTabBar(
              activeTab: InvestigationWorkspaceTab.connections,
              onTabSelected: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Timeline'), findsOneWidget);
      expect(find.text('Graph'), findsOneWidget);
      expect(find.text('Connections'), findsOneWidget);
      expect(find.text('Reconstruct'), findsOneWidget);
      expect(find.byType(Divider), findsOneWidget);
      final divider = tester.widget<Divider>(find.byType(Divider));
      expect(
        divider.color,
        InvestigationWorkspaceTabBar.dividerColor,
      );

      final selectedContainer = tester.widget<AnimatedContainer>(
        find.descendant(
          of: find.ancestor(
            of: find.text('Connections'),
            matching: find.byType(InkWell),
          ),
          matching: find.byType(AnimatedContainer),
        ),
      );
      final selectedDecoration =
          selectedContainer.decoration as BoxDecoration?;
      expect(selectedDecoration?.color, AppColors.primary);

      final selectedStyle = tester.widget<AnimatedDefaultTextStyle>(
        find.descendant(
          of: find.ancestor(
            of: find.text('Connections'),
            matching: find.byType(InkWell),
          ),
          matching: find.byType(AnimatedDefaultTextStyle),
        ),
      );
      expect(selectedStyle.style.color, AppColors.onPrimary);

      final unselectedStyle = tester.widget<AnimatedDefaultTextStyle>(
        find.descendant(
          of: find.ancestor(
            of: find.text('Timeline'),
            matching: find.byType(InkWell),
          ),
          matching: find.byType(AnimatedDefaultTextStyle),
        ),
      );
      expect(unselectedStyle.style.color, AppColors.textMuted);

      final widths = [
        for (final label in ['Timeline', 'Graph', 'Connections', 'Reconstruct'])
          tester
              .getSize(
                find.ancestor(
                  of: find.text(label),
                  matching: find.byType(InkWell),
                ),
              )
              .width,
      ];
      for (final width in widths.skip(1)) {
        expect(width, moreOrLessEquals(widths.first, epsilon: 0.5));
      }
    });

    testWidgets('invokes selection callback', (tester) async {
      InvestigationWorkspaceTab? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InvestigationWorkspaceTabBar(
              activeTab: InvestigationWorkspaceTab.timeline,
              onTabSelected: (tab) => selected = tab,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Reconstruct'));
      await tester.pump();

      expect(selected, InvestigationWorkspaceTab.reconstruction);
    });
  });
}
