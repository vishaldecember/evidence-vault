import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../models/evidence_record_model.dart';
import '../../models/workspace_evidence_item.dart';
import '../../presentation/evidence_inspector_semantics.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../common/silver_lustre_text.dart';

/// Quiet section label — typography, not a card header.
class InspectorSectionLabel extends StatelessWidget {
  const InspectorSectionLabel(
    this.text, {
    super.key,
    this.authored = false,
  });

  final String text;
  final bool authored;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTextStyles.caption.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.35,
        color: authored
            ? AppColors.onCanvasSecondary.withValues(alpha: 0.88)
            : AppColors.onCanvasSecondary.withValues(alpha: 0.72),
      ),
    );
  }
}

class InspectorFactRow extends StatelessWidget {
  const InspectorFactRow({
    super.key,
    required this.label,
    required this.value,
    this.valueKey,
    this.semanticLabel,
    this.valueWidget,
  });

  final String label;
  final String value;
  final Key? valueKey;
  final String? semanticLabel;
  final Widget? valueWidget;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel ?? 'Fact. $label. $value',
      child: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 108,
              child: SilverLustreText(
                label,
                style: AppTextStyles.caption.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
            Expanded(
              child: valueWidget ??
                  SilverLustreText(
                    value,
                    key: valueKey,
                    style: AppTextStyles.label.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Evidence type and incident association — identity, not forensic IDs.
class InspectorIdentitySection extends StatelessWidget {
  const InspectorIdentitySection({
    super.key,
    required this.evidence,
    required this.incidentTitle,
  });

  final WorkspaceEvidenceItem evidence;
  final String incidentTitle;

  @override
  Widget build(BuildContext context) {
    final title = incidentTitle.trim();
    return Semantics(
      container: true,
      label: title.isEmpty
          ? 'Evidence identity. ${evidence.kind.label}'
          : 'Evidence identity. ${evidence.kind.label}. Incident $title',
      child: Column(
        key: const Key('evidence_inspector_identity'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            evidence.kind.label,
            style: AppTextStyles.heading.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.25,
              height: 1.2,
              color: AppColors.onCanvas,
            ),
          ),
          if (title.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(
                fontSize: 13,
                height: 1.35,
                color: AppColors.onCanvasSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Evidence type and capture pathway. Never invents a modality.
class InspectorFactsSection extends StatelessWidget {
  const InspectorFactsSection({
    super.key,
    required this.record,
  });

  final EvidenceRecordModel record;

  @override
  Widget build(BuildContext context) {
    final evidence = record.evidence;
    final fileSize = record.metadata.fileSize;
    final duration = record.metadata.duration;
    final modality = EvidenceInspectorSemantics.captureModality(evidence);

    return Semantics(
      container: true,
      label: EvidenceInspectorSemantics.evidenceHeader,
      child: Column(
        key: const Key('evidence_inspector_facts'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const InspectorSectionLabel(EvidenceInspectorSemantics.evidenceHeader),
          InspectorFactRow(
            label: EvidenceInspectorSemantics.typeLabel,
            value: evidence.kind.label,
          ),
          InspectorFactRow(
            label: EvidenceInspectorSemantics.captureModalityLabel,
            value: modality,
            valueKey: const Key('evidence_inspector_capture_modality'),
            semanticLabel:
                'Fact. ${EvidenceInspectorSemantics.captureModalityLabel}. $modality',
          ),
          if (fileSize != null)
            InspectorFactRow(label: 'File size', value: fileSize),
          if (duration != null)
            InspectorFactRow(label: 'Duration', value: duration),
        ],
      ),
    );
  }
}

/// Existing `sequenceOrder` chronology. Never invents InspectorOrder.
class InspectorChronologySection extends StatelessWidget {
  const InspectorChronologySection({
    super.key,
    required this.position,
    this.priorObservationCaption,
  });

  final EvidenceChronologyPosition? position;

  /// Derived record-time relation. Never event time or causality.
  final String? priorObservationCaption;

  static const Key priorObservationKey =
      Key('evidence_inspector_prior_observation');

  @override
  Widget build(BuildContext context) {
    final resolved = position;
    final headline = resolved?.headline ??
        EvidenceInspectorSemantics.chronologyUnsupported;
    final detail = resolved?.positionLine;

    final prior = priorObservationCaption?.trim();
    final hasPrior = prior != null && prior.isNotEmpty;
    return Semantics(
      container: true,
      label: resolved == null
          ? 'Chronology. ${EvidenceInspectorSemantics.chronologyUnsupported}'
              '${hasPrior ? '. $prior' : ''}'
          : 'Chronology. ${resolved.headline}. ${resolved.positionLine}'
              '${hasPrior ? '. $prior' : ''}',
      child: Column(
        key: const Key('evidence_inspector_chronology'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const InspectorSectionLabel(
            EvidenceInspectorSemantics.chronologyHeader,
          ),
          const SizedBox(height: 6),
          Text(
            headline,
            key: const Key('evidence_inspector_chronology_headline'),
            style: AppTextStyles.label.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.onCanvas,
            ),
          ),
          if (detail != null) ...[
            const SizedBox(height: 2),
            Text(
              detail,
              style: AppTextStyles.caption.copyWith(
                fontSize: 12,
                color: AppColors.onCanvasSecondary,
              ),
            ),
          ],
          if (prior != null && prior.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              prior,
              key: priorObservationKey,
              style: AppTextStyles.caption.copyWith(
                fontSize: 12,
                color: AppColors.onCanvasSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Quiet digital integrity — preserved original only.
class InspectorIntegritySection extends StatelessWidget {
  const InspectorIntegritySection({super.key, required this.evidence});

  final WorkspaceEvidenceItem evidence;

  @override
  Widget build(BuildContext context) {
    final hashStatus = EvidenceInspectorSemantics.fingerprintStatus(evidence);
    return Semantics(
      container: true,
      label:
          'Integrity. ${EvidenceInspectorSemantics.originalPreserved}. $hashStatus',
      child: Column(
        key: const Key('evidence_inspector_integrity_section'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const InspectorSectionLabel(
            EvidenceInspectorSemantics.integrityHeader,
          ),
          const InspectorFactRow(
            label: EvidenceInspectorSemantics.originalLabel,
            value: EvidenceInspectorSemantics.originalPreserved,
            valueKey: Key('evidence_inspector_original'),
          ),
          InspectorFactRow(
            label: EvidenceInspectorSemantics.hashStatusLabel,
            value: hashStatus,
            valueKey: const Key('evidence_inspector_hash_status'),
          ),
        ],
      ),
    );
  }
}

class InspectorProvenanceSection extends StatelessWidget {
  const InspectorProvenanceSection({
    super.key,
    required this.evidence,
  });

  final WorkspaceEvidenceItem evidence;

  @override
  Widget build(BuildContext context) {
    final clocks = EvidenceInspectorSemantics.instants(evidence);
    final source = EvidenceInspectorSemantics.sourceLabelValue(evidence);
    final location = EvidenceInspectorSemantics.locationLabelValue(evidence);

    return Semantics(
      container: true,
      label: EvidenceInspectorSemantics.provenanceHeader,
      child: Column(
        key: const Key('evidence_inspector_provenance'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const InspectorSectionLabel(
            EvidenceInspectorSemantics.provenanceHeader,
          ),
          InspectorFactRow(
            label: EvidenceInspectorSemantics.sourceLabel,
            value: source,
            valueKey: const Key('evidence_inspector_source'),
          ),
          for (var i = 0; i < clocks.length; i++)
            InspectorFactRow(
              label: clocks[i].label,
              value: clocks[i].formatted,
              valueKey: i == 0
                  ? const Key('evidence_inspector_timestamp')
                  : Key('evidence_inspector_timestamp_$i'),
              semanticLabel:
                  'Fact. ${clocks[i].label}. ${clocks[i].formatted}',
            ),
          InspectorFactRow(
            label: EvidenceInspectorSemantics.locationLabel,
            value: location,
            valueKey: const Key('evidence_inspector_location'),
            valueWidget: location == EvidenceInspectorSemantics.locationUnavailable
                ? Text(
                    location,
                    key: const Key('evidence_inspector_location'),
                    style: AppTextStyles.label.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.warning,
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

class InspectorVerificationSection extends StatelessWidget {
  const InspectorVerificationSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label:
          '${EvidenceInspectorSemantics.verificationHeader}. ${EvidenceInspectorSemantics.verifiedLabel}',
      child: Column(
        key: const Key('evidence_inspector_verification'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const InspectorSectionLabel(
            EvidenceInspectorSemantics.verificationHeader,
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              key: const Key('evidence_inspector_integrity'),
              children: [
                const Icon(
                  Icons.check,
                  size: 18,
                  color: AppColors.success,
                ),
                const SizedBox(width: 6),
                SilverLustreText(
                  EvidenceInspectorSemantics.verifiedLabel,
                  style: AppTextStyles.label.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class InspectorQuietDivider extends StatelessWidget {
  const InspectorQuietDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Divider(
        height: 1,
        thickness: 1,
        color: AppColors.onCanvas.withValues(alpha: 0.22),
      ),
    );
  }
}

/// Shown for Organize context after it is snapped to a captured moment.
class InspectorLinkedOrganizeMomentSection extends StatelessWidget {
  const InspectorLinkedOrganizeMomentSection({
    super.key,
    required this.linked,
  });

  static const Key sectionKey = Key('evidence_inspector_linked_organize_moment');
  static const String header = 'Linked moment';

  final WorkspaceEvidenceItem linked;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '$header. ${linked.kind.label}',
      child: Column(
        key: sectionKey,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const InspectorSectionLabel(header),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'This context is linked to ${linked.kind.label}.',
              style: AppTextStyles.caption.copyWith(
                fontSize: 13,
                color: AppColors.onCanvasSecondary,
                height: 1.3,
              ),
            ),
          ),
          InspectorFactRow(
            label: 'Evidence',
            value: linked.kind.label,
            valueKey: Key('evidence_inspector_linked_moment_${linked.id}'),
          ),
        ],
      ),
    );
  }
}
