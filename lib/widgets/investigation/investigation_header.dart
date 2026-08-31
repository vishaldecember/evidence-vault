import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../models/journey_stage.dart';
import '../../services/narrative_validation_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_text_styles.dart';
import '../common/layered_card.dart';
import '../common/status_badge.dart';
import 'investigation_workspace_navigation_header.dart';

/// Shared investigation header — identical across Timeline, Connections,
/// and Reconstruction workspaces.
///
/// Visual dashboard for incident health. Presentation only — no persistence
/// or investigation logic beyond forwarding the inline title edit callback.
class InvestigationHeader extends StatelessWidget {
  const InvestigationHeader({
    super.key,
    required this.incidentName,
    required this.journeyStage,
    required this.timelineAnchorCount,
    required this.relationshipGroupCount,
    required this.narrativeEventCount,
    required this.reconstructionHealth,
    this.onIncidentNameChanged,
  });

  final String incidentName;
  final JourneyStage journeyStage;
  final int timelineAnchorCount;
  final int relationshipGroupCount;
  final int narrativeEventCount;
  final NarrativeReconstructionHealth reconstructionHealth;
  final ValueChanged<String>? onIncidentNameChanged;

  static const Color untitledTitleColor = AppColors.warning;
  static const String untitledPlaceholder = 'Untitled Incident';
  static const String renameHint = 'Tap to rename incident';
  static const double titleIconSize = 21;
  static const double parallelogramInset = 12;

  static Color statusColorFor(JourneyStage stage) => switch (stage) {
        JourneyStage.empty => AppColors.strengthGood,
        JourneyStage.building => AppColors.warning,
        JourneyStage.rich => AppColors.success,
        JourneyStage.reflective => AppColors.success,
      };

  static String displayHealthLabel(ReconstructionHealthStatus status) =>
      switch (status) {
        ReconstructionHealthStatus.excellent => 'Healthy',
        ReconstructionHealthStatus.needsReview => 'Needs Review',
        ReconstructionHealthStatus.incomplete => 'Incomplete',
      };

  @override
  Widget build(BuildContext context) {
    final statusColor = statusColorFor(journeyStage);
    final incidentStatus = IncidentStatus.resolve(
      journeyStage: journeyStage,
      health: reconstructionHealth.status,
    );
    final healthStatus = IncidentStatus.fromReconstructionHealth(
      reconstructionHealth.status,
    );

    return LayeredCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _IncidentCaseTitleHeader(
            incidentName: incidentName,
            onChanged: onIncidentNameChanged,
          ),
          const SizedBox(height: AppSpacing.xxs),
          _MetricsGrid(
            incidentStatus: incidentStatus,
            timelineAnchorCount: timelineAnchorCount,
            relationshipGroupCount: relationshipGroupCount,
            narrativeEventCount: narrativeEventCount,
            statusColor: statusColor,
          ),
          const SizedBox(height: AppSpacing.xs),
          _ReconstructionHealthBlock(
            healthStatus: healthStatus,
            coverageLabel: reconstructionHealth.coverageLabel,
          ),
        ],
      ),
    );
  }
}

/// Premium case-file title — view mode by default, edit on tap.
class _IncidentCaseTitleHeader extends StatefulWidget {
  const _IncidentCaseTitleHeader({
    required this.incidentName,
    this.onChanged,
  });

  final String incidentName;
  final ValueChanged<String>? onChanged;

  @override
  State<_IncidentCaseTitleHeader> createState() =>
      _IncidentCaseTitleHeaderState();
}

