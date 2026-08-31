import 'package:flutter/material.dart';

import '../../../constants/app_spacing.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../evidence_preview_renderer.dart';

/// Full text-note preview with inline editing and long-note scrolling.
class TextEvidenceRenderer extends EvidencePreviewRenderer {
  const TextEvidenceRenderer();

  @override
  Widget build(BuildContext context, EvidencePreviewContext preview) {
    return _TextNoteSurface(preview: preview);
  }
}

class _TextNoteSurface extends StatefulWidget {
  const _TextNoteSurface({required this.preview});

  final EvidencePreviewContext preview;

  @override
  State<_TextNoteSurface> createState() => _TextNoteSurfaceState();
}

class _TextNoteSurfaceState extends State<_TextNoteSurface> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.preview.record.evidence.notePreview ?? '',
    );
  }

  @override
  void didUpdateWidget(covariant _TextNoteSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.preview.record.evidence.notePreview ?? '';
    if (!_controller.selection.isValid && _controller.text != next) {
      _controller.text = next;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Text note',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Expanded(
              child: TextField(
                controller: _controller,
                expands: true,
                maxLines: null,
                minLines: null,
                textAlignVertical: TextAlignVertical.top,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                style: AppTextStyles.body.copyWith(
                  fontSize: 16,
                  height: 1.45,
                  color: AppColors.navy,
                ),
                decoration: InputDecoration(
                  hintText: 'Write the full note…',
                  hintStyle: AppTextStyles.body.copyWith(
                    color: AppColors.textMuted,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: widget.preview.onNoteBodyChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
