import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../constants/app_spacing.dart';
import '../../../domain/trust_package/trust_package.dart';
import '../../../services/trust_package_scorecard_service.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_decorations.dart';
import '../../../theme/app_text_styles.dart';
import '../../../utils/workspace_evidence_formatters.dart';
import '../../common/layered_card.dart';
import '../../common/status_badge.dart';
import 'trust_package_integrity_provenance_section.dart';

enum TrustPackagePreviewSection {
  cover('Cover'),
  executiveSummary('Executive Summary'),
  scorecard('Investigation Quality'),
  timeline('Timeline'),
  relationships('Relationships'),
  narrative('Narrative'),
  evidenceAppendix('Evidence Appendix'),
  integrityProvenance('Integrity & Provenance'),
  integrity('Integrity Report');

  const TrustPackagePreviewSection(this.label);

  final String label;
}

/// Document-style read-only Trust Package preview.
class TrustPackagePreview extends StatefulWidget {
  const TrustPackagePreview({
    super.key,
    required this.package,
    this.onEvidenceSelected,
    this.sectionKeys,
    this.showNavigation = true,
    this.printLayout = false,
  });

  final TrustPackage package;
  final ValueChanged<String>? onEvidenceSelected;
  final Map<TrustPackagePreviewSection, GlobalKey>? sectionKeys;
  final bool showNavigation;
  final bool printLayout;

  @override
  State<TrustPackagePreview> createState() => _TrustPackagePreviewState();
}

class _TrustPackagePreviewState extends State<TrustPackagePreview> {
  late final Map<TrustPackagePreviewSection, GlobalKey> _sectionKeys;

  @override
  void initState() {
    super.initState();
    _sectionKeys = widget.sectionKeys ??
        {
          for (final section in TrustPackagePreviewSection.values)
            section: GlobalKey(),
        };
  }

  void scrollToSection(TrustPackagePreviewSection section) {
    final context = _sectionKeys[section]?.currentContext;
    if (context == null) {
      return;
    }
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      alignment: 0.0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final quality =
        TrustPackageScorecardService.evaluate(widget.package);
    final appendixById = {
      for (final entry in widget.package.evidenceAppendix.entries)
        entry.evidenceId: entry,
    };
    final groupsById = {
      for (final group in widget.package.relationshipGroupsSection.groups)
        group.groupId: group,
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final useSideNavigation = constraints.maxWidth >= 920;
        final document = _TrustPackageDocument(
          package: widget.package,
          quality: quality,
          appendixById: appendixById,
          groupsById: groupsById,
          sectionKeys: _sectionKeys,
          onEvidenceSelected: widget.onEvidenceSelected,
          printLayout: widget.printLayout,
        );

        if (!widget.showNavigation) {
          return document;
        }

        if (!useSideNavigation) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TrustPackagePreviewNavigation(
                onSectionSelected: scrollToSection,
                axis: Axis.horizontal,
              ),
              Expanded(child: document),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: document),
            TrustPackagePreviewNavigation(
              onSectionSelected: scrollToSection,
              axis: Axis.vertical,
            ),
          ],
        );
      },
    );
  }
}

class TrustPackagePreviewNavigation extends StatelessWidget {
  const TrustPackagePreviewNavigation({
    super.key,
    required this.onSectionSelected,
    required this.axis,
  });

  final ValueChanged<TrustPackagePreviewSection> onSectionSelected;
  final Axis axis;

