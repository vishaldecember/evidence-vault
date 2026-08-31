import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../common/section_divider.dart';
import '../workspace/workspace_card.dart';

/// Reading-focused section shell for the Trust Package preview.
class TrustPackageSection extends StatelessWidget {
  const TrustPackageSection({
    super.key,
    required this.title,
    required this.child,
    this.caption,
  });

  final String title;
  final String? caption;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WorkspaceSectionHeader(title: title, caption: caption),
        const SizedBox(height: AppSpacing.md),
        child,
      ],
    );
  }
}

/// Subtle divider between major trust package sections.
typedef TrustPackageSectionDivider = SectionDivider;
