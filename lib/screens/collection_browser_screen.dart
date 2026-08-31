import 'package:flutter/material.dart';

import '../constants/app_spacing.dart';
import '../controllers/workspace_session.dart';
import '../domain/vault/incident_collection.dart';
import '../models/library_incident_summary.dart';
import '../navigation/app_navigation.dart';
import '../services/persistence/incident_library_service.dart';
import '../services/vault/incident_collection_store.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/common/app_back_button.dart';
import '../widgets/common/app_snackbar.dart';
import '../widgets/common/space_canvas.dart';
import '../widgets/home/library_incident_summary_tile.dart';
import '../widgets/vault/collection_member_resolution.dart';

/// Browses member Incidents of one [IncidentCollection].
///
/// Resolves IDs through [IncidentLibraryService]. Does not own or mutate
/// Incidents, Evidence, or collection membership.
class CollectionBrowserScreen extends StatefulWidget {
  const CollectionBrowserScreen({
    super.key,
    required this.collectionId,
    required this.userId,
    this.initialCollection,
    this.store,
    this.onIncidentOpen,
  });

  final String collectionId;
  final String userId;
  final IncidentCollection? initialCollection;
  final IncidentCollectionStore? store;
  final ValueChanged<LibraryIncidentSummary>? onIncidentOpen;

  static const routeName = 'collection-browser';

  static Key screenKey(String collectionId) =>
      Key('collection_browser_$collectionId');

  static const emptyKey = Key('collection_browser_empty');
  static const errorKey = Key('collection_browser_error');
  static const loadingKey = Key('collection_browser_loading');
  static const retryKey = Key('collection_browser_retry');

  static Key unavailableMemberKey(String incidentId) =>
      Key('collection_member_unavailable_$incidentId');

  @override
  State<CollectionBrowserScreen> createState() => _CollectionBrowserScreenState();
}

class _CollectionBrowserScreenState extends State<CollectionBrowserScreen> {
  IncidentCollection? _collection;
  var _loading = true;
  var _loadFailed = false;

  IncidentCollectionStore get _store =>
      widget.store ?? IncidentCollectionStore.instance;

  @override
  void initState() {
    super.initState();
    _collection = widget.initialCollection;
    _loading = _collection == null;
    IncidentLibraryService.instance.addListener(_onLibraryChanged);
    _loadCollection();
  }

  @override
  void dispose() {
    IncidentLibraryService.instance.removeListener(_onLibraryChanged);
    super.dispose();
  }

  void _onLibraryChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadCollection() async {
    setState(() {
      _loading = _collection == null;
      _loadFailed = false;
    });
    try {
      final loaded = await _store.get(
        userId: widget.userId,
        collectionId: widget.collectionId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _collection = loaded ?? _collection;
        _loadFailed = loaded == null;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadFailed = _collection == null;
        _loading = false;
      });
    }
  }

  Future<void> _openMember(LibraryIncidentSummary incident) async {
    final incidentId = incident.id.trim();
    if (incidentId.isEmpty) {
      return;
    }
    if (widget.onIncidentOpen != null) {
      widget.onIncidentOpen!(incident);
      return;
    }
    final opened = await WorkspaceSession.instance.openIncident(incidentId);
    if (!mounted) {
      return;
    }
    if (!opened) {
      AppSnackBar.showSuccess(
        context,
        'Couldn’t open that incident yet. Try again.',
      );
      return;
    }
    await AppNavigation.openIncidentWorkspaceFromLibrary(context);
  }

  @override
  Widget build(BuildContext context) {
    final collection = _collection;
    final title = collection == null
        ? 'Collection'
        : (collection.title.trim().isEmpty
            ? 'Collection'
            : collection.title.trim());
    final count = collection?.count ?? 0;
    final incidentWord = count == 1 ? 'incident' : 'incidents';

    return SpaceCanvas(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: const AppBackButton(color: AppColors.onCanvas),
          title: Text(
            title,
            style: AppTextStyles.screenTitle.copyWith(
              color: AppColors.onCanvas,
            ),
          ),
        ),
        body: SafeArea(
          child: KeyedSubtree(
            key: CollectionBrowserScreen.screenKey(widget.collectionId),
            child: _body(
              collection: collection,
              countLabel: '$count $incidentWord',
            ),
          ),
        ),
      ),
    );
  }

  Widget _body({
    required IncidentCollection? collection,
    required String countLabel,
  }) {
    if (_loading) {
      return const Center(
        key: CollectionBrowserScreen.loadingKey,
        child: CircularProgressIndicator(
          strokeWidth: 2.2,
          color: AppColors.onCanvas,
        ),
      );
    }
    if (_loadFailed && collection == null) {
      return _ErrorState(onRetry: _loadCollection);
    }
    if (collection == null) {
      return _ErrorState(onRetry: _loadCollection);
    }
    if (collection.memberIncidentIds.isEmpty) {
      return _EmptyState(countLabel: countLabel);
    }

    return ListenableBuilder(
      listenable: IncidentLibraryService.instance,
      builder: (context, _) {
        final members = resolveCollectionMembers(
          memberIncidentIds: collection.memberIncidentIds,
          summaries: IncidentLibraryService.instance.summaries,
        );
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenHorizontal,
            AppSpacing.sm,
            AppSpacing.screenHorizontal,
            AppSpacing.xl,
          ),
          itemCount: members.length + 1,
          separatorBuilder: (context, index) =>
              const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, index) {
            if (index == 0) {
              return _BrowserHeader(countLabel: countLabel);
            }
            return _MemberRow(
              member: members[index - 1],
              onOpen: _openMember,
            );
          },
        );
      },
    );
  }
}

class _BrowserHeader extends StatelessWidget {
  const _BrowserHeader({required this.countLabel});

  final String countLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'COLLECTION',
          style: AppTextStyles.caption.copyWith(
            color: AppColors.onCanvasSecondary,
            fontWeight: FontWeight.w700,
            fontSize: 10,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          countLabel,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.onCanvasSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.member,
    required this.onOpen,
  });

  final CollectionMemberView member;
  final ValueChanged<LibraryIncidentSummary> onOpen;

  @override
  Widget build(BuildContext context) {
    final summary = member.summary;
    if (summary == null) {
      return Semantics(
        label: 'Unavailable incident',
        child: Material(
          color: Colors.transparent,
          child: Ink(
            key: CollectionBrowserScreen.unavailableMemberKey(member.incidentId),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: AppColors.card.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
              border: Border.all(
                color: AppColors.border.withValues(alpha: 0.6),
              ),
            ),
            child: Text(
              'Unavailable incident',
              style: AppTextStyles.label.copyWith(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );
    }
    return LibraryIncidentSummaryTile(
      incident: summary,
      onTap: () => onOpen(summary),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.countLabel});

  final String countLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: CollectionBrowserScreen.emptyKey,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
        vertical: AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BrowserHeader(countLabel: countLabel),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'No incidents in this collection',
            style: AppTextStyles.body.copyWith(
              color: AppColors.onCanvasSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: CollectionBrowserScreen.errorKey,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
        vertical: AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Couldn’t load this collection.',
            style: AppTextStyles.body.copyWith(
              color: AppColors.onCanvasSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextButton(
            key: CollectionBrowserScreen.retryKey,
            onPressed: onRetry,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.onCanvas,
              minimumSize: const Size(48, 48),
            ),
            child: Text(
              'Retry',
              style: AppTextStyles.label.copyWith(
                color: AppColors.onCanvas,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
