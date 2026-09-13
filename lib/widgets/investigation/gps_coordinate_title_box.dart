import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// Read-only complete GPS pair. Shared by Graph and Reconstruct.
class GpsCoordinateTitleBox extends StatelessWidget {
  const GpsCoordinateTitleBox({super.key, required this.coordinates});

  final String coordinates;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 268, minHeight: 28),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.inspectorSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppColors.canvasHaloCore.withValues(alpha: 0.38),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'GPS',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.canvasHaloCore.withValues(alpha: 0.78),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                    height: 1,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: SizedBox(
                    width: 1,
                    height: 11,
                    child: ColoredBox(
                      color: AppColors.canvasHaloCore.withValues(alpha: 0.32),
                    ),
                  ),
                ),
                Text(
                  coordinates,
                  maxLines: 1,
                  softWrap: false,
                  style: AppTextStyles.caption.copyWith(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1,
                    letterSpacing: 0.15,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
