import 'package:flutter/material.dart';

import '../constants/app_spacing.dart';
import '../controllers/workspace_session.dart';
import '../models/evidence_type.dart';
import '../models/pending_evidence.dart';
import '../models/workspace_capture_mode.dart';
import '../navigation/app_navigation.dart';
import '../services/user_session_service.dart';
import '../services/evidence_storage_service.dart';
import '../services/storage/evidence_upload_coordinator.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/auth/auth_feedback.dart';
import '../widgets/ev_button.dart';
import '../widgets/evidence/evidence_metadata_panel.dart';
import '../widgets/evidence/evidence_thumbnail_preview.dart';

class EvidencePreviewScreen extends StatefulWidget {
  const EvidencePreviewScreen({
    super.key,
    required this.pending,
  });

  final PendingEvidence pending;

  @override
  State<EvidencePreviewScreen> createState() => _EvidencePreviewScreenState();
}

class _EvidencePreviewScreenState extends State<EvidencePreviewScreen> {
  bool _isSaving = false;

  Future<void> _saveEvidence() async {
    setState(() => _isSaving = true);

    try {
      final record = await EvidenceStorageService.save(widget.pending);

      // Sprint 4A — also push the binary to Firebase Storage (non-blocking path
      // still awaits here so legacy preview reports success after upload attempt).
      final mode = _modeFor(widget.pending.type);
      if (mode != null && UserSessionService.isSignedIn) {
        final meta = widget.pending.metadata;
        await EvidenceUploadCoordinator.instance.uploadCapturedMedia(
          evidenceId: record.id,
          incidentId: WorkspaceSession.instance.controller.currentIncident.id,
          localFilePath: widget.pending.filePath,
          mode: mode,
          deviceModel: meta.device.name,
          latitude: meta.location.latitude,
          longitude: meta.location.longitude,
          captureTime: meta.capturedAt,
        );
      }

      if (!mounted) return;

      AuthFeedback.showSuccess(context, 'Evidence saved to your vault.');
      await AppNavigation.openEvidenceWorkspace(context);
    } catch (_) {
      if (!mounted) return;
      AuthFeedback.showError(
        context,
        'Unable to save evidence. Please try again.',
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  WorkspaceCaptureMode? _modeFor(EvidenceType type) => switch (type) {
        EvidenceType.photo => WorkspaceCaptureMode.photo,
        EvidenceType.video => WorkspaceCaptureMode.video,
        EvidenceType.audio => WorkspaceCaptureMode.voice,
        EvidenceType.document => WorkspaceCaptureMode.file,
      };

  Future<void> _discardEvidence() async {
    await EvidenceStorageService.discardTempFile(widget.pending.filePath);
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final pending = widget.pending;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text('Evidence Preview', style: AppTextStyles.screenTitle),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenHorizontal,
          AppSpacing.sm,
          AppSpacing.screenHorizontal,
          AppSpacing.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EvidenceThumbnailPreview(
              type: pending.type,
              filePath: pending.filePath,
              thumbnailPath: pending.thumbnailPath,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              pending.title.isEmpty ? 'Untitled evidence' : pending.title,
              style: AppTextStyles.heading,
            ),
            if (pending.description.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(pending.description, style: AppTextStyles.body),
            ],
            const SizedBox(height: AppSpacing.lg),
            EvidenceMetadataPanel(
              metadata: pending.metadata,
              fileSizeBytes: pending.fileSizeBytes,
            ),
            const SizedBox(height: AppSpacing.lg),
            EVButton(
              text: 'Save',
              isLoading: _isSaving,
              onPressed: _isSaving ? null : _saveEvidence,
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              onPressed: _isSaving ? null : _discardEvidence,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(AppSpacing.buttonHeight),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
                ),
                side: const BorderSide(color: AppColors.danger),
              ),
              child: Text(
                'Discard',
                style: AppTextStyles.label.copyWith(color: AppColors.danger),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