  @override
  Widget build(BuildContext context) {
    final sections = TrustPackagePreviewSection.values;

    final chips = [
      for (final section in sections)
        _NavigationLink(
          label: section == TrustPackagePreviewSection.scorecard
              ? 'Investigation Quality'
              : section.label,
          onTap: () => onSectionSelected(section),
        ),
    ];

    if (axis == Axis.vertical) {
      return Container(
        width: 176,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: AppColors.background,
          border: Border(
            left: BorderSide(color: AppColors.border.withValues(alpha: 0.8)),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Contents',
              style: AppTextStyles.caption.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            ...chips,
          ],
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenHorizontal,
          AppSpacing.xs,
          AppSpacing.screenHorizontal,
          AppSpacing.sm,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.88)),
            boxShadow: AppDecorations.cardShadows,
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            child: Row(
              children: [
                for (var index = 0; index < chips.length; index++) ...[
                  if (index > 0) const SizedBox(width: AppSpacing.xxs),
                  chips[index],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavigationLink extends StatelessWidget {
  const _NavigationLink({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: AppSpacing.xxs,
          ),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.navy,
            fontWeight: FontWeight.w600,
          ),
          softWrap: true,
          maxLines: 2,
        ),
      ),
    );
  }
}

class _TrustPackageDocument extends StatelessWidget {
  const _TrustPackageDocument({
    required this.package,
    required this.quality,
    required this.appendixById,
    required this.groupsById,
    required this.sectionKeys,
    required this.onEvidenceSelected,
    this.printLayout = false,
  });

  final TrustPackage package;
  final TrustPackageInvestigationQuality quality;
  final Map<String, TrustPackageEvidenceAppendixEntry> appendixById;
  final Map<String, TrustPackageRelationshipGroupEntry> groupsById;
  final Map<TrustPackagePreviewSection, GlobalKey> sectionKeys;
  final ValueChanged<String>? onEvidenceSelected;
  final bool printLayout;

  @override
  Widget build(BuildContext context) {
    final document = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SectionAnchor(
                  sectionKey: sectionKeys[TrustPackagePreviewSection.cover]!,
                  child: _CoverPageSection(summary: package.incidentSummary,
                      metadata: package.metadata),
                ),
                const _DocumentDivider(),
                _SectionAnchor(
                  sectionKey:
                      sectionKeys[TrustPackagePreviewSection.executiveSummary]!,
                  child: _ExecutiveSummarySection(package: package),
                ),
                const _DocumentDivider(),
                _SectionAnchor(
                  sectionKey:
                      sectionKeys[TrustPackagePreviewSection.scorecard]!,
                  child: _ScorecardSection(quality: quality),
                ),
                const _DocumentDivider(),
                _SectionAnchor(
                  sectionKey: sectionKeys[TrustPackagePreviewSection.timeline]!,
                  child: _TimelineSection(
                    section: package.timelineSection,
                    groupsById: groupsById,
                  ),
                ),
                const _DocumentDivider(),
                _SectionAnchor(
                  sectionKey:
                      sectionKeys[TrustPackagePreviewSection.relationships]!,
                  child: _RelationshipGroupsSection(
                    section: package.relationshipGroupsSection,
                    appendixById: appendixById,
                    onEvidenceSelected: onEvidenceSelected,
                  ),
                ),
                const _DocumentDivider(),
                _SectionAnchor(
                  sectionKey: sectionKeys[TrustPackagePreviewSection.narrative]!,
                  child: _ReconstructionSection(
                    section: package.reconstructionSection,
                    appendixById: appendixById,
                    onEvidenceSelected: onEvidenceSelected,
                  ),
                ),
                const _DocumentDivider(),
                _SectionAnchor(
                  sectionKey:
                      sectionKeys[TrustPackagePreviewSection.evidenceAppendix]!,
                  child: _EvidenceAppendixSection(
                    section: package.evidenceAppendix,
                    groupsById: groupsById,
                    onEvidenceSelected: onEvidenceSelected,
                  ),
                ),
                const _DocumentDivider(),
                _SectionAnchor(
                  sectionKey: sectionKeys[
                      TrustPackagePreviewSection.integrityProvenance]!,
                  child: _DocumentSection(
                    title: TrustPackIntegrityLabels.sectionTitle,
                    child: TrustPackageIntegrityProvenanceView(
                      section: package.integrityProvenance,
                    ),
                  ),
                ),
                const _DocumentDivider(),
                _SectionAnchor(
                  sectionKey: sectionKeys[TrustPackagePreviewSection.integrity]!,
                  child: _IntegrityReportSection(
                    summary: package.integritySummary,
                    quality: quality,
                  ),
                ),
              ],
    );

