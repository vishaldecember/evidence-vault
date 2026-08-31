import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_styles.dart';

/// Empty state when no relationship groups exist yet.
class ConnectionsEmpty extends StatelessWidget {
  const ConnectionsEmpty({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: AppDecorations.card(backgroundColor: AppColors.surfaceMuted),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Text(
          'When you organize evidence in the Connections Workspace, related '
          'artifacts will appear here as groups.',
          style: AppTextStyles.bodySmall.copyWith(height: 1.55),
        ),
      ),
    );
  }
}
