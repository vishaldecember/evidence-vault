import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// Explains why Archive is blocked until the incident has a real title.
Future<bool> showArchiveTitleRequiredDialog(BuildContext context) async {
  final addTitle = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        key: const Key('archive_title_required_dialog'),
        backgroundColor: AppColors.card,
        title: Text(
          'Name this incident before archiving',
          style: AppTextStyles.heading.copyWith(fontSize: 18),
        ),
        content: Text(
          'Give this incident a title so you can easily recognize it later.',
          style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Not now',
              style: AppTextStyles.label.copyWith(color: AppColors.textMuted),
            ),
          ),
          TextButton(
            key: const Key('archive_add_title_action'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Add title',
              style: AppTextStyles.label.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      );
    },
  );
  return addTitle == true;
}