    return ColoredBox(
      color: printLayout ? Colors.white : Colors.transparent,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          printLayout ? 56 : AppSpacing.screenHorizontal,
          printLayout ? 40 : AppSpacing.lg,
          printLayout ? 56 : AppSpacing.screenHorizontal,
          printLayout ? 56 : AppSpacing.xxl,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: printLayout ? 720 : 760,
            ),
            child: printLayout
                ? document
                : LayeredCard(
                    elevated: true,
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: document,
                  ),
          ),
        ),
      ),
    );
  }
}

class _SectionAnchor extends StatelessWidget {
  const _SectionAnchor({
    required this.sectionKey,
    required this.child,
  });

  final GlobalKey sectionKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KeyedSubtree(
          key: sectionKey,
          child: const SizedBox(width: double.infinity, height: 1),
        ),
        child,
      ],
    );
  }
}

class _DocumentDivider extends StatelessWidget {
  const _DocumentDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Divider(color: AppColors.border.withValues(alpha: 0.85), height: 1),
    );
  }
}

class _CoverPageSection extends StatelessWidget {
  const _CoverPageSection({
    required this.summary,
    required this.metadata,
  });

  final TrustPackageIncidentSummary summary;
  final TrustPackageMetadata metadata;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Trust Package',
          style: AppTextStyles.heading.copyWith(
            fontSize: 22,
            height: 1.2,
            fontWeight: FontWeight.w800,
            color: AppColors.navy,
            letterSpacing: -0.35,
          ),
          softWrap: true,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          summary.incidentName,
          style: AppTextStyles.bodySmall.copyWith(
            fontSize: 15,
            height: 1.35,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
            letterSpacing: 0,
          ),
          softWrap: true,
        ),
        const SizedBox(height: AppSpacing.lg),
        _CoverFact(label: 'Incident Type', value: summary.incidentType),
        _CoverFact(label: 'Incident Status', value: summary.incidentStatus),
        _CoverFact(
          label: 'Generated Date',
          value: DateFormat('d MMMM yyyy • HH:mm').format(metadata.generatedAt),
        ),
        _CoverFact(label: 'Generated By', value: metadata.generatedBy),
        _CoverFact(label: 'Trust Package Version', value: metadata.packageVersion),
        _CoverFact(
          label: 'Investigation Confidence',
          value: summary.investigationConfidence,
          status: IncidentStatus.tryParse(summary.investigationConfidence),
        ),
        _CoverFact(
          label: 'Reconstruction Health',
          value: summary.reconstructionHealth,
          status: IncidentStatus.tryParse(summary.reconstructionHealth),
        ),
      ],
    );
  }
}

class _CoverFact extends StatelessWidget {
  const _CoverFact({
    required this.label,
    required this.value,
    this.status,
  });

  final String label;
  final String value;
  final IncidentStatus? status;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: Text(
                  label,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                  softWrap: true,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                flex: 6,
                child: status != null
                    ? Align(
                        alignment: Alignment.centerLeft,
                        child: StatusBadge(status: status!),
                      )
                    : Text(
                        value,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textPrimary,
                          height: 1.45,
                        ),
                        softWrap: true,
                      ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Divider(color: AppColors.border.withValues(alpha: 0.85), height: 1),
        ],
      ),
    );
  }
}

class _ExecutiveSummarySection extends StatelessWidget {
  const _ExecutiveSummarySection({required this.package});

  final TrustPackage package;

