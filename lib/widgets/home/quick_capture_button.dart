import 'package:flutter/material.dart';

import '../../models/workspace_capture_mode.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_text_styles.dart';
import '../common/capture_mode_icon.dart';

enum QuickCaptureType {
  photo,
  video,
  voice,
  note,
  attachment;

  String get label => switch (this) {
    QuickCaptureType.photo => 'Photo',
    QuickCaptureType.video => 'Video',
    QuickCaptureType.voice => 'Voice',
    QuickCaptureType.note => 'Note',
    QuickCaptureType.attachment => 'File',
  };

  /// Screen reader label for capture actions.
  String get semanticLabel => switch (this) {
    QuickCaptureType.photo => 'Capture photo evidence',
    QuickCaptureType.video => 'Capture video evidence',
    QuickCaptureType.voice => 'Record voice evidence',
    QuickCaptureType.note => 'Add written note',
    QuickCaptureType.attachment => 'Attach file',
  };

  IconData get icon => switch (this) {
    QuickCaptureType.photo => Icons.photo_camera_outlined,
    QuickCaptureType.video => Icons.videocam_outlined,
    QuickCaptureType.voice => Icons.mic_outlined,
    QuickCaptureType.note => Icons.edit_note_outlined,
    QuickCaptureType.attachment => Icons.attach_file_outlined,
  };
}

extension QuickCaptureTypeWorkspace on QuickCaptureType {
  WorkspaceCaptureMode get workspaceMode => switch (this) {
    QuickCaptureType.photo => WorkspaceCaptureMode.photo,
    QuickCaptureType.video => WorkspaceCaptureMode.video,
    QuickCaptureType.voice => WorkspaceCaptureMode.voice,
    QuickCaptureType.note => WorkspaceCaptureMode.note,
    QuickCaptureType.attachment => WorkspaceCaptureMode.file,
  };
}

class QuickCaptureButton extends StatefulWidget {
  const QuickCaptureButton({
    super.key,
    required this.type,
    required this.onTap,
  });

  final QuickCaptureType type;
  final VoidCallback onTap;

  @override
  State<QuickCaptureButton> createState() => _QuickCaptureButtonState();
}

class _QuickCaptureButtonState extends State<QuickCaptureButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.type.semanticLabel,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isPressed ? AppMotion.pressScale : 1,
          duration: AppMotion.fast,
          curve: AppMotion.enter,
          child: AnimatedContainer(
            duration: AppMotion.fast,
            width: double.infinity,
            height: double.infinity,
            decoration: AppDecorations.captureTile(pressed: _isPressed),
            padding: const EdgeInsets.only(top: 4),
            child: ExcludeSemantics(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  PinnedCaptureModeIcon(
                    mode: widget.type.workspaceMode,
                    size: CaptureModeIconMetrics.captureNow,
                    layoutSize: CaptureModeIconMetrics.captureNowLayout,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.type.label,
                    style: AppTextStyles.label.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.navy,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    softWrap: true,
                    overflow: TextOverflow.visible,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
