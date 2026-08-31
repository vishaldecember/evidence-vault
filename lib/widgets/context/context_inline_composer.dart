import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../presentation/evidence_inspector_semantics.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// Inline context entry — focused immediately after the Add Context reminder.
class ContextInlineComposer extends StatefulWidget {
  const ContextInlineComposer({
    super.key,
    required this.focusNode,
    required this.onSubmit,
    this.autofocus = false,
    this.minLines = 3,
    this.maxLines = 4,
  });

  static const String hintText =
      EvidenceInspectorSemantics.observationComposerHint;

  final FocusNode focusNode;
  final ValueChanged<String> onSubmit;
  final bool autofocus;
  final int minLines;
  final int maxLines;

  @override
  State<ContextInlineComposer> createState() => _ContextInlineComposerState();
}

class _ContextInlineComposerState extends State<ContextInlineComposer> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      return;
    }
    widget.onSubmit(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      maxLines: widget.maxLines,
      minLines: widget.minLines,
      textCapitalization: TextCapitalization.sentences,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _submit(),
      style: AppTextStyles.bodySmall.copyWith(height: 1.5),
      decoration: InputDecoration(
        hintText: ContextInlineComposer.hintText,
        hintStyle: AppTextStyles.bodySmall.copyWith(
          color: AppColors.textMuted,
          height: 1.5,
        ),
        filled: true,
        fillColor: AppColors.surfaceMuted.withValues(alpha: 0.35),
        contentPadding: const EdgeInsets.all(AppSpacing.sm),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.sm),
          borderSide: BorderSide(
            color: AppColors.border.withValues(alpha: 0.55),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.sm),
          borderSide: BorderSide(
            color: AppColors.border.withValues(alpha: 0.55),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.sm),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      ),
    );
  }
}