class _IncidentCaseTitleHeaderState extends State<_IncidentCaseTitleHeader> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _editing = false;

  bool get _isUntitled {
    final trimmed = widget.incidentName.trim();
    return trimmed.isEmpty ||
        trimmed == InvestigationHeader.untitledPlaceholder;
  }

  String get _displayTitle {
    final trimmed = widget.incidentName.trim();
    return trimmed.isEmpty
        ? InvestigationHeader.untitledPlaceholder
        : trimmed;
  }

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.incidentName);
    _focusNode = FocusNode()..addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant _IncidentCaseTitleHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.incidentName == oldWidget.incidentName) {
      return;
    }
    // Same field is notifying the parent on each keystroke. Unfocusing here
    // dismissed the keyboard after every character. Incident switches recreate
    // this State via ValueKey(incident.id), so keep focus while editing.
    if (_editing || _focusNode.hasFocus) {
      return;
    }
    if (widget.incidentName != _controller.text) {
      _controller.text = widget.incidentName;
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (!_focusNode.hasFocus && _editing) {
      _collapseToHeader();
    }
  }

  void _enterEditMode() {
    if (widget.onChanged == null || _editing) {
      return;
    }
    setState(() {
      _editing = true;
      _controller.text = _isUntitled ? '' : widget.incidentName.trim();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  void _collapseToHeader() {
    if (!_editing) {
      return;
    }
    setState(() => _editing = false);
  }

  void _submitEdit(String _) {
    _focusNode.unfocus();
    _collapseToHeader();
  }

  /// Matches [InvestigationWorkspaceNavigationHeader.titleStyle] exactly.
  TextStyle get _titleStyle {
    final base = InvestigationWorkspaceNavigationHeader.titleStyle.copyWith(
      height: 1.15,
    );
    if (_editing || !_isUntitled) {
      return base;
    }
    return base.copyWith(color: InvestigationHeader.untitledTitleColor);
  }

  static const EdgeInsets _fieldPadding = EdgeInsets.symmetric(
    horizontal: AppSpacing.md,
    vertical: 5,
  );

  Widget _wrapParallelogram({required Widget child}) {
    return ClipPath(
      clipper: const _RightInclineParallelogramClipper(
        inset: InvestigationHeader.parallelogramInset,
      ),
      child: ColoredBox(
        color: AppColors.canvasAtmosphere,
        child: child,
      ),
    );
  }

  Widget _buildFolderIcon() {
    return Icon(
      Icons.folder_outlined,
      size: InvestigationHeader.titleIconSize,
      color: AppColors.navy.withValues(alpha: 0.72),
    );
  }

  Widget _buildTitleContent({required Widget titleChild}) {
    return Padding(
      padding: _fieldPadding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildFolderIcon(),
              const SizedBox(width: 6),
              Flexible(child: titleChild),
            ],
          ),
          if (!_editing && _isUntitled) ...[
            const SizedBox(height: 2),
            Text(
              InvestigationHeader.renameHint,
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w400,
                fontSize: 11,
                height: 1.2,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildViewMode() {
    return _wrapParallelogram(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onChanged == null ? null : _enterEditMode,
          splashColor: AppColors.navy.withValues(alpha: 0.04),
          highlightColor: AppColors.navy.withValues(alpha: 0.02),
          child: _buildTitleContent(
            titleChild: Text(
              _displayTitle,
              textAlign: TextAlign.center,
              style: _titleStyle,
              maxLines: 3,
              softWrap: true,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEditMode() {
    return _wrapParallelogram(
      child: _buildTitleContent(
        titleChild: TextField(
          controller: _controller,
          focusNode: _focusNode,
          onChanged: widget.onChanged,
          style: _titleStyle,
          cursorColor: AppColors.primary,
          textAlign: TextAlign.center,
          maxLines: 2,
          minLines: 1,
          textInputAction: TextInputAction.done,
          onSubmitted: _submitEdit,
          decoration: InputDecoration(
            isDense: true,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: EdgeInsets.zero,
            hintText: InvestigationHeader.untitledPlaceholder,
            hintStyle: _titleStyle.copyWith(
              color: AppColors.navy.withValues(alpha: 0.4),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: AppMotion.medium,
      curve: AppMotion.enter,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: AppMotion.medium,
        switchInCurve: AppMotion.enter,
        switchOutCurve: AppMotion.exit,
        child: KeyedSubtree(
          key: ValueKey(_editing ? 'edit' : 'view'),
          child: _editing ? _buildEditMode() : _buildViewMode(),
        ),
      ),
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({
    required this.incidentStatus,
    required this.timelineAnchorCount,
    required this.relationshipGroupCount,
    required this.narrativeEventCount,
    required this.statusColor,
  });

  final IncidentStatus incidentStatus;
  final int timelineAnchorCount;
  final int relationshipGroupCount;
  final int narrativeEventCount;
  final Color statusColor;

  static const double _rowGap = AppSpacing.xxs;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _MetricCell(
                title: 'Incident Status',
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: StatusBadge(status: incidentStatus),
                ),
              ),
              const SizedBox(height: _rowGap),
              _MetricCell(
                title: 'Relationship Groups',
                value: '$relationshipGroupCount',
                valueColor: statusColor,
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _MetricCell(
                title: 'Primary Evidence',
                value: '$timelineAnchorCount',
                valueColor: statusColor,
              ),
              const SizedBox(height: _rowGap),
              _MetricCell(
                title: 'Narrative Events',
                value: '$narrativeEventCount',
                valueColor: statusColor,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricCell extends StatelessWidget {
  const _MetricCell({
    required this.title,
    this.value,
    this.valueColor,
    this.child,
  }) : assert(value != null || child != null);

  final String title;
  final String? value;
  final Color? valueColor;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textMuted,
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 2),
        if (child != null)
          child!
        else
          Text(
            value!,
            style: AppTextStyles.label.copyWith(
              color: valueColor,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
      ],
    );
  }
}

class _ReconstructionHealthBlock extends StatelessWidget {
  const _ReconstructionHealthBlock({
    required this.healthStatus,
    required this.coverageLabel,
  });

  final IncidentStatus healthStatus;
  final String coverageLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Reconstruction Health',
          style: AppTextStyles.caption.copyWith(
            color: AppColors.navy,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        StatusBadge(status: healthStatus),
        const SizedBox(height: 2),
        Text(
          coverageLabel,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
            fontSize: 11,
          ),
          maxLines: 4,
          softWrap: true,
        ),
      ],
    );
  }
}

/// Subtle right-inclined parallelogram — does not skew child text.
class _RightInclineParallelogramClipper extends CustomClipper<Path> {
  const _RightInclineParallelogramClipper({required this.inset});

  final double inset;

  @override
  Path getClip(Size size) {
    final skew = inset.clamp(0.0, size.width / 4);
    return Path()
      ..moveTo(skew, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width - skew, size.height)
      ..lineTo(0, size.height)
      ..close();
  }

  @override
  bool shouldReclip(covariant _RightInclineParallelogramClipper oldClipper) {
    return oldClipper.inset != inset;
  }
}

