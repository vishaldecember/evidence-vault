import 'package:flutter/material.dart';

import '../constants/app_spacing.dart';
import '../controllers/workspace_evidence_controller.dart';
import '../domain/trust_package/trust_package.dart';
import '../models/workspace_evidence_item.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/common/app_back_button.dart';
import '../widgets/common/space_canvas.dart';
import '../widgets/trust_package/export/trust_package_export_actions.dart';
import '../widgets/trust_package/preview/trust_package_preview.dart';

/// Read-only Trust Package preview workspace.
///
/// Reads the shared [WorkspaceEvidenceController.currentIncident] / canonical
/// Trust Package on every controller notification — never a frozen snapshot.
///
/// Evidence taps navigate to Investigation for editing — no in-place mutation.
class TrustPackageScreen extends StatelessWidget {
  const TrustPackageScreen({
    super.key,
    required this.controller,
    this.boundIncidentId,
    this.trustPackage,
    this.onNavigateToInvestigation,
    this.embeddedInShell = false,
  });

  final WorkspaceEvidenceController controller;

  /// Shell-authoritative incident. Session controller is subordinate.
  final String? boundIncidentId;

  /// Optional override for tests. Production always reads from [controller].
  final TrustPackage? trustPackage;

  final VoidCallback? onNavigateToInvestigation;
  final bool embeddedInShell;

  WorkspaceEvidenceItem? _resolveEvidence(String evidenceId) {
    return controller.currentIncident.evidenceById(evidenceId);
  }

  void _handleEvidenceTap(BuildContext context, String evidenceId) {
    if (_resolveEvidence(evidenceId) == null) {
      return;
    }

    onNavigateToInvestigation?.call();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (boundIncidentId != null) {
          final bound = boundIncidentId!.trim();
          final sessionId = controller.currentIncident.id.trim();
          if (bound.isEmpty || sessionId != bound) {
            return const SizedBox.shrink();
          }
        }
        final package = trustPackage ?? controller.canonicalTrustPackage;
        final preview = TrustPackagePreview(
          package: package,
          onEvidenceSelected: (evidenceId) =>
              _handleEvidenceTap(context, evidenceId),
        );

        if (embeddedInShell) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenHorizontal,
                  AppSpacing.sm,
                  AppSpacing.screenHorizontal,
                  AppSpacing.xs,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Trust Package Preview',
                        style: AppTextStyles.heading.copyWith(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: AppColors.onCanvas,
                          letterSpacing: -0.4,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        softWrap: true,
                      ),
                    ),
                    TrustPackageExportActions(package: package),
                  ],
                ),
              ),
              Expanded(child: preview),
            ],
          );
        }

        return SpaceCanvas(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              foregroundColor: AppColors.onCanvas,
              leading: const AppBackButton(color: AppColors.onCanvas),
              title: Text(
                'Trust Package Preview',
                style: AppTextStyles.screenTitle.copyWith(
                  color: AppColors.onCanvas,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
                maxLines: 2,
                softWrap: true,
              ),
              actions: [
                TrustPackageExportActions(package: package),
              ],
            ),
            body: SafeArea(child: preview),
          ),
        );
      },
    );
  }
}
