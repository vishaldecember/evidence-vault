import 'package:flutter/material.dart';

import '../../../constants/app_spacing.dart';
import '../../../domain/trust_package/trust_package_integrity_provenance.dart';
import '../../../presentation/evidence_inspector_semantics.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../utils/workspace_evidence_formatters.dart';

/// Integrity & Provenance body for the existing Trust Pack document.
class TrustPackageIntegrityProvenanceView extends StatelessWidget {
  const TrustPackageIntegrityProvenanceView({
    super.key,
    required this.section,
  });

  static const Key sectionKey = Key('trust_pack_integrity_provenance');
  static const Key packStatusKey = Key('trust_pack_integrity_status');
  static const Key independentVerificationKey =
      Key('trust_pack_independent_verification');

  static Key itemStatusKey(String evidenceId) =>
      Key('trust_pack_integrity_status_$evidenceId');

  static Key historyKey(String evidenceId) =>
      Key('trust_pack_evidence_history_$evidenceId');

  static Key detailsKey(String evidenceId) =>
      Key('trust_pack_integrity_details_$evidenceId');

  static Key sha256Key(String evidenceId) =>
      Key('trust_pack_sha256_$evidenceId');

  final TrustPackageIntegrityProvenanceSection section;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: TrustPackIntegrityLabels.sectionTitle,
      child: Column(
        key: sectionKey,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PackStatus(section: section),
          const SizedBox(height: AppSpacing.lg),
          if (section.entries.isEmpty)
            Text(
              TrustPackIntegrityLabels.unavailableExplanation,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
                height: 1.6,
              ),
            )
          else
            for (var index = 0; index < section.entries.length; index++) ...[
              if (index > 0) const SizedBox(height: AppSpacing.md),
              _EvidenceIntegrityCard(entry: section.entries[index]),
            ],
        ],
      ),
    );
  }
}

class _PackStatus extends StatelessWidget {
  const _PackStatus({required this.section});

  final TrustPackageIntegrityProvenanceSection section;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(section.mismatchCount > 0
        ? TrustPackIntegrityState.mismatch
        : section.reportsEntirePackVerified
            ? TrustPackIntegrityState.verified
            : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          section.packStatusLabel,
          key: TrustPackageIntegrityProvenanceView.packStatusKey,
          style: AppTextStyles.label.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: color,
            height: 1.3,
          ),
        ),
        if (section.packStatusSecondary != null) ...[
          const SizedBox(height: AppSpacing.xxs),
          Text(
            section.packStatusSecondary!,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xs),
        Text(
          section.scopeCaption,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textSecondary,
            height: 1.45,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          section.packStatusExplanation,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
            height: 1.55,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _FactLine(
          label: TrustPackIntegrityLabels.independentVerification,
          value: TrustPackIntegrityLabels.independentNotPerformed,
          valueKey:
              TrustPackageIntegrityProvenanceView.independentVerificationKey,
        ),
      ],
    );
  }
}

class _EvidenceIntegrityCard extends StatelessWidget {
  const _EvidenceIntegrityCard({required this.entry});

  final TrustPackageIntegrityProvenanceEntry entry;

  @override
  Widget build(BuildContext context) {
    final hash = entry.contentHash;
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
            entry.title,
            style: AppTextStyles.label.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            entry.statusLabel,
            key: TrustPackageIntegrityProvenanceView.itemStatusKey(
              entry.evidenceId,
            ),
            style: AppTextStyles.bodySmall.copyWith(
              fontWeight: FontWeight.w700,
              color: _statusColor(entry.state),
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            entry.statusExplanation,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _FactLine(
            label: 'Original',
            value: entry.originalPreservationLabel,
          ),
          if (entry.capturedAt != null)
            _FactLine(
              label: TrustPackIntegrityLabels.captured,
              value: WorkspaceEvidenceFormatters.inspectorTimestamp(
                entry.capturedAt!,
              ),
            ),
          if (entry.preservedAt != null)
            _FactLine(
              label: TrustPackIntegrityLabels.preserved,
              value: WorkspaceEvidenceFormatters.inspectorTimestamp(
                entry.preservedAt!,
              ),
            ),
          if (entry.source != null)
            _FactLine(
              label: TrustPackIntegrityLabels.source,
              value: entry.source!,
            ),
          if (entry.captureModality != null)
            _FactLine(
              label: TrustPackIntegrityLabels.captureModality,
              value: entry.captureModality!,
            ),
          _FactLine(
            label: TrustPackIntegrityLabels.location,
            value: entry.locationDisplay,
          ),
          if (entry.history.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            _QuietExpansion(
              key: TrustPackageIntegrityProvenanceView.historyKey(
                entry.evidenceId,
              ),
              title: TrustPackIntegrityLabels.evidenceHistory,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final event in entry.history)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
                      child: Text(
                        '${WorkspaceEvidenceFormatters.evidenceClockTime(event.at)}   ${event.label}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textPrimary,
                          height: 1.45,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (hash != null) ...[
            const SizedBox(height: AppSpacing.xxs),
            _QuietExpansion(
              key: TrustPackageIntegrityProvenanceView.detailsKey(
                entry.evidenceId,
              ),
              title: TrustPackIntegrityLabels.integrityDetails,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    TrustPackIntegrityLabels.sha256Fingerprint,
                    style: AppTextStyles.caption.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    EvidenceInspectorSemantics.hashPreview(hash),
                    style: AppTextStyles.bodySmall.copyWith(
                      fontFamily: 'monospace',
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  SelectableText(
                    hash,
                    key: TrustPackageIntegrityProvenanceView.sha256Key(
                      entry.evidenceId,
                    ),
                    style: AppTextStyles.bodySmall.copyWith(
                      fontFamily: 'monospace',
                      height: 1.4,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _QuietExpansion extends StatefulWidget {
  const _QuietExpansion({
    super.key,
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  State<_QuietExpansion> createState() => _QuietExpansionState();
}

class _QuietExpansionState extends State<_QuietExpansion> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: AppTextStyles.bodySmall.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.navy,
                    ),
                  ),
                ),
                Icon(
                  _expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: widget.child,
          ),
      ],
    );
  }
}

class _FactLine extends StatelessWidget {
  const _FactLine({
    required this.label,
    required this.value,
    this.valueKey,
  });

  final String label;
  final String value;
  final Key? valueKey;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
      child: RichText(
        key: valueKey,
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

Color _statusColor(TrustPackIntegrityState? state) {
  return switch (state) {
    TrustPackIntegrityState.verified => AppColors.navy,
    TrustPackIntegrityState.mismatch => AppColors.danger,
    TrustPackIntegrityState.recorded ||
    TrustPackIntegrityState.fingerprintUnavailable =>
      AppColors.textSecondary,
    null => AppColors.navy,
  };
}
