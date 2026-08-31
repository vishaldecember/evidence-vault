import 'package:flutter/material.dart';

import '../../theme/app_text_styles.dart';

/// Compact label/value row shared across Evidence Record pillars.
class EvidenceRecordInfoRow extends StatelessWidget {
  const EvidenceRecordInfoRow({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(label, style: AppTextStyles.caption),
        ),
        Expanded(
          child: Text(
            value,
            style: AppTextStyles.label.copyWith(fontSize: 14),
          ),
        ),
      ],
    );
  }
}
