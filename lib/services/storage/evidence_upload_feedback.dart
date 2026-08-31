import 'package:flutter/material.dart';

import '../../services/storage/evidence_upload_coordinator.dart';
import '../../services/storage/evidence_upload_models.dart';

/// Quiet upload feedback — never blocks capture with percentage snackbars.
///
/// Progress stays on the evidence thumbnail (compact sync badge). Failures
/// surface a calm optional retry; local evidence is always retained.
abstract final class EvidenceUploadFeedback {
  static Future<bool> confirmRetry(BuildContext context) async {
    if (!context.mounted) {
      return false;
    }
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Couldn’t sync this evidence'),
          content: const Text(
            'It’s saved on this device. Retry syncing now?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Keep local'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Retry'),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  /// Watches [evidenceId] for failure only — uploading stays unobtrusive.
  static void listenAndReport({
    required BuildContext context,
    required String evidenceId,
    required EvidenceUploadCoordinator coordinator,
    required Future<void> Function() onRetry,
  }) {
    void listener() {
      final progress = coordinator.progressFor(evidenceId);
      if (progress == null || !context.mounted) {
        return;
      }

      if (progress.status == EvidenceUploadStatus.failed) {
        coordinator.removeListener(listener);
        confirmRetry(context).then((shouldRetry) async {
          if (!shouldRetry || !context.mounted) {
            return;
          }
          listenAndReport(
            context: context,
            evidenceId: evidenceId,
            coordinator: coordinator,
            onRetry: onRetry,
          );
          await onRetry();
        });
      } else if (progress.status == EvidenceUploadStatus.uploaded) {
        coordinator.removeListener(listener);
        Future<void>.delayed(const Duration(milliseconds: 600), () {
          coordinator.clearProgress(evidenceId);
        });
      }
    }

    coordinator.addListener(listener);
    listener();
  }
}
