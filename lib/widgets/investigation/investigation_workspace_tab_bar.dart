import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../models/investigation_workspace_tab.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_text_styles.dart';
import '../common/layered_card.dart';

/// Tab navigation for the Investigation Workspace.
///
/// Visual segmented selector only — selection callback behaviour is unchanged.
/// On narrow widths, tabs wrap to two rows so labels are never clipped.
class InvestigationWorkspaceTabBar extends StatelessWidget {
  const InvestigationWorkspaceTabBar({
    super.key,
    required this.activeTab,
    required this.onTabSelected,
  });

  final InvestigationWorkspaceTab activeTab;
  final ValueChanged<InvestigationWorkspaceTab> onTabSelected;

  static const double _radius = 12;
  static const Color _unselectedText = AppColors.textMuted;

  /// Slightly richer divider — clear, not heavy.
  static const Color dividerColor = Color(0xFF8B95A8);

  /// Wrap Timeline/Graph/Connections/Reconstruction when too narrow for one row.
  static const double _wrapBelowWidth = 360;

  @override
  Widget build(BuildContext context) {
    final tabs = InvestigationWorkspaceTab.values;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Divider(
            height: 1,
            thickness: 1,
            color: dividerColor,
          ),
          const SizedBox(height: AppSpacing.xs),
          LayoutBuilder(
            builder: (context, constraints) {
              final wrap = constraints.maxWidth < _wrapBelowWidth;
              return LayeredCard(
                padding: EdgeInsets.zero,
                radius: _radius,
                clipBehavior: Clip.antiAlias,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(_radius - 0.5),
                  child: wrap
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    child: _Segment(
                                      label: tabs[0].label,
                                      selected: tabs[0] == activeTab,
                                      onTap: () => onTabSelected(tabs[0]),
                                      maxLines: 2,
                                    ),
                                  ),
                                  const VerticalDivider(
                                    width: 1,
                                    thickness: 1,
                                    color: dividerColor,
                                  ),
                                  Expanded(
                                    child: _Segment(
                                      label: tabs[1].label,
                                      selected: tabs[1] == activeTab,
                                      onTap: () => onTabSelected(tabs[1]),
                                      maxLines: 2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(
                              height: 1,
                              thickness: 1,
                              color: dividerColor,
                            ),
                            IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    child: _Segment(
                                      label: tabs[2].label,
                                      selected: tabs[2] == activeTab,
                                      onTap: () => onTabSelected(tabs[2]),
                                      maxLines: 2,
                                    ),
                                  ),
                                  const VerticalDivider(
                                    width: 1,
                                    thickness: 1,
                                    color: dividerColor,
                                  ),
                                  Expanded(
                                    child: _Segment(
                                      label: tabs[3].label,
                                      selected: tabs[3] == activeTab,
                                      onTap: () => onTabSelected(tabs[3]),
                                      maxLines: 2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (var index = 0; index < tabs.length; index++) ...[
                                if (index > 0)
                                  const VerticalDivider(
                                    width: 1,
                                    thickness: 1,
                                    color: dividerColor,
                                  ),
                                Expanded(
                                  child: _Segment(
                                    label: tabs[index].label,
                                    selected: tabs[index] == activeTab,
                                    onTap: () => onTabSelected(tabs[index]),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
    this.maxLines = 2,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: AnimatedContainer(
            duration: AppMotion.fast,
            curve: AppMotion.enter,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xxs,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : AppColors.background,
            ),
            child: AnimatedDefaultTextStyle(
              duration: AppMotion.fast,
              curve: AppMotion.enter,
              style: AppTextStyles.caption.copyWith(
                color: selected
                    ? AppColors.onPrimary
                    : InvestigationWorkspaceTabBar._unselectedText,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                fontSize: 12,
                height: 1.15,
              ),
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: maxLines,
                softWrap: true,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
