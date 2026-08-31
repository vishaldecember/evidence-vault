import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_text_styles.dart';

/// Compact orange reminder attached to the top edge of the Context card.
///
/// Mirrors [IncidentIdentityDrawer] animation, spacing, and palette.
class ContextReminderDrawer extends StatefulWidget {
  const ContextReminderDrawer({
    super.key,
    required this.isExpanded,
    required this.onToggle,
    this.animateEntry = false,
  });

  static const String reminderLabel = 'Add Context';

  static const double chevronEdgeInset = 18;
  static const double _headerHeight = 36;
  static const double _chevronSize = 40;
  static const double _chevronIconSize = 24;
  static const double _collapsedTabHeight = 30;

  final bool isExpanded;
  final VoidCallback onToggle;
  final bool animateEntry;

  @override
  State<ContextReminderDrawer> createState() => _ContextReminderDrawerState();
}

class _ContextReminderDrawerState extends State<ContextReminderDrawer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entryController;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: AppMotion.medium,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _entryController, curve: AppMotion.enter),
    );

    if (widget.animateEntry) {
      _entryController.forward();
    } else {
      _entryController.value = 1;
    }
  }

  @override
  void didUpdateWidget(ContextReminderDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animateEntry && !oldWidget.animateEntry) {
      _entryController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: SlideTransition(
        position: _slideAnimation,
        child: AnimatedSize(
          duration: AppMotion.medium,
          curve: AppMotion.enter,
          alignment: Alignment.topCenter,
          clipBehavior: Clip.hardEdge,
          child: widget.isExpanded
              ? _ExpandedReminderHeader(onCollapse: widget.onToggle)
              : _CollapsedReminderTab(onExpand: widget.onToggle),
        ),
      ),
    );
  }
}

class _CollapsedReminderTab extends StatelessWidget {
  const _CollapsedReminderTab({required this.onExpand});

  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.warning.withValues(alpha: 0.14),
      child: InkWell(
        onTap: onExpand,
        child: SizedBox(
          height: ContextReminderDrawer._collapsedTabHeight,
          child: Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.sm,
              right: ContextReminderDrawer.chevronEdgeInset,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.edit_note_outlined,
                  size: 15,
                  color: AppColors.warning.withValues(alpha: 0.95),
                ),
                const SizedBox(width: AppSpacing.xxs),
                Expanded(
                  child: Text(
                    ContextReminderDrawer.reminderLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.warning.withValues(alpha: 0.95),
                      height: 1,
                    ),
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_up_rounded,
                  size: ContextReminderDrawer._chevronIconSize,
                  color: AppColors.warning.withValues(alpha: 0.9),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ExpandedReminderHeader extends StatelessWidget {
  const _ExpandedReminderHeader({required this.onCollapse});

  final VoidCallback onCollapse;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted.withValues(alpha: 0.35),
        border: Border(
          bottom: BorderSide(
            color: AppColors.border.withValues(alpha: 0.55),
          ),
        ),
      ),
      child: SizedBox(
        height: ContextReminderDrawer._headerHeight,
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: Text(
                  ContextReminderDrawer.reminderLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.navy,
                    height: 1.1,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(
                right: ContextReminderDrawer.chevronEdgeInset,
              ),
              child: Semantics(
                button: true,
                label: 'Collapse context section',
                child: SizedBox(
                  width: ContextReminderDrawer._chevronSize,
                  height: ContextReminderDrawer._chevronSize,
                  child: IconButton(
                    onPressed: onCollapse,
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: ContextReminderDrawer._chevronIconSize,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
