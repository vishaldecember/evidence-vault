import 'package:flutter/material.dart';

import '../../theme/app_motion.dart';

/// Preserves scroll and selection state while cross-fading between tabs.
///
/// Only visited tabs are kept mounted — inactive unvisited slots stay empty so
/// opening Investigation does not build Timeline + Connections + Reconstruction
/// on the first frame.
class InvestigationWorkspaceTabStack extends StatelessWidget {
  const InvestigationWorkspaceTabStack({
    super.key,
    required this.activeIndex,
    required this.children,
    this.visitedIndexes,
  });

  final int activeIndex;
  final List<Widget> children;

  /// When set, unvisited indexes render as empty placeholders.
  final Set<int>? visitedIndexes;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        for (var index = 0; index < children.length; index++)
          IgnorePointer(
            ignoring: index != activeIndex,
            child: AnimatedOpacity(
              opacity: index != activeIndex ? 0 : 1,
              duration: AppMotion.medium,
              curve: AppMotion.enter,
              child: Offstage(
                offstage: index != activeIndex,
                child: (visitedIndexes == null || visitedIndexes!.contains(index))
                    ? children[index]
                    : const SizedBox.shrink(),
              ),
            ),
          ),
      ],
    );
  }
}
