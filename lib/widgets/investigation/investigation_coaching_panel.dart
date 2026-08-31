import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../controllers/investigation_coaching_controller.dart';
import '../../models/investigation_coaching_item.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../common/section_info_button.dart';
import 'investigation_coach_pocket.dart';
import 'investigation_coaching_card.dart';

/// Persistent Investigation Coach panel for the Investigation Workspace.
///
/// Vertically constrained so coaching never overflows the workspace column;
/// cards scroll horizontally within a capped height.
class InvestigationCoachingPanel extends StatelessWidget {
  const InvestigationCoachingPanel({
    super.key,
    required this.controller,
    required this.onReview,
    this.pocketKey,
  });

  final InvestigationCoachingController controller;
  final void Function(InvestigationCoachingItem item) onReview;
  final GlobalKey? pocketKey;

  /// Wise-advisor mark — mentor / strategist, not a gendered figure.
  static const IconData mentorIcon = Icons.psychology_outlined;

  /// Shared premium golden-brown for title and mentor icon.
  static const Color mentorAccent = Color(0xFFB8893D);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final items = controller.visibleItems;
        if (items.isEmpty) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.only(
            top: AppSpacing.lg,
            bottom: AppSpacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    mentorIcon,
                    size: 22,
                    color: mentorAccent,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Flexible(
                    child: Text(
                      'Investigation Coach',
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      softWrap: true,
                      style: AppTextStyles.label.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: mentorAccent,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  SectionInfoButton(
                    title: 'Investigate',
                    items: SectionInfoButton.investigateItems,
                    iconColor: mentorAccent,
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'Evidence-based guidance to strengthen your documentation.',
                textAlign: TextAlign.center,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.onCanvasSecondary,
                  height: 1.35,
                ),
                maxLines: 3,
                softWrap: true,
              ),
              const SizedBox(height: AppSpacing.sm),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var index = 0; index < items.length; index++) ...[
                      if (index > 0) const SizedBox(width: AppSpacing.sm),
                      Builder(
                        builder: (cardContext) {
                          return InvestigationCoachingCard(
                            item: items[index],
                            onReview: () => onReview(items[index]),
                            onDismiss: () {
                              final pocketContext = pocketKey?.currentContext;
                              if (pocketContext != null) {
                                InvestigationCoachPocket.flyToPocket(
                                  fromContext: cardContext,
                                  pocketContext: pocketContext,
                                  onArrived: () => controller.dismiss(
                                    items[index].fingerprint,
                                  ),
                                );
                              } else {
                                controller.dismiss(items[index].fingerprint);
                              }
                            },
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
