import 'dart:async';

import 'package:flutter/material.dart';

import '../constants/app_spacing.dart';
import '../controllers/workspace_session.dart';
import '../domain/memory/memory_recall_item.dart';
import '../models/library_incident_summary.dart';
import '../navigation/app_navigation.dart';
import '../domain/vault/incident_collection.dart';
import '../services/memory/memory_recall_service.dart';
import '../services/persistence/incident_library_service.dart';
import '../services/user_session_service.dart';
import '../services/vault/incident_collection_store.dart';
import '../services/vault/vault_incident_grouping.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/common/app_snackbar.dart';
import '../widgets/common/layered_card.dart';
import '../widgets/home/library_incident_summary_tile.dart';
import '../widgets/vault/memory_recall_section.dart';
import '../widgets/vault/this_month_section.dart';
import '../widgets/vault/collection_member_resolution.dart';
import '../widgets/vault/vault_collection_module.dart';
import '../widgets/vault/vault_incident_module.dart';
import '../widgets/vault/vault_collection_organize_slot.dart';
import '../widgets/vault/vault_incident_organize_slot.dart';
import '../widgets/vault/vault_organize_module.dart';
import '../widgets/vault/vault_recent_layout.dart';

/// The Library of Truth — Vault with This Month + Memory Recall (Sprint 5D).
class VaultScreen extends StatefulWidget {
  const VaultScreen({
    super.key,
    this.onIncidentOpen,
    this.collectionUserId,
    this.collectionStore,
  });

  /// Test seam. Production opens the existing Incident Workspace.
  final ValueChanged<LibraryIncidentSummary>? onIncidentOpen;

  /// Test seam. Production uses the signed-in user, then a local session id.
  final String? collectionUserId;

  /// Test seam. Production uses [IncidentCollectionStore.instance].
  final IncidentCollectionStore? collectionStore;