  @override
  Widget build(BuildContext context) {
    final stats = package.investigationSummary;
    return _DocumentSection(
      title: 'Executive Summary',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SummaryBlock(
            heading: 'Incident Summary',
            body:
                '${package.incidentSummary.incidentName} is recorded as '
                '${package.incidentSummary.incidentStatus.toLowerCase()} '
                'with ${stats.primaryChronologyStatement}. '
                '${stats.structuralSupportStatement}.',
          ),
          _SummaryBlock(
            heading: 'Timeline Summary',
            body:
                '${stats.timelineAnchorCount} timeline anchors preserve the '
                'chronological sequence of the incident.',
          ),
          _SummaryBlock(
            heading: 'Relationship Summary',
            body:
                '${stats.relationshipGroupCount} relationship groups connect '
                'related evidence items.',
          ),
          _SummaryBlock(
            heading: 'Narrative Summary',
            body:
                '${stats.narrativeEventCount} narrative events document the '
                'investigator reconstruction.',
          ),
          _SummaryBlock(
            heading: 'Evidence Statistics',
            body: '${stats.recordedContextStatement}. '
                '${stats.witnessCount} witness-kind records and '
                '${stats.documentCount} note or document items are listed by type.',
          ),
        ],
      ),
    );
  }
}

class _SummaryBlock extends StatelessWidget {
  const _SummaryBlock({required this.heading, required this.body});

  final String heading;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            heading,
            style: AppTextStyles.label.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            body,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              height: 1.65,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Divider(color: AppColors.border.withValues(alpha: 0.9), height: 1),
        ],
      ),
    );
  }
}

class _ScorecardSection extends StatelessWidget {
  const _ScorecardSection({required this.quality});

  final TrustPackageInvestigationQuality quality;

  @override
  Widget build(BuildContext context) {
    final ratingColor = switch (quality.overallRating) {
      TrustPackageQualityRating.excellent => AppColors.success,
      TrustPackageQualityRating.good => AppColors.success,
      TrustPackageQualityRating.needsReview => AppColors.warning,
      TrustPackageQualityRating.incomplete => AppColors.danger,
    };

    return _DocumentSection(
      title: 'Investigation Quality',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            quality.overallRating.label,
            style: AppTextStyles.label.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: ratingColor,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final indicator in quality.indicators)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _ScorecardRow(indicator: indicator),
            ),
        ],
      ),
    );
  }
}

class _ScorecardRow extends StatelessWidget {
  const _ScorecardRow({required this.indicator});

  final TrustPackageQualityIndicator indicator;

  @override
  Widget build(BuildContext context) {
    final color = indicator.isMet ? AppColors.success : AppColors.warning;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          indicator.isMet ? Icons.check_circle_rounded : Icons.info_rounded,
          size: 18,
          color: color,
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                indicator.label,
                style: AppTextStyles.bodySmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                indicator.statusLabel,
                style: AppTextStyles.caption.copyWith(color: color),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TimelineSection extends StatelessWidget {
  const _TimelineSection({
    required this.section,
    required this.groupsById,
  });

  final TrustPackageTimelineSection section;
  final Map<String, TrustPackageRelationshipGroupEntry> groupsById;

  @override
  Widget build(BuildContext context) {
    return _DocumentSection(
      title: 'Chronological Timeline',
      child: section.entries.isEmpty
          ? const _EmptySectionMessage(
              message: 'No timeline anchors are included in this package.',
            )
          : Column(
              children: [
                for (var index = 0; index < section.entries.length; index++) ...[
                  if (index > 0) const SizedBox(height: AppSpacing.md),
                  _TimelineEntryCard(
                    entry: section.entries[index],
                    groupsById: groupsById,
                  ),
                ],
              ],
            ),
    );
  }
}

class _TimelineEntryCard extends StatelessWidget {
  const _TimelineEntryCard({
    required this.entry,
    required this.groupsById,
  });

  final TrustPackageTimelineEntry entry;
  final Map<String, TrustPackageRelationshipGroupEntry> groupsById;

  @override
  Widget build(BuildContext context) {
    final group = entry.relationshipGroupIds.isEmpty
        ? null
        : groupsById[entry.relationshipGroupIds.first];
    final groupLabel = group?.groupName ??
        (entry.relationshipGroupIds.isEmpty
            ? 'No relationship group'
            : 'Relationship group referenced');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border.withValues(alpha: 0.85)),
        borderRadius: BorderRadius.circular(AppSpacing.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            WorkspaceEvidenceFormatters.preservedTimestamp(entry.timestamp),
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            entry.title,
            style: AppTextStyles.label.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _FactLine(
            label: 'Related Evidence',
            value: '${entry.relatedEvidenceIds.length}',
          ),
          _FactLine(label: 'Relationship Group', value: groupLabel),
          _FactLine(
            label: 'Confidence',
            value: group?.confidenceLevel ?? 'Not assessed',
          ),
        ],
      ),
    );
  }
}

