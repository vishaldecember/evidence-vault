import 'package:flutter/material.dart';

import '../../controllers/workspace_evidence_controller.dart';
import '../../diagnostics/file_final_trace.dart';
import '../../models/workspace_capture_mode.dart';
import '../../theme/app_colors.dart';
import 'capture_media_service.dart';
import 'evidence_upload_coordinator.dart';

/// Outcome of dialog-backed File persist (never navigates).
enum FilePersistDialogResult {
  /// Local evidence committed.
  success,

  /// Originating / dialog context was unmounted — caller should headless persist.
  contextLost,

  /// Preserve threw — do not retry headless (avoids duplicate evidence).
  failed,
}

/// Shared File attach barrier — progress UI + local persist, never navigates.
abstract final class FileAttachmentPersist {
  /// Test seam: awaited after the progress dialog is scheduled, before persist.
  @visibleForTesting
  static Future<void> Function()? debugAfterDialogShown;

  /// Commits [media] with an optional progress dialog.
  static Future<FilePersistDialogResult> persistWithProgress({
    required BuildContext context,
    required WorkspaceEvidenceController controller,
    required CapturedMediaFile media,
    EvidenceUploadCoordinator? uploadCoordinator,
    WorkspaceCaptureMode persistMode = WorkspaceCaptureMode.file,
    String? mimeType,
  }) async {
    if (!context.mounted) {
      FileFinalTrace.stage(
        'PERSIST_DIALOG_SKIP',
        result: 'CONTEXT_UNMOUNTED',
        mounted: false,
        fileName: media.fileName,
        fileSize: media.fileSizeBytes,
      );
      return FilePersistDialogResult.contextLost;
    }

    FileFinalTrace.stage(
      'PERSIST_DIALOG_SHOW',
      mounted: true,
      fileName: media.fileName,
      fileSize: media.fileSizeBytes,
      extra: 'persistMode=${persistMode.name}',
    );

    BuildContext? dialogContext;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (ctx) {
        dialogContext = ctx;
        return PopScope(
          canPop: false,
          child: AlertDialog(
            backgroundColor: AppColors.card,
            content: Row(
              children: [
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    media.fileSizeBytes >= 5 * 1024 * 1024
                        ? 'Attaching large file…'
                        : 'Attaching file…',
                    style: const TextStyle(color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    final originMountedAtShow = context.mounted;
    try {
      await debugAfterDialogShown?.call();
      await controller.preserveEvidenceWithMedia(
        mode: persistMode,
        media: media,
        mimeType: mimeType,
        uploadCoordinator:
            uploadCoordinator ?? EvidenceUploadCoordinator.instance,
      );
      FileFinalTrace.stage(
        'PERSIST_DIALOG_PRESERVE_OK',
        mounted: context.mounted,
        fileName: media.fileName,
      );
      return FilePersistDialogResult.success;
    } catch (error, stack) {
      FileFinalTrace.failure(
        'PERSIST_DIALOG_PRESERVE',
        error: error,
        stackTrace: stack,
        mounted: context.mounted,
        fileName: media.fileName,
        path: media.localPath,
      );
      return FilePersistDialogResult.failed;
    } finally {
      final progressDialogContext = dialogContext;
      _dismissProgressDialogIfCurrent(
        progressDialogContext != null && progressDialogContext.mounted
            ? progressDialogContext
            : null,
        originMounted: originMountedAtShow,
      );
      // Fast persist can finish before the dialog route mounts. Dismiss on
      // the next frame only if that route is still the dialog (never Workspace).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final delayedDialogContext = dialogContext;
        _dismissProgressDialogIfCurrent(
          delayedDialogContext != null && delayedDialogContext.mounted
              ? delayedDialogContext
              : null,
          originMounted: originMountedAtShow,
        );
      });
      debugAfterDialogShown = null;
    }
  }

  /// Pops the progress dialog only. Never pops Incident Workspace.
  static void _dismissProgressDialogIfCurrent(
    BuildContext? dialogContext, {
    required bool originMounted,
  }) {
    final ctx = dialogContext;
    if (ctx == null || !ctx.mounted) {
      FileFinalTrace.stage(
        'PERSIST_DIALOG_DISMISS',
        result: originMounted ? 'SKIPPED_NO_DIALOG' : 'LOST_MID_PERSIST',
        mounted: originMounted,
      );
      return;
    }

    final route = ModalRoute.of(ctx);
    if (route == null || !route.isCurrent) {
      FileFinalTrace.stage(
        'PERSIST_DIALOG_DISMISS',
        result: 'SKIPPED_NOT_CURRENT',
        mounted: true,
      );
      return;
    }

    Navigator.of(ctx).pop();
    FileFinalTrace.stage('PERSIST_DIALOG_DISMISS', result: 'POPPED');
  }
}
