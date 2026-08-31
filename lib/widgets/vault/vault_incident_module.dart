import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../domain/incident/incident_title.dart';
import '../../models/library_incident_summary.dart';
import '../../presentation/incident_cover_resolver.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_styles.dart';
import '../common/status_badge.dart';
import 'incident_cover_preview.dart';

/// Vault Incident module — one event, optional existing cover thumbnail.
///
/// Home Library tiles are unchanged. This does not load original evidence.
class VaultIncidentModule extends StatefulWidget {
  const VaultIncidentModule({
    super.key,
    required this.incident,
    this.onTap,
    this.onLongPress,
    this.coverOverride,
  });

  final LibraryIncidentSummary incident;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final IncidentCoverResolution? coverOverride;

  static const typeLabel = 'INCIDENT';

  static Key moduleKey(String incidentId) =>
      Key('vault_incident_module_$incidentId');

  @override
  State<VaultIncidentModule> createState() => _VaultIncidentModuleState();
}

class _VaultIncidentModuleState extends State<VaultIncidentModule> {
  late IncidentCoverResolution _resolution;

  LibraryIncidentSummary get _incident => widget.incident;

  IncidentStatus get _status {
    if (_incident.isArchived) {
      return IncidentStatus.archived;
    }
    if (_incident.isInProgress) {
      return IncidentStatus.building;
    }
    if (_incident.integrityVerified) {
      return IncidentStatus.ready;
    }
    return IncidentStatus.incomplete;
  }

  bool get _expectsCoverBand =>
      (_incident.coverEvidenceId?.trim().isNotEmpty ?? false) ||
      (widget.coverOverride?.hasThumbnail ?? false);

  @override
  void initState() {
    super.initState();
    _resolution = widget.coverOverride ?? IncidentCoverResolution.fallback;
    if (widget.coverOverride == null && _expectsCoverBand) {
      _resolve();
    }
  }

  @override
  void didUpdateWidget(VaultIncidentModule oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.coverOverride != null) {
      _resolution = widget.coverOverride!;
      return;
    }
    if (oldWidget.incident.coverEvidenceId != _incident.coverEvidenceId ||
        oldWidget.incident.id != _incident.id) {
      _resolution = IncidentCoverResolution.fallback;
      if (_expectsCoverBand) {
        _resolve();
      }
    }
  }

  Future<void> _resolve() async {
    final resolved = await IncidentCoverResolver.resolve(
      incidentId: _incident.id,
      coverEvidenceId: _incident.coverEvidenceId,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _resolution = resolved;
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = IncidentTitle.display(_incident.title);
    final untitled = IncidentTitle.isPlaceholder(_incident.title);
    const evidenceWord = 'evidence';
    return Semantics(
      button: widget.onTap != null,
      label:
          '$title, incident, ${_status.label}, ${_incident.evidenceCount} $evidenceWord',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          onLongPress: _incident.isArchived ? null : widget.onLongPress,
          borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
          child: ExcludeSemantics(
            child: Ink(
              key: VaultIncidentModule.moduleKey(_incident.id),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.sm,
              ),
              decoration: AppDecorations.innerTile(
                backgroundColor: _incident.isArchived
                    ? AppColors.archivedSurface
                    : AppColors.card,
              ).copyWith(
                border: Border.all(
                  color: _incident.isArchived
                      ? AppColors.archivedBorder.withValues(alpha: 0.9)
                      : AppColors.border
                          .withValues(alpha: AppDecorations.borderAlpha),
                ),
              ),
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_expectsCoverBand) ...[
                      IncidentCoverPreview.band(
                        incidentId: _incident.id,
                        resolution: _resolution,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                    ],
                    Text(
                      VaultIncidentModule.typeLabel,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.navy.withValues(alpha: 0.55),
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                        letterSpacing: 1.1,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.label.copyWith(
                              fontWeight: FontWeight.w700,
                              color: untitled && !_incident.isArchived
                                  ? AppColors.danger
                                  : AppColors.navy,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        StatusBadge(status: _status),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_incident.lastPreserved}  ·  ${_incident.evidenceCount} $evidenceWord',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
            ),
          ),
        ),
      ),
    );
  }
}