class _RelationshipGroupsSection extends StatelessWidget {
  const _RelationshipGroupsSection({
    required this.section,
    required this.appendixById,
    required this.onEvidenceSelected,
  });

  final TrustPackageRelationshipGroupsSection section;
  final Map<String, TrustPackageEvidenceAppendixEntry> appendixById;
  final ValueChanged<String>? onEvidenceSelected;

  @override
  Widget build(BuildContext context) {
    return _DocumentSection(
      title: 'Relationship Groups',
      child: section.groups.isEmpty
          ? const _EmptySectionMessage(
              message: 'No relationship groups are included in this package.',
            )
          : Column(
              children: [
                for (var index = 0; index < section.groups.length; index++) ...[
                  if (index > 0) const SizedBox(height: AppSpacing.md),
                  _RelationshipGroupCard(
                    group: section.groups[index],
                    appendixById: appendixById,
                    onEvidenceSelected: onEvidenceSelected,
                  ),
                ],
              ],
            ),
    );
  }
}

class _RelationshipGroupCard extends StatelessWidget {
  const _RelationshipGroupCard({
    required this.group,
    required this.appendixById,
    required this.onEvidenceSelected,
  });

  final TrustPackageRelationshipGroupEntry group;
  final Map<String, TrustPackageEvidenceAppendixEntry> appendixById;
  final ValueChanged<String>? onEvidenceSelected;

  Color get _color {
    final hex = group.colorHex.replaceFirst('#', '');
    final value = int.tryParse(hex, radix: 16) ?? 0xFF3B36F4;
    return Color(value);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border.withValues(alpha: 0.85)),
        borderRadius: BorderRadius.circular(AppSpacing.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: _color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  group.groupName,
                  style: AppTextStyles.label.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _FactLine(label: 'Confidence', value: group.confidenceLevel),
          _FactLine(label: 'Validation Status', value: group.validationStatus),
          const SizedBox(height: AppSpacing.sm),
          _EvidenceThumbnailRow(
            evidenceIds: group.memberEvidenceIds,
            appendixById: appendixById,
            onEvidenceSelected: onEvidenceSelected,
          ),
        ],
      ),
    );
  }
}

class _ReconstructionSection extends StatelessWidget {
  const _ReconstructionSection({
    required this.section,
    required this.appendixById,
    required this.onEvidenceSelected,
  });

  final TrustPackageReconstructionSection section;
  final Map<String, TrustPackageEvidenceAppendixEntry> appendixById;
  final ValueChanged<String>? onEvidenceSelected;

  @override
  Widget build(BuildContext context) {
    return _DocumentSection(
      title: 'Reconstruction Narrative',
      child: section.events.isEmpty
          ? const _EmptySectionMessage(
              message: 'No narrative events are included in this package.',
            )
          : Column(
              children: [
                for (var index = 0; index < section.events.length; index++) ...[
                  if (index > 0) const SizedBox(height: AppSpacing.md),
                  _NarrativeEventCard(
                    event: section.events[index],
                    appendixById: appendixById,
                    onEvidenceSelected: onEvidenceSelected,
                  ),
                ],
              ],
            ),
    );
  }
}

