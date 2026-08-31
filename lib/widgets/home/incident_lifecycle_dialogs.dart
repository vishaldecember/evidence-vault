import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// Confirmation before moving an incident to Deleted (30-day retention).
Future<bool> showDeleteIncidentDialog(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        key: const Key('delete_incident_dialog'),
        backgroundColor: AppColors.card,
        title: Text(
          'Delete this incident?',
          style: AppTextStyles.heading.copyWith(fontSize: 18),
        ),
        content: Text(
          'This incident will move to Deleted and be permanently removed after 30 days.',
          style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            key: const Key('delete_incident_cancel'),
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: AppTextStyles.label.copyWith(color: AppColors.textMuted),
            ),
          ),
          TextButton(
            key: const Key('delete_incident_confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Delete',
              style: AppTextStyles.label.copyWith(
                color: AppColors.danger,
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

/// Confirmation before permanently destroying a Deleted incident.
Future<bool> showPermanentlyDeleteIncidentDialog(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        key: const Key('permanently_delete_incident_dialog'),
        backgroundColor: AppColors.card,
        title: Text(
          'Permanently delete this incident?',
          style: AppTextStyles.heading.copyWith(fontSize: 18),
        ),
        content: Text(
          'This will permanently remove the incident and its associated data. This action cannot be undone.',
          style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            key: const Key('permanently_delete_incident_cancel'),
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: AppTextStyles.label.copyWith(color: AppColors.textMuted),
            ),
          ),
          TextButton(
            key: const Key('permanently_delete_incident_confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Delete permanently',
              style: AppTextStyles.label.copyWith(
                color: AppColors.danger,
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

/// Compact rename field for the incident-level More menu.
Future<String?> showRenameIncidentDialog(
  BuildContext context, {
  required String currentTitle,
}) async {
  final controller = TextEditingController(text: currentTitle);
  final renamed = await showDialog<String>(
    context: context,
    builder: (context) {
      return AlertDialog(
        key: const Key('rename_incident_dialog'),
        backgroundColor: AppColors.card,
        title: Text(
          'Rename incident',
          style: AppTextStyles.heading.copyWith(fontSize: 18),
        ),
        content: TextField(
          key: const Key('rename_incident_field'),
          controller: controller,
          autofocus: true,
          style: AppTextStyles.body.copyWith(color: AppColors.navy),
          decoration: const InputDecoration(isDense: true),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            key: const Key('rename_incident_cancel'),
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: AppTextStyles.label.copyWith(color: AppColors.textMuted),
            ),
          ),
          TextButton(
            key: const Key('rename_incident_save'),
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(
              'Save',
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
  controller.dispose();
  final trimmed = renamed?.trim() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}
