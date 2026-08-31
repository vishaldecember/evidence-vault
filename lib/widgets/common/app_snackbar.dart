import 'package:flutter/material.dart';

import 'success_confirmation.dart';

/// Workspace success acknowledgements — centred confirmation, not bottom ribbons.
abstract final class AppSnackBar {
  static void showSuccess(BuildContext context, String message) {
    SuccessConfirmation.show(context, message: message);
  }

  /// Lightweight failure acknowledgement for capture/persist errors.
  static void showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
