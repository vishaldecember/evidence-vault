import 'package:flutter/material.dart';

import '../ev_button.dart';

/// Primary authentication action button with loading support.
class AuthButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final String? loadingText;
  final Color? color;

  const AuthButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.loadingText,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return EVButton(
      text: text,
      onPressed: onPressed,
      isLoading: isLoading,
      loadingText: loadingText,
      color: color,
    );
  }
}
