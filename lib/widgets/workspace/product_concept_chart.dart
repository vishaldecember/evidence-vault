import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'evidence_composition_guide.dart';

/// Product-level conceptual model. Never an incident summary.
abstract final class ProductConceptCopy {
  static const title = 'Information';
  static const caption =
      'A product guide to stages and views. Not a summary of any incident.';

  static const captureTitle = 'CAPTURE';
  static const captureEquation = 'preserve';
  static const captureBody =
      'Preserve what is happening. Capture creates the trustworthy '
      'underlying records.';

  static const organizeTitle = 'ORGANIZE';
  static const organizeEquation = 'structure and contextualize';
  static const organizeBody =
      'Understand and structure the preserved record. Organize does not '
      'modify preserved evidence.';
  static const organizeChronology = 'Evidence chronology';
  static const organizeContext = 'Context';
  static const organizeGroups = 'Groups';
  static const organizeContextDetail =
      'Floating context can be associated with preserved moments. '
      'Authored context does not become captured evidence. A context '
      'timestamp records when it was authored, not when an event occurred. '
      'Placement does not change chronology.';

  static const groupsTitle = 'GROUPS';
  static const groupsQuote = 'These records belong together.';
  static const groupsBody =
      'Groups are evidence collections. They organize records without '
      'asserting a relationship or causal explanation.';

  static const investigateTitle = 'INVESTIGATE';
  static const investigateEquation = 'understand relationships';
  static const investigateBody =
      'Understand the situation represented by the evidence.';
  static const investigateTimeline = 'Timeline';
  static const investigateGraph = 'Graph / situation flow';
  static const investigateConnections = 'Connections';
  static const investigateReconstruction = 'Reconstruction';

  static const connectionsTitle = 'CONNECTIONS';
  static const connectionsQuote = 'These things are related.';
  static const connectionsBody =
      'Connections express a meaningful relationship between entities, '
      'events, or evidence. A connection is stronger and more specific than '
      'simple group membership. It is not automatically a finding of fact.';

  static const reconstructTitle = 'RECONSTRUCTION';
  static const reconstructEquation = 'form the supported account';
  static const reconstructBody =
      'Assemble the supported understanding of what happened. '
      'Reconstruction is not presented as fact when the evidence does not '
      'establish it. It is not automatically truth.';

  static const distinctionCapture = 'CAPTURE = preserve';
  static const distinctionOrganize = 'ORGANIZE = structure and contextualize';
  static const distinctionInvestigate = 'INVESTIGATE = understand relationships';
  static const distinctionReconstruct = 'RECONSTRUCT = form the supported account';
}

/// Visual Capture → Organize → Investigate → Reconstruct product chart.
class ProductConceptChart extends StatelessWidget {
  const ProductConceptChart({super.key});

  static const Key chartKey = Key('product_concept_chart');
  static const Key captureKey = Key('product_concept_capture');
  static const Key organizeKey = Key('product_concept_organize');
  static const Key groupsKey = Key('product_concept_groups');
  static const Key investigateKey = Key('product_concept_investigate');
  static const Key connectionsKey = Key('product_concept_connections');
  static const Key reconstructKey = Key('product_concept_reconstruction');
  static const Key distinctionKey = Key('product_concept_distinction');

  @override
  Widget build(BuildContext context) {
    return Column(
      key: chartKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StageCard(
          key: captureKey,
          title: ProductConceptCopy.captureTitle,
          equation: ProductConceptCopy.captureEquation,
          body: ProductConceptCopy.captureBody,
        ),
        const _FlowDown(),
        _StageCard(
          key: organizeKey,
          title: ProductConceptCopy.organizeTitle,
          equation: ProductConceptCopy.organizeEquation,
          body: ProductConceptCopy.organizeBody,
          branches: const [
            ProductConceptCopy.organizeChronology,
            ProductConceptCopy.organizeContext,
            ProductConceptCopy.organizeGroups,
          ],
          footnote: ProductConceptCopy.organizeContextDetail,
        ),
        const SizedBox(height: AppSpacing.md),
        const EvidenceCompositionGuide(),
        const SizedBox(height: AppSpacing.sm),
        _QuoteCard(
          key: groupsKey,
          title: ProductConceptCopy.groupsTitle,
          quote: ProductConceptCopy.groupsQuote,
          body: ProductConceptCopy.groupsBody,
        ),
        const _FlowDown(),
        _StageCard(
          key: investigateKey,
          title: ProductConceptCopy.investigateTitle,
          equation: ProductConceptCopy.investigateEquation,
          body: ProductConceptCopy.investigateBody,
          branches: const [
            ProductConceptCopy.investigateTimeline,
            ProductConceptCopy.investigateGraph,
            ProductConceptCopy.investigateConnections,
            ProductConceptCopy.investigateReconstruction,
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        _QuoteCard(
          key: connectionsKey,
          title: ProductConceptCopy.connectionsTitle,
          quote: ProductConceptCopy.connectionsQuote,
          body: ProductConceptCopy.connectionsBody,
        ),
        const SizedBox(height: AppSpacing.sm),
        _StageCard(
          key: reconstructKey,
          title: ProductConceptCopy.reconstructTitle,
          equation: ProductConceptCopy.reconstructEquation,
          body: ProductConceptCopy.reconstructBody,
        ),
        const SizedBox(height: AppSpacing.md),
        _DistinctionBlock(
          key: distinctionKey,
          lines: const [
            ProductConceptCopy.distinctionCapture,
            ProductConceptCopy.distinctionOrganize,
            ProductConceptCopy.distinctionInvestigate,
            ProductConceptCopy.distinctionReconstruct,
          ],
        ),
      ],
    );
  }
}

class _FlowDown extends StatelessWidget {
  const _FlowDown();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Icon(
        Icons.south_rounded,
        size: 16,
        color: AppColors.navy.withValues(alpha: 0.45),
      ),
    );
  }
}

class _StageCard extends StatelessWidget {
  const _StageCard({
    super.key,
    required this.title,
    required this.equation,
    required this.body,
    this.branches = const [],
    this.footnote,
  });

  final String title;
  final String equation;
  final String body;
  final List<String> branches;
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppTextStyles.label.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: AppColors.navy,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              equation,
              style: AppTextStyles.caption.copyWith(
                fontWeight: FontWeight.w600,
                fontStyle: FontStyle.italic,
                color: AppColors.primary,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              body,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
            if (branches.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final branch in branches) _BranchChip(label: branch),
                ],
              ),
            ],
            if (footnote != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                footnote!,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textMuted,
                  height: 1.35,
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BranchChip extends StatelessWidget {
  const _BranchChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.55)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          label,
          style: AppTextStyles.caption.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.navy,
            height: 1.15,
          ),
        ),
      ),
    );
  }
}

class _QuoteCard extends StatelessWidget {
  const _QuoteCard({
    super.key,
    required this.title,
    required this.quote,
    required this.body,
  });

  final String title;
  final String quote;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.md),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
          border: Border(
            left: BorderSide(
              color: AppColors.primary.withValues(alpha: 0.35),
              width: 2.5,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.caption.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                quote,
                style: AppTextStyles.bodySmall.copyWith(
                  fontWeight: FontWeight.w600,
                  fontStyle: FontStyle.italic,
                  color: AppColors.navy,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                body,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DistinctionBlock extends StatelessWidget {
  const _DistinctionBlock({super.key, required this.lines});

  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < lines.length; i++) ...[
              if (i > 0) const SizedBox(height: 4),
              Text(
                lines[i],
                style: AppTextStyles.bodySmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.navy,
                  height: 1.3,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
