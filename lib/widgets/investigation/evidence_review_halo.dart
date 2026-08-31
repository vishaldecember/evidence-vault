import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';

/// Evidence IDs the Investigation Coach asked Review to halo.
class CoachReviewHaloScope extends InheritedWidget {
  const CoachReviewHaloScope({
    super.key,
    required this.evidenceIds,
    required super.child,
  });

  final Set<String> evidenceIds;

  static Set<String> of(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<CoachReviewHaloScope>()
            ?.evidenceIds ??
        const {};
  }

  static bool highlights(BuildContext context, String evidenceId) {
    return of(context).contains(evidenceId);
  }

  @override
  bool updateShouldNotify(CoachReviewHaloScope oldWidget) {
    return evidenceIds != oldWidget.evidenceIds;
  }
}

/// Soft cool atmospheric halo — no border, no fill change.
class EvidenceReviewHalo extends StatefulWidget {
  const EvidenceReviewHalo({
    super.key,
    required this.evidenceId,
    required this.child,
    this.ensureVisible = false,
  });

  final String evidenceId;
  final Widget child;
  final bool ensureVisible;

  @override
  State<EvidenceReviewHalo> createState() => _EvidenceReviewHaloState();
}

class _EvidenceReviewHaloState extends State<EvidenceReviewHalo> {
  bool _didScroll = false;

  bool get _active => CoachReviewHaloScope.highlights(context, widget.evidenceId);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleScrollIfNeeded();
  }

  @override
  void didUpdateWidget(covariant EvidenceReviewHalo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.evidenceId != widget.evidenceId) {
      _didScroll = false;
    }
    _scheduleScrollIfNeeded();
  }

  void _scheduleScrollIfNeeded() {
    if (!widget.ensureVisible || !_active || _didScroll) {
      return;
    }
    _didScroll = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_active) {
        return;
      }
      Scrollable.ensureVisible(
        context,
        alignment: 0.2,
        duration: AppMotion.medium,
        curve: AppMotion.enter,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final active = _active;
    return AnimatedContainer(
      duration: AppMotion.medium,
      curve: AppMotion.enter,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: active
            ? [
                BoxShadow(
                  color: AppColors.canvasHaloCore.withValues(alpha: 0.42),
                  blurRadius: 22,
                  spreadRadius: 3,
                ),
                BoxShadow(
                  color: AppColors.canvasGlow.withValues(alpha: 0.28),
                  blurRadius: 32,
                  spreadRadius: 1,
                ),
              ]
            : const [],
      ),
      child: widget.child,
    );
  }
}
