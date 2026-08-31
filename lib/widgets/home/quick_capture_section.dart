import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../common/layered_card.dart';
import '../common/modern_art_material.dart';
import 'quick_capture_button.dart';

class QuickCaptureSection extends StatelessWidget {
  const QuickCaptureSection({super.key, required this.onCaptureTap});

  final ValueChanged<QuickCaptureType> onCaptureTap;

  static const _topRow = [
    QuickCaptureType.photo,
    QuickCaptureType.video,
    QuickCaptureType.voice,
  ];

  static const _bottomRow = [
    QuickCaptureType.note,
    QuickCaptureType.attachment,
  ];

  static const _buttonHeight = 77.5;

  @override
  Widget build(BuildContext context) {
    return LayeredCard(
      elevated: true,
      padding: const EdgeInsets.all(AppSpacing.sm),
      atmosphere: const ChromeAtmosphereSurface(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Capture Now',
            style: AppTextStyles.heading.copyWith(letterSpacing: -0.4),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Something happened? Don’t wait, capture it',
            style: AppTextStyles.bodySmall.copyWith(height: 1.45),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              for (var index = 0; index < _topRow.length; index++) ...[
                if (index > 0) const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: SizedBox(
                    height: _buttonHeight,
                    child: QuickCaptureButton(
                      type: _topRow[index],
                      onTap: () => onCaptureTap(_topRow[index]),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: _buttonHeight,
                  child: QuickCaptureButton(
                    type: _bottomRow[0],
                    onTap: () => onCaptureTap(_bottomRow[0]),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: SizedBox(
                  height: _buttonHeight,
                  child: QuickCaptureButton(
                    type: _bottomRow[1],
                    onTap: () => onCaptureTap(_bottomRow[1]),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              const Expanded(child: SizedBox()),
            ],
          ),
        ],
      ),
    );
  }
}
