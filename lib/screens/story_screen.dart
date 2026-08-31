import 'package:flutter/material.dart';

import '../constants/app_spacing.dart';
import '../models/story_model.dart';
import '../models/workspace_evidence_item.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/common/app_back_button.dart';
import '../widgets/story/story_renderer.dart';

/// Dedicated reading view for the assembled incident story.
class StoryScreen extends StatelessWidget {
  const StoryScreen({
    super.key,
    required this.getStory,
    required this.getAllItems,
    required this.onEvidenceSelected,
  });

  final StoryModel Function() getStory;
  final List<WorkspaceEvidenceItem> Function() getAllItems;
  final ValueChanged<WorkspaceEvidenceItem> onEvidenceSelected;

  @override
  Widget build(BuildContext context) {
    final story = getStory();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: const AppBackButton(),
        title: Text('Story', style: AppTextStyles.screenTitle),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenHorizontal,
            AppSpacing.sm,
            AppSpacing.screenHorizontal,
            AppSpacing.xl,
          ),
          child: StoryRenderer(
            story: story,
            allItems: getAllItems(),
            onEvidenceSelected: onEvidenceSelected,
          ),
        ),
      ),
    );
  }
}