  static const Key organizeModeKey = Key('vault_organize_mode');
  static const Key doneKey = Key('vault_organize_done');

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen>
    with SingleTickerProviderStateMixin {
  bool _organizing = false;
  bool _groupingInFlight = false;
  List<IncidentCollection> _collections = const [];
  late final AnimationController _jiggle;
  late final VaultIncidentGrouping _grouping;

  @override
  void initState() {
    super.initState();
    _jiggle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _grouping = VaultIncidentGrouping(store: widget.collectionStore);
    IncidentLibraryService.instance.refresh();
    IncidentLibraryService.instance.addListener(_onLibraryChanged);
    // Async recall — never blocks first paint.
    unawaited(MemoryRecallService.instance.refresh());
    unawaited(_loadCollections());
  }

  @override
  void dispose() {
    _jiggle.dispose();
    IncidentLibraryService.instance.removeListener(_onLibraryChanged);
    super.dispose();
  }

  void _enterOrganize() {
    if (_organizing) {
      return;
    }
    setState(() {
      _organizing = true;
    });
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (!reduceMotion) {
      _jiggle.repeat();
    }
  }

  void _exitOrganize() {
    if (!_organizing) {
      return;
    }
    _jiggle
      ..stop()
      ..value = 0;
    setState(() {
      _organizing = false;
    });
  }

  String get _ownerId {
    final override = widget.collectionUserId?.trim();
    if (override != null && override.isNotEmpty) {
      return override;
    }
    final signed = UserSessionService.account?.userId.trim() ?? '';
    if (signed.isNotEmpty) {
      return signed;
    }
    return 'local';
  }

  Future<void> _loadCollections() async {
    final collections = await _grouping.store.list(userId: _ownerId);
    if (!mounted) {
      return;
    }
    setState(() {
      _collections = collections;
    });
  }

  bool _isArchivedId(String incidentId) {
    final library = IncidentLibraryService.instance;
    if (library.isArchivedId(incidentId)) {
      return true;
    }
    for (final incident in library.summaries) {
      if (incident.id == incidentId && incident.isArchived) {
        return true;
      }
    }
    return false;
  }

  Future<void> _handleIncidentDrop({
    required String sourceIncidentId,
    required String targetIncidentId,
  }) async {
    if (!_organizing || _groupingInFlight) {
      return;
    }
    if (_isArchivedId(sourceIncidentId) || _isArchivedId(targetIncidentId)) {
      if (mounted) {
        AppSnackBar.showSuccess(
          context,
          'Restore this incident before changing collection membership.',
        );
      }
      return;
    }
    _groupingInFlight = true;
    try {
      final created = await _grouping.groupIncidents(
        userId: _ownerId,
        sourceIncidentId: sourceIncidentId,
        targetIncidentId: targetIncidentId,
      );
      if (!mounted) {
        return;
      }
      if (created == null) {
        return;
      }
      await _loadCollections();
    } catch (_) {
      if (mounted) {
        AppSnackBar.showError(
          context,
          'Couldn’t group those incidents. Try again.',
        );
      }
    } finally {
      _groupingInFlight = false;
    }
  }

  Future<void> _handleCollectionDrop({
    required String sourceIncidentId,
    required String collectionId,
  }) async {
    if (!_organizing || _groupingInFlight) {
      return;
    }
    if (_isArchivedId(sourceIncidentId)) {
      if (mounted) {
        AppSnackBar.showSuccess(
          context,
          'Restore this incident before changing collection membership.',
        );
      }
      return;
    }
    _groupingInFlight = true;
    try {
      final updated = await _grouping.addIncidentToCollection(
        userId: _ownerId,
        collectionId: collectionId,
        incidentId: sourceIncidentId,
      );
      if (!mounted) {
        return;
      }
      if (updated == null) {
        return;
      }
      await _loadCollections();
    } catch (_) {
      if (mounted) {
        AppSnackBar.showError(
          context,
          'Couldn’t group those incidents. Try again.',
        );
      }
    } finally {
      _groupingInFlight = false;
    }
  }

  void _onLibraryChanged() {
    MemoryRecallService.instance.recomputeFromLibrary();
  }

  Future<void> _handleIncidentTap(LibraryIncidentSummary incident) async {
    if (_organizing) {
      return;
    }
    // Open by immutable id — Untitled is as valid as a named incident.
    final incidentId = incident.id.trim();
    if (incidentId.isEmpty) {
      return;
    }
    if (widget.onIncidentOpen != null) {
      widget.onIncidentOpen!(incident);
      return;
    }
    final opened =
        await WorkspaceSession.instance.openIncident(incidentId);
    if (!mounted) {
      return;
    }
    if (!opened) {
      // Match Home: surface failure instead of a silent no-op.
      AppSnackBar.showSuccess(
        context,
        'Couldn’t open that incident yet. Try again.',
      );
      return;
    }
    await AppNavigation.openIncidentWorkspaceFromLibrary(context);
  }

  Future<void> _handleCollectionTap(IncidentCollection collection) async {
    if (_organizing) {
      return;
    }
    final collectionId = collection.id.trim();
    if (collectionId.isEmpty) {
      return;
    }
    await AppNavigation.openCollectionBrowser(
      context,
      collectionId: collectionId,
      userId: _ownerId,
      initialCollection: collection,
      store: widget.collectionStore,
      onIncidentOpen: widget.onIncidentOpen,
    );
  }

  Future<void> _handleRecallAction(MemoryRecallItem item) async {
    await _handleIncidentTap(
      LibraryIncidentSummary(
        id: item.incidentId,
        title: item.title,
        evidenceCount: item.evidenceCount ?? 0,
        contextEnrichedCount: item.relationshipCount ?? 0,
        integrityVerified: false,
        lastPreserved: item.ageLabel ?? '',
        isInProgress: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_organizing,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || !_organizing) {
          return;
        }
        _exitOrganize();
      },
      child: ColoredBox(
      color: Colors.transparent,
      child: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: Listenable.merge([
            IncidentLibraryService.instance,
            MemoryRecallService.instance,
          ]),
          builder: (context, _) {
            final library = IncidentLibraryService.instance;
            final incidents = library.summaries;
            final active = [
              for (final incident in incidents)
                if (!incident.isRecentlyDeleted &&
                    !library.isRecentlyDeletedId(incident.id) &&
                    !incident.isArchived &&
                    !library.isArchivedId(incident.id))
                  incident,
            ];
            final archived = [
              for (final incident in incidents)
                if (!incident.isRecentlyDeleted &&
                    !library.isRecentlyDeletedId(incident.id) &&
                    (incident.isArchived || library.isArchivedId(incident.id)))
                  incident.copyWith(isArchived: true),
            ];
            final recall = MemoryRecallService.instance;
            if (incidents.isEmpty) {
              return const _EmptyVault(
                showMemoryExplanation: true,
              );
            }
            return _VaultList(
              organizing: _organizing,
              organizeAnimation: _jiggle,
              recent: composeVaultRecent(
                activeIncidents: active,
                collections: _collections,
              ),
              archivedIncidents: archived,
              monthSummary: recall.monthSummary,
              recallItems: recall.items,
              onIncidentTap: _handleIncidentTap,
              onCollectionTap: _handleCollectionTap,
              onIncidentLongPress: _enterOrganize,
              onOrganizeDone: _exitOrganize,
              onOrganizeRemove: _exitOrganize,
              onIncidentDrop: (source, target) {
                unawaited(
                  _handleIncidentDrop(
                    sourceIncidentId: source,
                    targetIncidentId: target,
                  ),
                );
              },
              onCollectionDrop: (source, collectionId) {
                unawaited(
                  _handleCollectionDrop(
                    sourceIncidentId: source,
                    collectionId: collectionId,
                  ),
                );
              },
              onRestore: _organizing
                  ? null
                  : (incident) {
                      unawaited(
                        IncidentLibraryService.instance
                            .restoreIncident(incident.id),
                      );
                    },
              onRecallAction: _handleRecallAction,
              onRecallDismiss: (item) {
                unawaited(MemoryRecallService.instance.dismiss(item.id));
              },
            );
          },
        ),
      ),
    ),
    );
  }
}

