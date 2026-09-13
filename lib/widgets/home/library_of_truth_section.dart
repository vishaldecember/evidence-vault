import 'dart:async';

import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../models/library_incident_summary.dart';
import '../../services/persistence/incident_library_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_text_styles.dart';
import '../common/home_section_card.dart';
import 'incident_lifecycle_dialogs.dart';
import 'library_incident_summary_tile.dart';
import 'library_preview_illustration.dart';

enum _LibraryLifecycleTab { active, archived, recentlyDeleted }

/// The Library of Truth section on the Home Launch Pad.
class LibraryOfTruthSection extends StatefulWidget {
  const LibraryOfTruthSection({
    super.key,
    required this.incidents,
    required this.onIncidentTap,
  });

  final List<LibraryIncidentSummary> incidents;
  final ValueChanged<String> onIncidentTap;

  @override
  State<LibraryOfTruthSection> createState() => _LibraryOfTruthSectionState();
}

class _LibraryOfTruthSectionState extends State<LibraryOfTruthSection> {
  _LibraryLifecycleTab _tab = _LibraryLifecycleTab.active;

  bool _isRecentlyDeleted(LibraryIncidentSummary incident) {
    return IncidentLibraryService.instance.isRecentlyDeletedId(incident.id);
  }

  bool _isArchived(LibraryIncidentSummary incident) {
    if (IncidentLibraryService.instance.isRecentlyDeletedId(incident.id)) {
      return false;
    }
    return incident.isArchived ||
        IncidentLibraryService.instance.isArchivedId(incident.id);
  }

  List<LibraryIncidentSummary> get _resolved {
    return [
      for (final incident in widget.incidents)
        incident.copyWith(
          isArchived: _isArchived(incident),
          isRecentlyDeleted: _isRecentlyDeleted(incident),
          deletedAt:
              IncidentLibraryService.instance.deletedAtFor(incident.id) ??
              incident.deletedAt,
        ),
    ];
  }

  List<LibraryIncidentSummary> get _visible {
    return [
      for (final incident in _resolved)
        if (_tab == _LibraryLifecycleTab.recentlyDeleted
            ? incident.isRecentlyDeleted
            : _tab == _LibraryLifecycleTab.archived
            ? incident.isArchived
            : !incident.isArchived && !incident.isRecentlyDeleted)
          incident,
    ];
  }

  @override
  void initState() {
    super.initState();
    unawaited(IncidentLibraryService.instance.sweepExpiredRecentlyDeleted());
  }

  Future<void> _moveToRecentlyDeleted(String incidentId) async {
    final confirmed = await showDeleteIncidentDialog(context);
    if (!confirmed) {
      return;
    }
    await IncidentLibraryService.instance.moveToRecentlyDeleted(incidentId);
  }

  Future<void> _deletePermanently(String incidentId) async {
    final confirmed = await showPermanentlyDeleteIncidentDialog(context);
    if (!confirmed) {
      return;
    }
    await IncidentLibraryService.instance.permanentlyDeleteIncident(incidentId);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.incidents.isEmpty) {
      return HomeSectionCard(
        color: AppColors.canvasAtmosphere,
        padding: const EdgeInsets.symmetric(
          horizontal: 0,
          vertical: AppSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'The Library of Truth',
              textAlign: TextAlign.center,
              style: AppTextStyles.heading,
            ),
            const SizedBox(height: AppSpacing.xs),
            const _LibraryHeroMessage(),
            const SizedBox(height: AppSpacing.sm),
            const LibraryPreviewIllustration(),
          ],
        ),
      );
    }

    return ListenableBuilder(
      listenable: IncidentLibraryService.instance,
      builder: (context, _) {
        final visible = _visible;
        return HomeSectionCard(
          color: AppColors.canvasAtmosphere,
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _LibraryHeader(
                tab: _tab,
                onTabSelected: (tab) => setState(() => _tab = tab),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (visible.isEmpty)
                _LibraryEmptyFilter(tab: _tab)
              else
                for (var index = 0; index < visible.length; index++) ...[
                  if (index > 0) const SizedBox(height: AppSpacing.xs),
                  LibraryIncidentSummaryTile(
                    incident: visible[index],
                    onTap: () => widget.onIncidentTap(visible[index].id),
                    onArchive:
                        visible[index].isRecentlyDeleted ||
                            visible[index].isArchived
                        ? null
                        : () {
                            unawaited(
                              IncidentLibraryService.instance.archiveIncident(
                                visible[index].id,
                              ),
                            );
                          },
                    onRestore: visible[index].isRecentlyDeleted
                        ? () {
                            unawaited(
                              IncidentLibraryService.instance
                                  .restoreFromRecentlyDeleted(
                                    visible[index].id,
                                  ),
                            );
                          }
                        : visible[index].isArchived
                        ? () {
                            unawaited(
                              IncidentLibraryService.instance.restoreIncident(
                                visible[index].id,
                              ),
                            );
                          }
                        : null,
                    onMoveToRecentlyDeleted: visible[index].isArchived
                        ? () {
                            unawaited(
                              _moveToRecentlyDeleted(visible[index].id),
                            );
                          }
                        : null,
                    onDeletePermanently: visible[index].isRecentlyDeleted
                        ? () {
                            unawaited(_deletePermanently(visible[index].id));
                          }
                        : null,
                  ),
                ],
            ],
          ),
        );
      },
    );
  }
}

