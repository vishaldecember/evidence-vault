import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// Premium confirmation before discarding one floating Organize context.
Future<bool> showOrganizeContextDeleteDialog(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        key: const Key('organize_context_delete_dialog'),
        backgroundColor: AppColors.card,
        title: Text(
          'Delete the context?',
          style: AppTextStyles.heading.copyWith(fontSize: 18),
        ),
        actions: [
          TextButton(
            key: const Key('organize_context_delete_cancel'),
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'CANCEL',
              style: AppTextStyles.label.copyWith(color: AppColors.textMuted),
            ),
          ),
          TextButton(
            key: const Key('organize_context_delete_ok'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'OK',
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
  return confirmed == true;
}
