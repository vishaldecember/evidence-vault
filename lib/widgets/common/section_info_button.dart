import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// Compact heading ⓘ that opens a premium, dismiss-on-outside flyout.
class SectionInfoButton extends StatelessWidget {
  const SectionInfoButton({
    super.key,
    required this.title,
    required this.items,
    this.iconColor = AppColors.onCanvasSecondary,
  });

  static const investigateItems = [
    'Suggested Connections',
    'Relationship analysis',
    'Evidence relationships',
    'Timeline / Story',
    'Patterns',
    'Matter investigation',
  ];

  static const organizeItems = [
    'Create Group',
    'Add/remove evidence from a group',
    'Rename group',
    'Tags/categories',
    'Archive',
    'Organize evidence',
  ];

  final String title;
  final List<String> items;
  final Color iconColor;

  static const IconData icon = Icons.info_outline_rounded;

  Future<void> _open(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    final overlay = Overlay.maybeOf(context)?.context.findRenderObject();
    if (box == null || overlay is! RenderBox) {
      return;
    }
    final offset = box.localToGlobal(Offset.zero, ancestor: overlay);
    final size = box.size;
    await showMenu<void>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy + size.height,
        overlay.size.width - offset.dx - size.width,
        overlay.size.height - offset.dy - size.height,
      ),
      color: AppColors.card,
      elevation: 10,
      shadowColor: const Color(0x33071426),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
        side: BorderSide(
          color: AppColors.borderAccent.withValues(alpha: 0.55),
        ),
      ),
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 280),
      items: [
        PopupMenuItem<void>(
          enabled: false,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: _SectionInfoFlyoutBody(title: title, items: items),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: IconButton(
        onPressed: () => _open(context),
        tooltip: '$title information',
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        icon: _StylishInfoMark(color: iconColor),
      ),
    );
  }
}

/// Curvy lowercase "i" in a circle — premium information mark.
class _StylishInfoMark extends StatelessWidget {
  const _StylishInfoMark({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 1.35),
        ),
        child: Center(
          child: Text(
            'i',
            style: TextStyle(
              fontSize: 12.5,
              height: 1,
              fontWeight: FontWeight.w500,
              fontStyle: FontStyle.italic,
              fontFamily: 'Georgia',
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionInfoFlyoutBody extends StatelessWidget {
  const _SectionInfoFlyoutBody({
    required this.title,
    required this.items,
  });

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: AppTextStyles.label.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.navy,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: 4),
          Text(
            items[i],
            style: AppTextStyles.bodySmall.copyWith(
              fontWeight: FontWeight.w400,
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
        ],
      ],
    );
  }
}
