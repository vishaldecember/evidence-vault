import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../models/reflection_model.dart';
import '../../theme/app_button_styles.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../common/app_bottom_sheet.dart';

/// Add or edit a personal reflection — never auto-generated.
Future<void> showReflectionEditorSheet({
  required BuildContext context,
  ReflectionModel? existing,
  required void Function({String? title, required String body}) onSave,
}) {
  return showAppBottomSheet<void>(
    context: context,
    builder: (context) {
      return ReflectionEditorSheet(
        existing: existing,
        onSave: (title, body) {
          Navigator.pop(context);
          onSave(title: title, body: body);
        },
      );
    },
  );
}

class ReflectionEditorSheet extends StatefulWidget {
  const ReflectionEditorSheet({
    super.key,
    this.existing,
    required this.onSave,
  });

  final ReflectionModel? existing;
  final void Function(String? title, String body) onSave;

  @override
  State<ReflectionEditorSheet> createState() => _ReflectionEditorSheetState();
}

class _ReflectionEditorSheetState extends State<ReflectionEditorSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.existing?.title);
    _bodyController = TextEditingController(text: widget.existing?.body);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _handleSave() {
    final body = _bodyController.text.trim();
    if (body.isEmpty) {
      return;
    }

    final title = _titleController.text.trim();
    widget.onSave(title.isEmpty ? null : title, body);
  }

  @override
  Widget build(BuildContext context) {
    final canSave = _bodyController.text.trim().isNotEmpty;

    return BottomSheetInsets(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BottomSheetHeader(
            title: _isEditing ? 'Edit Reflection' : 'Add Reflection',
            caption: ReflectionPrompts.canonical,
          ),
          const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Title (optional)',
                labelStyle: AppTextStyles.caption,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
              ),
              style: AppTextStyles.label,
              textInputAction: TextInputAction.next,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _bodyController,
              decoration: InputDecoration(
                labelText: 'Reflection',
                alignLabelWithHint: true,
                labelStyle: AppTextStyles.caption,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
                ),
                contentPadding: const EdgeInsets.all(AppSpacing.md),
              ),
              style: AppTextStyles.bodySmall.copyWith(height: 1.5),
              minLines: 4,
              maxLines: 8,
              textInputAction: TextInputAction.newline,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              height: AppSpacing.buttonHeight,
              child: ElevatedButton(
                onPressed: canSave ? _handleSave : null,
                style: AppButtonStyles.primary.copyWith(
                  backgroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.disabled)) {
                      return AppColors.primary.withValues(alpha: 0.4);
                    }
                    return AppColors.primary;
                  }),
                ),
                child: Text(
                  _isEditing ? 'Save Reflection' : 'Add Reflection',
                  style: AppTextStyles.button,
                ),
              ),
            ),
          ],
        ),
    );
  }
}