class _VaultList extends StatelessWidget {
  const _VaultList({
    required this.organizing,
    required this.organizeAnimation,
    required this.recent,
    required this.archivedIncidents,
    required this.monthSummary,
    required this.recallItems,
    required this.onIncidentTap,
    required this.onCollectionTap,
    required this.onIncidentLongPress,
    required this.onOrganizeDone,
    required this.onOrganizeRemove,
    required this.onIncidentDrop,
    required this.onCollectionDrop,
    required this.onRestore,
    required this.onRecallAction,
    required this.onRecallDismiss,
  });

  final bool organizing;
  final Animation<double> organizeAnimation;
  final List<VaultRecentEntry> recent;
  final List<LibraryIncidentSummary> archivedIncidents;
  final MemoryMonthSummary monthSummary;
  final List<MemoryRecallItem> recallItems;
  final ValueChanged<LibraryIncidentSummary> onIncidentTap;
  final ValueChanged<IncidentCollection> onCollectionTap;
  final VoidCallback onIncidentLongPress;
  final VoidCallback onOrganizeDone;
  final VoidCallback onOrganizeRemove;
  final void Function(String sourceIncidentId, String targetIncidentId)
      onIncidentDrop;
  final void Function(String sourceIncidentId, String collectionId)
      onCollectionDrop;
  final ValueChanged<LibraryIncidentSummary>? onRestore;
  final ValueChanged<MemoryRecallItem> onRecallAction;
  final ValueChanged<MemoryRecallItem> onRecallDismiss;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: organizing ? 'Organizing incidents' : null,
      child: SingleChildScrollView(
      key: organizing ? VaultScreen.organizeModeKey : null,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
        vertical: AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
        Text(
          'The Library of Truth',
          style: AppTextStyles.heroTitle,
        ),
        const SizedBox(height: AppSpacing.md),
        ThisMonthSection(summary: monthSummary),
        if (!monthSummary.isEmpty) const SizedBox(height: AppSpacing.lg),
        MemoryRecallSection(
          items: recallItems,
          onAction: onRecallAction,
          onDismiss: onRecallDismiss,
        ),
        if (recallItems.isNotEmpty) const SizedBox(height: AppSpacing.lg),
        if (recent.isNotEmpty) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  'Recent Incidents',
                  style: AppTextStyles.heading.copyWith(
                    color: AppColors.onCanvas,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
              ),
              if (organizing)
                TextButton(
                  key: VaultScreen.doneKey,
                  onPressed: onOrganizeDone,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.onCanvas,
                    minimumSize: const Size(48, 48),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Done',
                    style: AppTextStyles.label.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (var i = 0; i < recent.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.sm),
            _VaultRecentRow(
              entry: recent[i],
              index: i,
              organizing: organizing,
              organizeAnimation: organizeAnimation,
              onIncidentTap: onIncidentTap,
              onCollectionTap: onCollectionTap,
              onIncidentLongPress: onIncidentLongPress,
              onOrganizeRemove: onOrganizeRemove,
              onIncidentDrop: onIncidentDrop,
              onCollectionDrop: onCollectionDrop,
            ),
          ],
        ],
        if (archivedIncidents.isNotEmpty) ...[
          if (recent.isNotEmpty) const SizedBox(height: AppSpacing.lg),
          Text(
            'Archive',
            style: AppTextStyles.heading.copyWith(
              color: AppColors.onCanvas,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (var i = 0; i < archivedIncidents.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.xs),
            LibraryIncidentSummaryTile(
              incident: archivedIncidents[i],
              onTap: () => onIncidentTap(archivedIncidents[i]),
              onRestore: onRestore == null
                  ? null
                  : () => onRestore!(archivedIncidents[i]),
            ),
          ],
        ],
      ],
      ),
    ),
    );
  }
}

