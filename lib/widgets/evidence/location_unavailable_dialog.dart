import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../constants/app_spacing.dart';
import '../../navigation/app_navigator.dart';
import '../../services/capture/capture_provenance.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_text_styles.dart';

/// Capture-time location prompt. Evidence is already preserved.
abstract final class CaptureLocationPrompt {
  static Future<void> offer({
    required CaptureLocationStatus status,
    required Future<bool> Function() onRetry,
    required VoidCallback onDismissed,
  }) async {
    if (_inFlutterTest) {
      return;
    }
    if (status == CaptureLocationStatus.captured ||
        status == CaptureLocationStatus.skipped) {
      return;
    }
    final context = appNavigatorKey.currentContext;
    if (context == null || !context.mounted) {
      return;
    }

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: AppColors.navy.withValues(alpha: 0.28),
      transitionDuration: AppMotion.page,
      pageBuilder: (context, animation, secondaryAnimation) {
        return Center(
          child: _LocationUnavailableDialog(
            status: status,
            onContinue: () {
              onDismissed();
              Navigator.pop(context);
            },
            onRetry: () async {
              final recovered = await onRetry();
              if (!context.mounted) {
                return;
              }
              if (!recovered) {
                onDismissed();
              }
              Navigator.pop(context);
            },
            onOpenSettings: () async {
              onDismissed();
              if (status == CaptureLocationStatus.servicesDisabled) {
                await Geolocator.openLocationSettings();
              } else {
                await openAppSettings();
              }
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
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
  }

  static bool get _inFlutterTest =>
      !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
}

class _LocationUnavailableDialog extends StatelessWidget {
  const _LocationUnavailableDialog({
    required this.status,
    required this.onContinue,
    required this.onRetry,
    required this.onOpenSettings,
  });

  final CaptureLocationStatus status;
  final VoidCallback onContinue;
  final Future<void> Function() onRetry;
  final Future<void> Function() onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final settings = status == CaptureLocationStatus.servicesDisabled ||
        status == CaptureLocationStatus.permissionPermanentlyDenied;
    final actionLabel = status == CaptureLocationStatus.servicesDisabled
        ? 'Enable Location'
        : (settings ? 'Open settings' : 'Try Again');

    return AlertDialog(
      key: const Key('capture_location_unavailable_dialog'),
      backgroundColor: AppColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      title: Text('Location unavailable', style: AppTextStyles.heading),
      content: const Text(
        "My Truth couldn't capture your location for this moment.",
        style: AppTextStyles.bodySmall,
      ),
      actions: [
        TextButton(
          onPressed: onContinue,
          child: const Text('Not now', style: AppTextStyles.link),
        ),
        TextButton(
          onPressed: () {
            if (settings) {
              onOpenSettings();
            } else {
              onRetry();
            }
          },
          child: Text(actionLabel, style: AppTextStyles.link),
        ),
      ],
    );
  }
}
