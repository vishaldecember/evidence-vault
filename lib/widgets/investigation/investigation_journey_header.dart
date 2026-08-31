import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../models/investigation_methodology_stage.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_text_styles.dart';

/// Persistent methodology orientation across Investigation Workspace surfaces.
///
/// Not onboarding — a calm workspace state indicator with tappable stage labels.
/// The four stages together represent the Incident Status lifecycle.
class InvestigationJourneyHeader extends StatelessWidget {
  const InvestigationJourneyHeader({
    super.key,
    required this.activeStage,
    required this.onStageSelected,
  });

  final InvestigationMethodologyStage activeStage;
  final ValueChanged<InvestigationMethodologyStage> onStageSelected;

  /// Target size when width allows — never exceeded, never scaled per label.
  static const double _preferredLabelFontSize = 13;

  static const double _minLabelFontSize = 11;

  /// Below this per-slot width, stages wrap onto two rows (no clipping).
  static const double _wrapBelowSlotWidth = 78;

  /// Fixed weight shared by every stage (selected and unselected).
  static const FontWeight _stageLabelFontWeight = FontWeight.w700;

  static const double _stageLabelHeight = 1.2;

  /// Equal gap between stage slots.
  static const double _stageSpacing = 4;

  static const Color _inactiveStageColor = AppColors.onCanvasSecondary;

  static Color tabFillFor(InvestigationMethodologyStage stage) =>
      switch (stage) {
        InvestigationMethodologyStage.capture => AppColors.journeyTabCapture,
        InvestigationMethodologyStage.evidence => AppColors.journeyTabOrganize,
        InvestigationMethodologyStage.investigation =>
          AppColors.journeyTabInvestigate,
        InvestigationMethodologyStage.trustPackage => AppColors.journeyTabTrust,
      };

  /// Single-line caption under the tabs — dark navy for readability.
  static final TextStyle _subtitleStyle = AppTextStyles.caption.copyWith(
    color: AppColors.navy,
    fontWeight: FontWeight.w400,
    fontSize: 12,
    height: 1.3,
    letterSpacing: -0.1,
  );

  /// One shared style for all four labels — only [color] varies by selection.
  static TextStyle stageLabelStyle({
    required Color color,
    required double fontSize,
  }) {
    return AppTextStyles.label.copyWith(
      fontSize: fontSize,
      fontWeight: _stageLabelFontWeight,
      color: color,
      letterSpacing: -0.15,
      height: _stageLabelHeight,
    );
  }

  /// Computes a single font size that fits every stage label in an equal slot.
  static double _sharedFontSizeForSlot(double slotWidth) {
    if (slotWidth <= 0) {
      return _minLabelFontSize;
    }

    var size = _preferredLabelFontSize;
    while (size > _minLabelFontSize) {
      final style = stageLabelStyle(
        color: _inactiveStageColor,
        fontSize: size,
      );
      var fits = true;
      for (final stage in InvestigationMethodologyStage.journeyOrder) {
        final painter = TextPainter(
          text: TextSpan(text: stage.label, style: style),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout(minWidth: 0, maxWidth: double.infinity);
        if (painter.width > slotWidth) {
          fits = false;
          break;
        }
      }
      if (fits) {
        return size;
      }
      size -= 0.5;
    }
    return _minLabelFontSize;
  }

  @override
  Widget build(BuildContext context) {
    final stages = InvestigationMethodologyStage.journeyOrder;
    final stageCount = stages.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final totalGaps = _stageSpacing * (stageCount - 1);
            final slotWidth =
                (constraints.maxWidth - totalGaps) / stageCount;
            final shouldWrap = slotWidth < _wrapBelowSlotWidth;
            final fontSize = shouldWrap
                ? _preferredLabelFontSize
                : _sharedFontSizeForSlot(slotWidth);

            if (shouldWrap) {
              final halfGap = _stageSpacing / 2;
              final cellWidth =
                  (constraints.maxWidth - _stageSpacing) / 2;
              return Wrap(
                spacing: _stageSpacing,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final stage in stages)
                    SizedBox(
                      width: cellWidth - halfGap + halfGap,
                      child: _StageLabel(
                        stage: stage,
                        isActive: stage == activeStage,
                        fontSize: fontSize,
                        allowWrap: true,
                        onTap: () => onStageSelected(stage),
                      ),
                    ),
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var index = 0; index < stageCount; index++) ...[
                  if (index > 0) const SizedBox(width: _stageSpacing),
                  Expanded(
                    child: _StageLabel(
                      stage: stages[index],
                      isActive: stages[index] == activeStage,
                      fontSize: fontSize,
                      allowWrap: false,
                      onTap: () => onStageSelected(stages[index]),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.xs),
        AnimatedSwitcher(
          duration: AppMotion.fast,
          switchInCurve: AppMotion.enter,
          switchOutCurve: AppMotion.enter,
          child: Text(
            activeStage.subtitle,
            key: ValueKey(activeStage),
            textAlign: TextAlign.center,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: _subtitleStyle,
          ),
        ),
      ],
    );
  }
}

class _StageLabel extends StatelessWidget {
  const _StageLabel({
    required this.stage,
    required this.isActive,
    required this.fontSize,
    required this.onTap,
    this.allowWrap = false,
  });

  final InvestigationMethodologyStage stage;
  final bool isActive;
  final double fontSize;
  final VoidCallback onTap;
  final bool allowWrap;

  @override
  Widget build(BuildContext context) {
    final color = isActive
        ? AppColors.onCanvas
        : InvestigationJourneyHeader._inactiveStageColor;
    final fill = InvestigationJourneyHeader.tabFillFor(stage);

    return Semantics(
      button: true,
      selected: isActive,
      label: stage.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.xs),
          splashColor: AppColors.onCanvas.withValues(alpha: 0.06),
          highlightColor: AppColors.onCanvas.withValues(alpha: 0.03),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(AppSpacing.xs),
              border: Border.all(
                color: isActive
                    ? AppColors.onCanvas.withValues(alpha: 0.28)
                    : fill,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.xxs,
                horizontal: 2,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AnimatedDefaultTextStyle(
                    duration: AppMotion.fast,
                    curve: AppMotion.enter,
                    style: InvestigationJourneyHeader.stageLabelStyle(
                      color: color,
                      fontSize: fontSize,
                    ),
                    textAlign: TextAlign.center,
                    child: Text(
                      stage.label,
                      textAlign: TextAlign.center,
                      maxLines: allowWrap ? 2 : 1,
                      softWrap: allowWrap,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  AnimatedContainer(
                    duration: AppMotion.fast,
                    curve: AppMotion.enter,
                    height: 2,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: isActive ? AppColors.onCanvas : Colors.transparent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
