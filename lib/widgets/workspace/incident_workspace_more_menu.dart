import 'package:flutter/material.dart';

import '../../constants/app_accessibility.dart';
import '../../controllers/workspace_evidence_controller.dart';
import '../../domain/incident/incident_title.dart';
import '../../services/persistence/incident_library_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../home/archive_title_required_dialog.dart';
import '../home/incident_lifecycle_dialogs.dart';

/// Persistent incident-level More control for the workspace header.
class IncidentWorkspaceMoreMenu extends StatelessWidget {
  const IncidentWorkspaceMoreMenu({
    super.key,
    required this.incidentId,
    required this.title,
    required this.controller,
    this.onDeleted,
  });

  final String incidentId;
  final String title;
  final WorkspaceEvidenceController controller;
  final VoidCallback? onDeleted;

  static const Key buttonKey = Key('incident_workspace_more');
  static const Key renameKey = Key('incident_menu_rename');
  static const Key archiveKey = Key('incident_menu_archive');
  static const Key deleteKey = Key('incident_menu_delete');
  static const Key restoreKey = Key('incident_menu_restore');
  static const Key deletePermanentlyKey = Key(
    'incident_menu_delete_permanently',
  );

  static const String renameLabel = 'Rename incident';
  static const String archiveLabel = 'Archive incident';
  static const String deleteLabel = 'Delete incident';
  static const String restoreLabel = 'Restore';
  static const String deletePermanentlyLabel = 'Delete permanently';

  @override
  Widget build(BuildContext context) {
    final library = IncidentLibraryService.instance;
    final deleted = library.isRecentlyDeletedId(incidentId);
    final archived = library.isArchivedId(incidentId);

    return PopupMenuButton<_IncidentMenuAction>(
      key: buttonKey,
      tooltip: 'More',
      padding: EdgeInsets.zero,
      onSelected: (action) => _onSelected(context, action),
      itemBuilder: (context) {
        if (deleted) {
          return [
            const PopupMenuItem(
              key: restoreKey,
              value: _IncidentMenuAction.restore,
              child: Text(restoreLabel),
            ),
            PopupMenuItem(
              key: deletePermanentlyKey,
              value: _IncidentMenuAction.deletePermanently,
              child: Text(
                deletePermanentlyLabel,
                style: AppTextStyles.label.copyWith(
                  color: AppColors.danger,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ];
        }
        return [
          if (!archived)
            const PopupMenuItem(
              key: renameKey,
              value: _IncidentMenuAction.rename,
              child: Text(renameLabel),
            ),
          if (!archived)
            const PopupMenuItem(
              key: archiveKey,
              value: _IncidentMenuAction.archive,
              child: Text(archiveLabel),
            ),
          if (!archived) const PopupMenuDivider(),
          PopupMenuItem(
            key: deleteKey,
            value: _IncidentMenuAction.delete,
            child: Row(
              children: [
                const Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: AppColors.danger,
                ),
                const SizedBox(width: 8),
                Text(
                  deleteLabel,
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.danger,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ];
      },
      child: const SizedBox(
        width: AppAccessibility.minTouchTarget,
        height: AppAccessibility.minTouchTarget,
        child: Icon(Icons.more_horiz, color: AppColors.onCanvas, size: 22),
      ),
    );
  }

  Future<void> _onSelected(
    BuildContext context,
    _IncidentMenuAction action,
  ) async {
    final library = IncidentLibraryService.instance;
    switch (action) {
      case _IncidentMenuAction.rename:
        final next = await showRenameIncidentDialog(
          context,
          currentTitle: IncidentTitle.display(title),
        );
        if (next != null) {
          controller.updateIncidentName(next);
        }
      case _IncidentMenuAction.archive:
        if (!IncidentTitle.isMeaningful(title)) {
          if (context.mounted) {
            await showArchiveTitleRequiredDialog(context);
          }
          return;
        }
        await library.archiveIncident(incidentId);
      case _IncidentMenuAction.delete:
        final confirmed = context.mounted
            ? await showDeleteIncidentDialog(context)
            : false;
        if (!confirmed) {
          return;
        }
        library.upsertFromLocal(
          incidentId: incidentId,
          evidenceCount: controller.currentIncident.evidenceCount,
          title: controller.currentIncident.displayTitle,
          updatedAt: controller.currentIncident.updatedAt,
        );
        await library.moveToRecentlyDeleted(incidentId);
        onDeleted?.call();
      case _IncidentMenuAction.restore:
        await library.restoreFromRecentlyDeleted(incidentId);
      case _IncidentMenuAction.deletePermanently:
        final confirmed = context.mounted
            ? await showPermanentlyDeleteIncidentDialog(context)
            : false;
        if (!confirmed) {
          return;
        }
        await library.permanentlyDeleteIncident(incidentId);
        onDeleted?.call();
    }
  }
}

enum _IncidentMenuAction { rename, archive, delete, restore, deletePermanently }
