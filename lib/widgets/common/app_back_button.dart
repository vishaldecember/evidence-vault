import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Standard back navigation control with screen-reader label.
class AppBackButton extends StatelessWidget {
  const AppBackButton({super.key, this.onPressed, this.color});

  final VoidCallback? onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Back',
      onPressed: onPressed ?? () => Navigator.maybePop(context),
      icon: Icon(
        Icons.arrow_back_ios_new,
        color: color ?? AppColors.navy,
        size: 20,
      ),
    );
  }
}
