import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../domain/incident/incident_deletion_lifecycle.dart';
import '../../domain/incident/incident_title.dart';
import '../../models/library_incident_summary.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_text_styles.dart';
import '../common/status_badge.dart';
import 'archive_title_required_dialog.dart';

/// Incident summary tile for Library previews and active records.
///
/// Compact premium card: title, essential metadata, then Case readiness
/// with Archive/Restore on the same row. The card body opens the incident;
/// Archive/Restore remain independently tappable.
class LibraryIncidentSummaryTile extends StatelessWidget {
  const LibraryIncidentSummaryTile({
    super.key,
    required this.incident,
    this.onTap,
    this.onLongPress,
    this.onArchive,
    this.onRestore,
    this.onMoveToRecentlyDeleted,
    this.onDeletePermanently,
  });

  final LibraryIncidentSummary incident;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onArchive;
  final VoidCallback? onRestore;
  final VoidCallback? onMoveToRecentlyDeleted;
  final VoidCallback? onDeletePermanently;

  static Key cardKey(String id) => Key('library_incident_card_$id');

  IncidentStatus get _status {
    if (incident.isRecentlyDeleted) {
      return IncidentStatus.archived;
    }
    if (incident.isArchived) {
      return IncidentStatus.archived;
    }
    if (incident.isInProgress) {
      return IncidentStatus.building;
    }
    if (incident.integrityVerified) {
      return IncidentStatus.ready;
    }
    return IncidentStatus.incomplete;
  }

  Future<bool> _confirmArchive(BuildContext context) async {
    if (IncidentTitle.isMeaningful(incident.title)) {
      return true;
    }
    final addTitle = await showArchiveTitleRequiredDialog(context);
    if (addTitle && context.mounted) {
      onTap?.call();
    }
    return false;
  }

  Future<void> _onArchivePressed(BuildContext context) async {
    if (await _confirmArchive(context) && context.mounted) {
      onArchive?.call();
    }
  }

  String? get _overflowAction {
    if (incident.isRecentlyDeleted && onDeletePermanently != null) {
      return 'delete';
    }
    if (incident.isArchived && onMoveToRecentlyDeleted != null) {
      return 'move';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final card = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: incident.isArchived || incident.isRecentlyDeleted
            ? null
            : onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          key: cardKey(incident.id),
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm,
            6,
            AppSpacing.sm,
            6,
          ),
          decoration:
              AppDecorations.innerTile(
                backgroundColor:
                    incident.isArchived || incident.isRecentlyDeleted
                    ? AppColors.archivedSurface
                    : AppColors.card,
              ).copyWith(
                border: Border.all(
                  color: incident.isArchived || incident.isRecentlyDeleted
                      ? AppColors.archivedBorder.withValues(alpha: 0.9)
                      : AppColors.border.withValues(
                          alpha: AppDecorations.borderAlpha,
                        ),
                ),
              ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: _IncidentTitle(incident: incident)),
                  if (_overflowAction != null) ...[
                    const SizedBox(width: 2),
                    _IncidentOverflowMenu(
                      incidentId: incident.id,
                      action: _overflowAction!,
                      onSelected: _overflowAction == 'move'
                          ? onMoveToRecentlyDeleted
                          : onDeletePermanently,
                    ),
                  ],
                  const SizedBox(width: AppSpacing.xs),
                  StatusBadge(status: _status),
                ],
              ),
              const SizedBox(height: 2),
              _EssentialMetadata(incident: incident),
              if (incident.isRecentlyDeleted && incident.deletedAt != null) ...[
                const SizedBox(height: 2),
                _RecentlyDeletedRetention(deletedAt: incident.deletedAt!),
              ],
              const SizedBox(height: 2),
              _CaseReadinessLifecycleRow(
                integrityVerified: incident.integrityVerified,
                action: incident.isRecentlyDeleted || incident.isArchived
                    ? (onRestore != null ? 'restore' : null)
                    : (onArchive != null ? 'archive' : null),
                onAction: incident.isRecentlyDeleted || incident.isArchived
                    ? onRestore
                    : (onArchive != null
                          ? () => _onArchivePressed(context)
                          : null),
              ),
            ],
          ),
        ),
      ),
    );

    if (!incident.isArchived &&
        !incident.isRecentlyDeleted &&
        onArchive != null) {
      return Dismissible(
        key: ValueKey('library-archive-${incident.id}'),
        direction: DismissDirection.startToEnd,
        dismissThresholds: const {DismissDirection.startToEnd: 0.38},
        movementDuration: AppMotion.fast,
        confirmDismiss: (_) => _confirmArchive(context),
        onDismissed: (_) => onArchive!(),
        background: const _LifecycleSwipeReveal(action: 'Archive'),
        child: card,
      );
    }
    if (incident.isArchived &&
        !incident.isRecentlyDeleted &&
        onRestore != null) {
      return Dismissible(
        key: ValueKey('library-restore-${incident.id}'),
        direction: DismissDirection.startToEnd,
        dismissThresholds: const {DismissDirection.startToEnd: 0.38},
        movementDuration: AppMotion.fast,
        onDismissed: (_) => onRestore!(),
        background: const _LifecycleSwipeReveal(action: 'Restore'),
        child: card,
      );
    }
    return card;
  }
}