class _VaultRecentRow extends StatelessWidget {
  const _VaultRecentRow({
    required this.entry,
    required this.index,
    required this.organizing,
    required this.organizeAnimation,
    required this.onIncidentTap,
    required this.onCollectionTap,
    required this.onIncidentLongPress,
    required this.onOrganizeRemove,
    required this.onIncidentDrop,
    required this.onCollectionDrop,
  });

  final VaultRecentEntry entry;
  final int index;
  final bool organizing;
  final Animation<double> organizeAnimation;
  final ValueChanged<LibraryIncidentSummary> onIncidentTap;
  final ValueChanged<IncidentCollection> onCollectionTap;
  final VoidCallback onIncidentLongPress;
  final VoidCallback onOrganizeRemove;
  final void Function(String sourceIncidentId, String targetIncidentId)
      onIncidentDrop;
  final void Function(String sourceIncidentId, String collectionId)
      onCollectionDrop;

  @override
  Widget build(BuildContext context) {
    switch (entry) {
      case VaultRecentCollectionEntry(:final collection):
        final members = resolveCollectionMembers(
          memberIncidentIds: collection.memberIncidentIds,
          summaries: IncidentLibraryService.instance.summaries,
        );
        final organized = VaultOrganizeModule(
          incidentId: collection.id,
          organizing: organizing,
          animation: organizeAnimation,
          phase: index * 0.85,
          onRemove: onOrganizeRemove,
          child: VaultCollectionModule(
            collection: collection,
            members: members,
            onTap: organizing ? null : () => onCollectionTap(collection),
          ),
        );
        if (!organizing) {
          return organized;
        }
        return VaultCollectionOrganizeSlot(
          collectionId: collection.id,
          onIncidentDropped: onCollectionDrop,
          child: organized,
        );
      case VaultRecentIncidentEntry(:final incident):
        final tile = VaultIncidentModule(
          incident: incident,
          onTap: () => onIncidentTap(incident),
          onLongPress: organizing ? null : onIncidentLongPress,
        );
        final organized = VaultOrganizeModule(
          incidentId: incident.id,
          organizing: organizing,
          animation: organizeAnimation,
          phase: index * 0.85,
          onRemove: onOrganizeRemove,
          child: tile,
        );
        if (!organizing) {
          return organized;
        }
        return VaultIncidentOrganizeSlot(
          incidentId: incident.id,
          onDroppedOn: onIncidentDrop,
          child: organized,
        );
    }
  }
}

class _EmptyVault extends StatelessWidget {
  const _EmptyVault({this.showMemoryExplanation = false});

  final bool showMemoryExplanation;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
        vertical: AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'The Library of Truth',
            style: AppTextStyles.heroTitle,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Your permanent repository of preserved truth records '
            'will live here.',
            style: AppTextStyles.body.copyWith(
              color: AppColors.onCanvasSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (showMemoryExplanation)
            MemoryRecallSection(
              items: const [],
              showEmptyExplanation: true,
              onAction: (_) {},
              onDismiss: (_) {},
            ),
          const Spacer(),
          LayeredCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Every library begins with one piece of truth.',
                  style: AppTextStyles.label.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Preserved incidents will appear here as soon as you '
                  'capture your first piece of evidence.',
                  style: AppTextStyles.bodySmall.copyWith(height: 1.5),
                ),
              ],
            ),
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }
}
