import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// Compact persistent incident identity above the sticky Capture Bar.
///
/// Supports inline title editing. Untitled incidents use a restrained orange
/// treatment without blocking capture.
class CockpitIncidentHeader extends StatefulWidget {
  const CockpitIncidentHeader({
    super.key,
    required this.incidentTitle,
    required this.onTitleSaved,
    this.enabled = true,
    this.showPreservingLabel = true,
    this.startEditing = false,
  });

  final String incidentTitle;
  final ValueChanged<String> onTitleSaved;
  final bool enabled;

  /// When false, only the editable title is shown (Workspace sticky footer).
  final bool showPreservingLabel;

  /// Open the title field immediately (Library Add Title).
  final bool startEditing;

  static bool isUntitled(String title) {
    final trimmed = title.trim();
    return trimmed.isEmpty ||
        trimmed.toLowerCase() == 'untitled incident';
  }

  @override
  State<CockpitIncidentHeader> createState() => _CockpitIncidentHeaderState();
}

class _CockpitIncidentHeaderState extends State<CockpitIncidentHeader> {
  bool _editing = false;
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _seedText(widget.incidentTitle));
    _focusNode = FocusNode();
    if (widget.startEditing && widget.enabled) {
      _editing = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _focusNode.requestFocus();
        }
      });
    }
  }

  @override
  void didUpdateWidget(CockpitIncidentHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.incidentTitle == widget.incidentTitle) {
      return;
    }
    // Incident identity changed (Clear Vault / Capture Now) — drop stale edit.
    if (_editing) {
      _editing = false;
      _focusNode.unfocus();
    }
    _controller.text = _seedText(widget.incidentTitle);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String _seedText(String title) {
    return CockpitIncidentHeader.isUntitled(title) ? '' : title.trim();
  }

  void _beginEdit() {
    if (!widget.enabled) {
      return;
    }
    setState(() {
      _editing = true;
      _controller.text = _seedText(widget.incidentTitle);
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  void _cancel() {
    setState(() {
      _editing = false;
      _controller.text = _seedText(widget.incidentTitle);
    });
    _focusNode.unfocus();
  }

  void _save() {
    final next = _controller.text.trim();
    widget.onTitleSaved(next);
    setState(() => _editing = false);
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final untitled = CockpitIncidentHeader.isUntitled(widget.incidentTitle);
    final display = untitled
        ? 'Untitled incident'
        : widget.incidentTitle.trim();

    return Container(
      key: const Key('cockpit_incident_header'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.xs,
      ),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(
          top: BorderSide(color: AppColors.border),
        ),
      ),
      child: _editing ? _buildEditor() : _buildDisplay(display, untitled),
    );
  }

  Widget _buildDisplay(String display, bool untitled) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          key: const Key('cockpit_incident_title_tap'),
          onTap: widget.enabled ? _beginEdit : null,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                if (untitled) ...[
                  Container(
                    key: const Key('cockpit_untitled_indicator'),
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.warning,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                ],
                Expanded(
                  child: Text(
                    display,
                    key: const Key('cockpit_incident_title'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.label.copyWith(
                      fontWeight: FontWeight.w700,
                      color: untitled ? AppColors.warning : AppColors.navy,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                Icon(
                  Icons.edit_outlined,
                  size: 16,
                  color: untitled ? AppColors.warning : AppColors.textMuted,
                ),
              ],
            ),
          ),
        ),
        if (widget.showPreservingLabel) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'PRESERVING',
                key: const Key('cockpit_preserving_label'),
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.success,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildEditor() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            key: const Key('cockpit_incident_title_field'),
            controller: _controller,
            focusNode: _focusNode,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
            style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w600),
            decoration: const InputDecoration(
              isDense: true,
              hintText: 'Name this incident',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
            ),
          ),
        ),
        IconButton(
          key: const Key('cockpit_incident_title_save'),
          tooltip: 'Save title',
          onPressed: _save,
          icon: const Icon(Icons.check, color: AppColors.success),
        ),
        IconButton(
          key: const Key('cockpit_incident_title_cancel'),
          tooltip: 'Cancel',
          onPressed: _cancel,
          icon: const Icon(Icons.close, color: AppColors.textMuted),
        ),
      ],
    );
  }
}
