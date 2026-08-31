import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../domain/organize/organize_readiness.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'product_concept_chart.dart';

/// Presentation copy derived from an existing [OrganizeReadiness] snapshot.
///
/// Kept for assessment-copy tests. The Information section no longer
/// displays this incident-specific copy.
abstract final class OrganizeReadinessCopy {
  static const compositionLabel = 'Evidence composition';
  static const structureLabel = 'Chronological / contextual structure';
  static const nextStepLabel = 'Useful next step';
  static const readyHeadline = 'Ready to organize';
  static const readyBody =
      'Your record has enough material to organize.';
  static const notReadyHeadline = 'Not yet ready to organize';
  static const notReadyBody =
      'Additional supporting context would strengthen this record '
      'before organizing.';
  static const unevaluableHeadline =
      'Readiness could not be determined yet.';
  static const compositionLead = 'Your record currently includes:';
  static const sequenceMatters =
      'Some evidence combinations are stronger when they form a '
      'meaningful sequence or surrounding context.';
  static const sequenceMet =
      'Your supporting records currently form a useful sequence.';
  static const contextMet =
      'Your records currently provide useful surrounding context.';

  static String compositionBody(OrganizeReadiness readiness) {
    return '$compositionLead\n${readiness.composition.summary}';
  }

  static String structureBody(OrganizeReadiness readiness) {
    final parts = <String>[sequenceMatters];
    if (readiness.isReady) {
      parts.add(
        _hasSequenceRequirement(readiness) ? sequenceMet : contextMet,
      );
      final example = readiness.matchedExample?.structure.trim();
      if (example != null && example.isNotEmpty) {
        parts.add(example);
      }
    } else {
      final summary = readiness.structureSummary.trim();
      if (summary.isNotEmpty) {
        parts.add(summary);
      }
    }
    return parts.join('\n\n');
  }

  static String? nextStep(OrganizeReadiness? readiness) {
    if (readiness == null || readiness.isReady) {
      return null;
    }
    final hint = readiness.nextUsefulMaterial?.trim();
    if (hint == null || hint.isEmpty) {
      return null;
    }
    return hint;
  }

  /// Sequence-sensitive combinations already described by assess() examples.
  static bool _hasSequenceRequirement(OrganizeReadiness readiness) {
    return readiness.matchedExample?.structure.contains('→') ?? false;
  }
}

/// ⓘ that opens the product-level Information guide.
class OrganizeReadinessInfoButton extends StatelessWidget {
  const OrganizeReadinessInfoButton({
    super.key,
    this.iconColor = AppColors.onCanvasSecondary,
  });

  final Color iconColor;

  static const Key buttonKey = Key('organize_readiness_info');

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: IconButton(
        key: buttonKey,
        onPressed: () => showOrganizeReadinessGuide(context: context),
        tooltip: ProductConceptCopy.title,
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        icon: _InfoMark(color: iconColor),
      ),
    );
  }
}

class _InfoMark extends StatelessWidget {
  const _InfoMark({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 1.35),
        ),
        child: Center(
          child: Text(
            'i',
            style: TextStyle(
              fontSize: 12.5,
              height: 1,
              fontWeight: FontWeight.w500,
              fontStyle: FontStyle.italic,
              fontFamily: 'Georgia',
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showOrganizeReadinessGuide({
  required BuildContext context,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      return const OrganizeReadinessGuideSheet();
    },
  );
}

/// Product-guide Information surface. Never an incident summary.
class OrganizeReadinessGuideSheet extends StatelessWidget {
  const OrganizeReadinessGuideSheet({super.key});

  static const Key sheetKey = Key('organize_readiness_guide');
  static const Key compositionKey = Key('organize_readiness_composition');
  static const Key structureKey = Key('organize_readiness_structure');
  static const Key statusKey = Key('organize_readiness_status');
  static const Key nextStepKey = Key('organize_readiness_next_step');

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return SafeArea(
      key: sheetKey,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.lg + bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.82,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderAccent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                ProductConceptCopy.title,
                style: AppTextStyles.heading.copyWith(fontSize: 20),
              ),
              const SizedBox(height: 4),
              Text(
                ProductConceptCopy.caption,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              const Expanded(
                child: SingleChildScrollView(
                  child: ProductConceptChart(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