class _LibraryHeader extends StatelessWidget {
  const _LibraryHeader({required this.tab, required this.onTabSelected});

  final _LibraryLifecycleTab tab;
  final ValueChanged<_LibraryLifecycleTab> onTabSelected;

  static const Key titleKey = Key('library_of_truth_title');

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          flex: 5,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              'The Library of Truth',
              key: titleKey,
              maxLines: 1,
              softWrap: false,
              style: AppTextStyles.heading.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                height: 1.1,
                letterSpacing: -0.45,
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          flex: 6,
          child: _LifecycleTabs(tab: tab, onTabSelected: onTabSelected),
        ),
      ],
    );
  }
}

class _LifecycleTabs extends StatelessWidget {
  const _LifecycleTabs({required this.tab, required this.onTabSelected});

  final _LibraryLifecycleTab tab;
  final ValueChanged<_LibraryLifecycleTab> onTabSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _LifecycleTabButton(
            key: const Key('library_tab_active'),
            label: 'Active',
            selected: tab == _LibraryLifecycleTab.active,
            onTap: () => onTabSelected(_LibraryLifecycleTab.active),
          ),
        ),
        const SizedBox(width: 2),
        Expanded(
          child: _LifecycleTabButton(
            key: const Key('library_tab_archived'),
            label: 'Archived',
            selected: tab == _LibraryLifecycleTab.archived,
            onTap: () => onTabSelected(_LibraryLifecycleTab.archived),
          ),
        ),
        const SizedBox(width: 2),
        Expanded(
          child: _LifecycleTabButton(
            key: const Key('library_tab_recently_deleted'),
            label: 'Deleted',
            selected: tab == _LibraryLifecycleTab.recentlyDeleted,
            onTap: () => onTabSelected(_LibraryLifecycleTab.recentlyDeleted),
          ),
        ),
      ],
    );
  }
}

class _LifecycleTabButton extends StatelessWidget {
  const _LifecycleTabButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  static const double _radius = 8;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(_radius);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius,
          splashColor: AppColors.primary.withValues(alpha: 0.08),
          highlightColor: AppColors.primary.withValues(alpha: 0.04),
          child: AnimatedContainer(
            duration: AppMotion.fast,
            curve: AppMotion.enter,
            constraints: const BoxConstraints(minHeight: 48),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 12),
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : Colors.white,
              borderRadius: borderRadius,
              border: Border.all(
                color: selected
                    ? AppColors.primaryDeep
                    : AppColors.borderAccent.withValues(alpha: 0.92),
                width: selected ? 1.5 : 1,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.22),
                        blurRadius: 5,
                        offset: const Offset(0, 1),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.fade,
              style: AppTextStyles.caption.copyWith(
                color: selected ? AppColors.onPrimary : AppColors.textMuted,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                fontSize: 12,
                height: 1.15,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LibraryEmptyFilter extends StatelessWidget {
  const _LibraryEmptyFilter({required this.tab});

  final _LibraryLifecycleTab tab;

  @override
  Widget build(BuildContext context) {
    final message = switch (tab) {
      _LibraryLifecycleTab.recentlyDeleted => 'No deleted incidents.',
      _LibraryLifecycleTab.archived => 'No archived incidents.',
      _LibraryLifecycleTab.active => 'No active incidents.',
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Text(
        message,
        style: AppTextStyles.caption.copyWith(
          color: AppColors.textMuted,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// Connected hero copy — one thought, two lines, no artificial gap.
class _LibraryHeroMessage extends StatelessWidget {
  const _LibraryHeroMessage();

  static const _primaryLine = 'Every library begins with one piece of truth.';
  static const _secondaryLine = 'Enrich it as your story unfolds.';

  /// 3sp below [AppTextStyles.heading] — secondary without shrinking readability.
  static const double _supportingFontSize = 17;

  /// Shared tight line height — only natural leading separates the lines.
  static const double _lineHeight = 1.15;

  @override
  Widget build(BuildContext context) {
    final supportingStyle = TextStyle(
      fontSize: _supportingFontSize,
      fontWeight: FontWeight.w500,
      height: _lineHeight,
      letterSpacing: -0.2,
      color: AppColors.textSecondary,
    );
    final secondaryStyle = supportingStyle.copyWith(color: AppColors.textMuted);

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '$_primaryLine\n', style: supportingStyle),
          TextSpan(text: _secondaryLine, style: secondaryStyle),
        ],
      ),
      textAlign: TextAlign.center,
      maxLines: 2,
      softWrap: false,
      overflow: TextOverflow.visible,
    );
  }
}
