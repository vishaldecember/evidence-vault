import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_text_styles.dart';

/// Consistent modal bottom sheet presentation across Evidence Vault.
Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  bool useRootNavigator = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useRootNavigator: useRootNavigator,
    useSafeArea: true,
    enableDrag: true,
    backgroundColor: AppColors.background,
    barrierColor: AppColors.navy.withValues(alpha: 0.28),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppSpacing.cardRadius),
      ),
    ),
    sheetAnimationStyle: AnimationStyle(
      duration: AppMotion.sheet,
      reverseDuration: AppMotion.sheet,
      curve: AppMotion.enter,
      reverseCurve: AppMotion.exit,
    ),
    builder: builder,
  );
}

/// Drag handle shown at the top of modal sheets.
class BottomSheetHandle extends StatelessWidget {
  const BottomSheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.border,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

/// Standard sheet header with optional caption.
class BottomSheetHeader extends StatelessWidget {
  const BottomSheetHeader({
    super.key,
    required this.title,
    this.caption,
  });

  final String title;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const BottomSheetHandle(),
        const SizedBox(height: AppSpacing.md),
        Text(title, style: AppTextStyles.heading),
        if (caption != null) ...[
          const SizedBox(height: AppSpacing.xxs),
          Text(
            caption!,
            style: AppTextStyles.caption.copyWith(height: 1.5),
          ),
        ],
      ],
    );
  }
}

/// Applies keyboard inset padding for scroll-controlled sheets.
class BottomSheetInsets extends StatelessWidget {
  const BottomSheetInsets({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.lg,
      AppSpacing.sm,
      AppSpacing.lg,
      AppSpacing.lg,
    ),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return AnimatedPadding(
      duration: AppMotion.medium,
      curve: AppMotion.enter,
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: Padding(
        padding: padding.copyWith(
          bottom: padding.bottom + bottomInset,
        ),
        child: child,
      ),
    );
  }
}
