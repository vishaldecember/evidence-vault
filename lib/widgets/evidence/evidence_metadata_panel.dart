import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../models/evidence_metadata.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/evidence_formatters.dart';

class EvidenceMetadataPanel extends StatelessWidget {
  const EvidenceMetadataPanel({
    super.key,
    required this.metadata,
    required this.fileSizeBytes,
  });

  final EvidenceMetadata metadata;
  final int fileSizeBytes;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Evidence metadata', style: AppTextStyles.heading),
          const SizedBox(height: AppSpacing.sm),
          _MetadataRow(
            label: 'Evidence ID',
            value: metadata.evidenceId,
          ),
          _MetadataRow(
            label: 'Timestamp',
            value: EvidenceFormatters.timestamp(
              metadata.capturedAt,
              timezone: metadata.timezone,
            ),
          ),
          _MetadataRow(
            label: 'Location',
            value: EvidenceFormatters.coordinates(
              metadata.location.latitude,
              metadata.location.longitude,
            ),
          ),
          if (metadata.location.accuracyMeters != null)
            _MetadataRow(
              label: 'Accuracy',
              value: '${metadata.location.accuracyMeters!.toStringAsFixed(1)} m',
            ),
          _MetadataRow(
            label: 'Device',
            value: metadata.device.name,
          ),
          _MetadataRow(
            label: 'Platform',
            value: metadata.device.platform,
          ),
          _MetadataRow(
            label: 'File size',
            value: EvidenceFormatters.fileSize(fileSizeBytes),
          ),
        ],
      ),
    );
  }
}

class _MetadataRow extends StatelessWidget {
  const _MetadataRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(label, style: AppTextStyles.caption),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.label.copyWith(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