class _IncidentTitle extends StatelessWidget {
  const _IncidentTitle({required this.incident});

  final LibraryIncidentSummary incident;

  @override
  Widget build(BuildContext context) {
    final untitled = IncidentTitle.isPlaceholder(incident.title);
    final style = AppTextStyles.label.copyWith(
      fontWeight: FontWeight.w600,
      height: 1.2,
      color: untitled && !incident.isArchived && !incident.isRecentlyDeleted
          ? AppColors.danger
          : AppColors.navy,
    );
    return Text(
      IncidentTitle.display(incident.title),
      style: style,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _EssentialMetadata extends StatelessWidget {
  const _EssentialMetadata({required this.incident});

  final LibraryIncidentSummary incident;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          incident.lastPreserved,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textMuted,
            fontSize: 12,
            height: 1.15,
          ),
        ),
        _MetadataUnit(label: 'Evidence', value: '${incident.evidenceCount}'),
        _MetadataUnit(
          label: 'Context Enriched',
          value: '${incident.contextEnrichedCount}',
        ),
      ],
    );
  }
}

class _CaseReadinessLifecycleRow extends StatelessWidget {
  const _CaseReadinessLifecycleRow({
    required this.integrityVerified,
    required this.action,
    this.onAction,
  });

  final bool integrityVerified;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MetadataUnit(
            label: 'Case readiness',
            value: integrityVerified ? 'Good' : 'Building',
            valueColor: integrityVerified
                ? AppColors.success
                : AppColors.textMuted,
          ),
        ),
        if (action != null)
          _LifecycleAction(
            key: action == 'restore'
                ? const Key('library_restore_action')
                : const Key('library_archive_affordance'),
            action: action!,
            onPressed: onAction,
          ),
      ],
    );
  }
}

class _LifecycleAction extends StatelessWidget {
  const _LifecycleAction({super.key, required this.action, this.onPressed});

  final String action;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final label = action == 'restore' ? 'Restore' : 'Archive';
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.xs,
            top: 2,
            bottom: 2,
          ),
          child: Text(
            label,
            style: AppTextStyles.caption.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
              height: 1.1,
            ),
          ),
        ),
      ),
    );
  }
}

class _LifecycleSwipeReveal extends StatelessWidget {
  const _LifecycleSwipeReveal({required this.action});

  final String action;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.inspectorSurface.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(left: AppSpacing.sm),
          child: Text(
            '$action >>',
            style: AppTextStyles.caption.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _IncidentOverflowMenu extends StatelessWidget {
  const _IncidentOverflowMenu({
    required this.incidentId,
    required this.action,
    this.onSelected,
  });

  final String incidentId;
  final String action;
  final VoidCallback? onSelected;

  @override
  Widget build(BuildContext context) {
    final label = action == 'delete' ? 'Delete permanently' : 'Delete incident';
    return PopupMenuButton<String>(
      key: Key('library_incident_overflow_$incidentId'),
      tooltip: 'More',
      padding: EdgeInsets.zero,
      onSelected: (_) => onSelected?.call(),
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          key: action == 'delete'
              ? const Key('library_delete_permanently')
              : const Key('library_delete_incident'),
          value: action,
          child: Text(
            label,
            style: AppTextStyles.label.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: action == 'delete' ? AppColors.danger : AppColors.navy,
            ),
          ),
        ),
      ],
      icon: Icon(Icons.more_horiz, size: 20, color: AppColors.textMuted),
    );
  }
}

class _RecentlyDeletedRetention extends StatelessWidget {
  const _RecentlyDeletedRetention({required this.deletedAt});

  final DateTime deletedAt;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          IncidentDeletionLifecycle.deletedAgoLabel(deletedAt: deletedAt),
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textMuted,
            fontWeight: FontWeight.w600,
            height: 1.15,
          ),
        ),
        Text(
          IncidentDeletionLifecycle.permanentInLabel(deletedAt: deletedAt),
          key: const Key('recently_deleted_retention'),
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textMuted,
            fontSize: 12,
            height: 1.15,
          ),
        ),
      ],
    );
  }
}

/// One scannable metadata pair — label and value read as a single unit.
class _MetadataUnit extends StatelessWidget {
  const _MetadataUnit({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  static final _labelStyle = AppTextStyles.caption.copyWith(
    fontSize: 12,
    height: 1.15,
  );
  static final _valueStyle = AppTextStyles.caption.copyWith(
    fontWeight: FontWeight.w700,
    fontSize: 12,
    height: 1.15,
  );

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: _labelStyle,
        children: [
          TextSpan(text: label),
          const TextSpan(text: '\u00A0'),
          TextSpan(
            text: value,
            style: _valueStyle.copyWith(color: valueColor ?? AppColors.navy),
          ),
        ],
      ),
    );
  }
}
