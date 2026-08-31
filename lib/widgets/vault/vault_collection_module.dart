import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../domain/vault/incident_collection.dart';
import '../../presentation/incident_cover_resolver.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_styles.dart';
import 'collection_member_resolution.dart';
import 'incident_cover_preview.dart';

/// Vault module for a user-created Incident Collection.
///
/// Spatial stack of member covers — not an Incident and not an AI pattern.
class VaultCollectionModule extends StatefulWidget {
  const VaultCollectionModule({
    super.key,
    required this.collection,
    this.members = const [],
    this.onTap,
    this.coverOverrides,
  });

  final IncidentCollection collection;
  final List<CollectionMemberView> members;
  final VoidCallback? onTap;

  /// Test seam. Production resolves through [IncidentCoverResolver].
  final List<IncidentCoverResolution>? coverOverrides;

  static Key moduleKey(String collectionId) =>
      Key('vault_collection_module_$collectionId');

  static const typeLabel = 'COLLECTION';
  static const int visualSample = 3;

  @override
  State<VaultCollectionModule> createState() => _VaultCollectionModuleState();
}

class _VaultCollectionModuleState extends State<VaultCollectionModule> {
  List<IncidentCoverResolution> _covers = const [];

  @override
  void initState() {
    super.initState();
    _covers = widget.coverOverrides ??
        List<IncidentCoverResolution>.filled(
          VaultCollectionModule.visualSample,
          IncidentCoverResolution.fallback,
        );
    if (widget.coverOverrides == null) {
      _resolveCovers();
    }
  }

  @override
  void didUpdateWidget(VaultCollectionModule oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.coverOverrides != null) {
      _covers = widget.coverOverrides!;
      return;
    }
    if (oldWidget.collection.id != widget.collection.id ||
        oldWidget.members.length != widget.members.length) {
      _resolveCovers();
    }
  }

  Future<void> _resolveCovers() async {
    final sample = widget.members.take(VaultCollectionModule.visualSample);
    final next = <IncidentCoverResolution>[];
    for (final member in sample) {
      final summary = member.summary;
      if (summary == null) {
        next.add(IncidentCoverResolution.fallback);
        continue;
      }
      next.add(
        await IncidentCoverResolver.resolve(
          incidentId: summary.id,
          coverEvidenceId: summary.coverEvidenceId,
        ),
      );
    }
    while (next.length < VaultCollectionModule.visualSample) {
      next.add(IncidentCoverResolution.fallback);
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _covers = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.collection.count;
    final incidentWord = count == 1 ? 'incident' : 'incidents';
    final title = widget.collection.title.trim().isEmpty
        ? 'Collection'
        : widget.collection.title.trim();
    return Semantics(
      button: widget.onTap != null,
      label: '$title, collection, $count $incidentWord',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
          child: ExcludeSemantics(
            child: Ink(
              key: VaultCollectionModule.moduleKey(widget.collection.id),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.sm,
              ),
              decoration: AppDecorations.innerTile(
                backgroundColor: AppColors.surfaceMuted,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IgnorePointer(
                    child: _CoverStack(
                      members: widget.members,
                      covers: _covers,
                      count: count,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    VaultCollectionModule.typeLabel,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.navy.withValues(alpha: 0.55),
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                      letterSpacing: 1.1,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.label.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$count $incidentWord',
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

class _CoverStack extends StatelessWidget {
  const _CoverStack({
    required this.members,
    required this.covers,
    required this.count,
  });

  final List<CollectionMemberView> members;
  final List<IncidentCoverResolution> covers;
  final int count;

  static const _frameHeight = 52.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: Stack(
        children: [
          for (var i = 2; i >= 0; i--)
            Positioned(
              left: i * 8.0,
              right: (2 - i) * 8.0,
              top: (2 - i) * 8.0,
              height: _frameHeight,
              child: _StackFrame(
                resolution: i < covers.length
                    ? covers[i]
                    : IncidentCoverResolution.fallback,
                label: _labelFor(i),
                depth: i,
              ),
            ),
        ],
      ),
    );
  }

  String? _labelFor(int index) {
    if (index >= members.length) {
      return count > index ? null : '';
    }
    final summary = members[index].summary;
    if (summary == null) {
      return null;
    }
    final title = summary.title.trim();
    return title.isEmpty ? 'Untitled' : title;
  }
}

class _StackFrame extends StatelessWidget {
  const _StackFrame({
    required this.resolution,
    required this.label,
    required this.depth,
  });

  final IncidentCoverResolution resolution;
  final String? label;
  final int depth;

  @override
  Widget build(BuildContext context) {
    final empty = label != null && label!.isEmpty;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.border.withValues(alpha: 0.85),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.06 + (depth * 0.02)),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: resolution.hasThumbnail
            ? IncidentCoverPreview.band(
                incidentId: 'stack-$depth',
                resolution: resolution,
                height: _CoverStack._frameHeight,
              )
            : ColoredBox(
                color: empty ? AppColors.cardStackDeep : AppColors.card,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      label == null ? '—' : (empty ? '' : label!),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.navy.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