class _NarrativeEventCard extends StatelessWidget {
  const _NarrativeEventCard({
    required this.event,
    required this.appendixById,
    required this.onEvidenceSelected,
  });

  final TrustPackageReconstructionEventEntry event;
  final Map<String, TrustPackageEvidenceAppendixEntry> appendixById;
  final ValueChanged<String>? onEvidenceSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border.withValues(alpha: 0.85)),
        borderRadius: BorderRadius.circular(AppSpacing.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            event.title,
            style: AppTextStyles.label.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
          if (event.summary?.trim().isNotEmpty ?? false) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              event.summary!.trim(),
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
                height: 1.6,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          _FactLine(label: 'Confidence', value: event.confidence),
          _FactLine(label: 'Validation Status', value: event.validationStatus),
          const SizedBox(height: AppSpacing.sm),
          _EvidenceThumbnailRow(
            evidenceIds: event.evidenceReferenceIds,
            appendixById: appendixById,
            onEvidenceSelected: onEvidenceSelected,
          ),
        ],
      ),
    );
  }
}

class _EvidenceAppendixSection extends StatelessWidget {
  const _EvidenceAppendixSection({
    required this.section,
    required this.groupsById,
    required this.onEvidenceSelected,
  });

  final TrustPackageEvidenceAppendix section;
  final Map<String, TrustPackageRelationshipGroupEntry> groupsById;
  final ValueChanged<String>? onEvidenceSelected;

  @override
  Widget build(BuildContext context) {
    return _DocumentSection(
      title: 'Evidence Appendix',
      child: section.entries.isEmpty
          ? const _EmptySectionMessage(
              message: 'No evidence items are included in this package.',
            )
          : Column(
              children: [
                for (var index = 0; index < section.entries.length; index++) ...[
                  if (index > 0) const SizedBox(height: AppSpacing.sm),
                  _EvidenceAppendixCard(
                    entry: section.entries[index],
                    groupsById: groupsById,
                    onTap: onEvidenceSelected == null
                        ? null
                        : () => onEvidenceSelected!(section.entries[index].evidenceId),
                  ),
                ],
              ],
            ),
    );
  }
}

class _EvidenceAppendixCard extends StatelessWidget {
  const _EvidenceAppendixCard({
    required this.entry,
    required this.groupsById,
    required this.onTap,
  });

