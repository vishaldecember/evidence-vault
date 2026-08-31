import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_text_styles.dart';

class TypedConfirmationDialog extends StatefulWidget {
  const TypedConfirmationDialog({
    super.key,
    required this.title,
    required this.body,
    required this.confirmationWord,
    required this.confirmLabel,
    this.busy = false,
  });

  final String title;
  final String body;
  final String confirmationWord;
  final String confirmLabel;
  final bool busy;

  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String body,
    required String confirmationWord,
    required String confirmLabel,
  }) async {
    final result = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: AppColors.navy.withValues(alpha: 0.28),
      transitionDuration: AppMotion.page,
      pageBuilder: (context, animation, secondaryAnimation) {
        return Center(
          child: TypedConfirmationDialog(
            title: title,
            body: body,
            confirmationWord: confirmationWord,
            confirmLabel: confirmLabel,
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: AppMotion.enter,
          reverseCurve: AppMotion.exit,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.98, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
    return result ?? false;
  }

  @override
  State<TypedConfirmationDialog> createState() =>
      _TypedConfirmationDialogState();
}

class _TypedConfirmationDialogState extends State<TypedConfirmationDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _canConfirm =>
      !widget.busy &&
      _controller.text.trim() == widget.confirmationWord;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      title: Text(widget.title, style: AppTextStyles.heading),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.body, style: AppTextStyles.bodySmall),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _controller,
              enabled: !widget.busy,
              decoration: InputDecoration(
                labelText: 'Type ${widget.confirmationWord} to confirm',
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: widget.busy ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel', style: AppTextStyles.link),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.danger,
            foregroundColor: AppColors.onPrimary,
          ),
          onPressed: _canConfirm
              ? () => Navigator.pop(context, true)
              : null,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