  final TrustPackageEvidenceAppendixEntry entry;
  final Map<String, TrustPackageRelationshipGroupEntry> groupsById;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final groupNames = [
      for (final groupId in entry.relationshipGroupIds)
        groupsById[groupId]?.groupName ?? groupId,
    ];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border.withValues(alpha: 0.85)),
            borderRadius: BorderRadius.circular(AppSpacing.sm),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _EvidenceTypeThumbnail(evidenceType: entry.evidenceType),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      style: AppTextStyles.label.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    _FactLine(label: 'Type', value: entry.evidenceType),
                    _FactLine(
                      label: 'Timestamp',
                      value: WorkspaceEvidenceFormatters.preservedTimestamp(
                        entry.timestamp,
                      ),
                    ),
                    if (entry.device != null)
                      _FactLine(label: 'Device', value: entry.device!),
                    if (entry.location != null)
                      _FactLine(label: 'Location', value: entry.location!),
                    if (entry.context != null)
                      _FactLine(label: 'Context', value: entry.context!),
                    _FactLine(
                      label: 'Relationship Groups',
                      value: groupNames.isEmpty
                          ? 'None'
                          : groupNames.join(', '),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IntegrityReportSection extends StatelessWidget {
  const _IntegrityReportSection({
    required this.summary,
    required this.quality,
  });

  final TrustPackageIntegritySummary summary;
  final TrustPackageInvestigationQuality quality;

  @override
  Widget build(BuildContext context) {
    final evidenceIntegrity = summary.missingReferences.isEmpty
        ? 'References present'
        : 'Review required';
    final narrativeCompleteness = quality.indicators
        .firstWhere(
          (entry) =>
              entry.label == TrustPackageScorecardService.narrativeReferencesLabel,
        )
        .statusLabel;
    final referenceCompleteness = summary.missingReferences.isEmpty
        ? 'Verified'
        : 'Unverified';

    return _DocumentSection(
      title: 'Integrity Report',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FactLine(
            label: 'Timeline Integrity',
            value: TrustPackageScorecardService.integrityStatusLabel(
              summary.timelineIntegrity,
            ),
          ),
          _FactLine(
            label: 'Relationship Integrity',
            value: TrustPackageScorecardService.integrityStatusLabel(
              summary.relationshipIntegrity,
            ),
          ),
          _FactLine(label: 'Evidence Integrity', value: evidenceIntegrity),
          _FactLine(
            label: 'Narrative references verified',
            value: narrativeCompleteness,
          ),
          _FactLine(label: 'Validation Status', value: summary.validationStatus),
          _FactLine(
            label: 'References verified',
            value: referenceCompleteness,
          ),
          if (summary.missingReferences.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'Missing References',
              style: AppTextStyles.label.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            for (final reference in summary.missingReferences)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
                child: Text(
                  '• $reference',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.warning,
                    height: 1.5,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _EvidenceThumbnailRow extends StatelessWidget {
  const _EvidenceThumbnailRow({
    required this.evidenceIds,
    required this.appendixById,
    required this.onEvidenceSelected,
  });

  final List<String> evidenceIds;
  final Map<String, TrustPackageEvidenceAppendixEntry> appendixById;
  final ValueChanged<String>? onEvidenceSelected;

  @override
  Widget build(BuildContext context) {
    if (evidenceIds.isEmpty) {
      return Text(
        'No evidence references',
        style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
      );
    }

    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final evidenceId in evidenceIds)
          if (appendixById[evidenceId] != null)
            _EvidenceTypeThumbnail(
              evidenceType: appendixById[evidenceId]!.evidenceType,
              onTap: onEvidenceSelected == null
                  ? null
                  : () => onEvidenceSelected!(evidenceId),
            ),
      ],
    );
  }
}

class _EvidenceTypeThumbnail extends StatelessWidget {
  const _EvidenceTypeThumbnail({
    required this.evidenceType,
    this.onTap,
  });

  final String evidenceType;
  final VoidCallback? onTap;

  IconData get _icon {
    final normalized = evidenceType.toLowerCase();
    if (normalized.contains('photo') || normalized.contains('image')) {
      return Icons.photo_outlined;
    }
    if (normalized.contains('video')) {
      return Icons.videocam_outlined;
    }
    if (normalized.contains('voice')) {
      return Icons.mic_outlined;
    }
    if (normalized.contains('witness')) {
      return Icons.person_outline_rounded;
    }
    return Icons.description_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceMuted,
      borderRadius: BorderRadius.circular(AppSpacing.xs),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.xs),
        child: SizedBox(
          width: 52,
          height: 52,
          child: Icon(_icon, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

class _DocumentSection extends StatelessWidget {
  const _DocumentSection({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTextStyles.heading.copyWith(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.navy,
            letterSpacing: -0.3,
            height: 1.25,
          ),
          softWrap: true,
        ),
        const SizedBox(height: AppSpacing.xs),
        Container(
          width: 36,
          height: 2,
          decoration: BoxDecoration(
            color: AppColors.navy.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        child,
      ],
    );
  }
}

class _FactLine extends StatelessWidget {
  const _FactLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
      child: RichText(
        text: TextSpan(
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
            height: 1.45,
          ),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

class _EmptySectionMessage extends StatelessWidget {
  const _EmptySectionMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: AppTextStyles.bodySmall.copyWith(
        color: AppColors.textMuted,
        height: 1.6,
      ),
    );
  }
}
