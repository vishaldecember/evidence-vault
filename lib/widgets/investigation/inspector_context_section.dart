import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../models/context_item.dart';
import '../../models/context_type.dart';
import '../../models/evidence_record_model.dart';
import '../../presentation/evidence_inspector_semantics.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/workspace_evidence_formatters.dart';
import 'inspector_record_sections.dart';

/// Notebook-style context capture for the Evidence Inspector.
///
/// Collapsed: at most two visible lines. Expands while editing / focused.
class InspectorContextSection extends StatefulWidget {
  const InspectorContextSection({
    super.key,
    required this.record,
    required this.onDraftChanged,
    this.expandEditor = false,
    this.requestAutofocus = false,
    this.onEditingChanged,
  });

  static const String placeholder =
      EvidenceInspectorSemantics.observationPlaceholder;

  final EvidenceRecordModel record;
  final ValueChanged<String> onDraftChanged;
  final bool expandEditor;
  final bool requestAutofocus;
  final ValueChanged<bool>? onEditingChanged;

  /// Newest text-note context item, if any — used for in-place autosave.
  static ContextItem? editableNote(EvidenceRecordModel record) {
    for (final item in record.contextItems) {
      if (item.type == ContextType.note) {
        return item;
      }
    }
    return null;
  }

  @override
  State<InspectorContextSection> createState() =>
      _InspectorContextSectionState();
}

class _InspectorContextSectionState extends State<InspectorContextSection> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _editing = false;

  String _initialText(EvidenceRecordModel record) {
    return InspectorContextSection.editableNote(record)?.displayTitle ?? '';
  }

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _initialText(widget.record));
    _focusNode = FocusNode()..addListener(_handleFocusChange);
    if (widget.requestAutofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _focusNode.requestFocus();
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant InspectorContextSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_focusNode.hasFocus) {
      return;
    }
    final next = _initialText(widget.record);
    if (_controller.text != next) {
      _controller.text = next;
    }
  }

  void _handleFocusChange() {
    final editing = _focusNode.hasFocus;
    if (editing == _editing) {
      return;
    }
    setState(() => _editing = editing);
    widget.onEditingChanged?.call(editing);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  static const _editorRadius = 10.0;
  static const _editorFill = AppColors.card;

  InputDecoration get _decoration => InputDecoration(
        hintText: InspectorContextSection.placeholder,
        hintStyle: AppTextStyles.body.copyWith(
          fontSize: 15,
          height: 1.35,
          color: AppColors.textMuted.withValues(alpha: 0.85),
        ),
        filled: true,
        fillColor: _editorFill,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_editorRadius),
          borderSide: const BorderSide(
            color: AppColors.captureTileBorder,
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_editorRadius),
          borderSide: const BorderSide(
            color: AppColors.captureTileBorder,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_editorRadius),
          borderSide: const BorderSide(
            color: AppColors.canvasAtmosphere,
            width: 1.25,
          ),
        ),
      );

  TextStyle get _editorStyle => AppTextStyles.body.copyWith(
        fontSize: 15,
        height: 1.35,
        color: AppColors.navy,
        fontWeight: FontWeight.w500,
      );

  Widget _buildEditor({required bool expand}) {
    final field = expand
        ? TextField(
            controller: _controller,
            focusNode: _focusNode,
            expands: true,
            maxLines: null,
            minLines: null,
            textAlignVertical: TextAlignVertical.top,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.newline,
            style: _editorStyle,
            decoration: _decoration,
            onChanged: widget.onDraftChanged,
          )
        : TextField(
            controller: _controller,
            focusNode: _focusNode,
            minLines: 2,
            maxLines: _editing ? 3 : 2,
            scrollPadding: const EdgeInsets.only(bottom: 80),
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.newline,
            style: _editorStyle,
            decoration: _decoration,
            onChanged: widget.onDraftChanged,
          );

    return KeyedSubtree(
      key: const Key('evidence_inspector_description_editor'),
      child: field,
    );
  }

  void _beginEditing() {
    if (_editing) {
      return;
    }
    setState(() => _editing = true);
    widget.onEditingChanged?.call(true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  bool get _hasAuthoredText => _controller.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final editingNote = InspectorContextSection.editableNote(widget.record);
    final priorObservations = widget.record.contextItems
        .where((item) => item.id != editingNote?.id)
        .toList();
    final expand = widget.expandEditor;
    final showEditor =
        expand || _editing || _hasAuthoredText || priorObservations.isNotEmpty;

    return Semantics(
      container: true,
      label: showEditor
          ? 'Your observation. User-authored context.'
          : 'Your observation. No user-authored context yet.',
      child: Column(
        key: const Key('evidence_inspector_context'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const InspectorSectionLabel(
            EvidenceInspectorSemantics.observationLabel,
            authored: true,
          ),
          const SizedBox(height: AppSpacing.xxs),
          if (priorObservations.isNotEmpty) ...[
            _ExistingObservations(items: priorObservations),
            const SizedBox(height: AppSpacing.xxs),
          ],
          if (!showEditor)
            _AddObservationAffordance(onPressed: _beginEditing)
          else if (expand)
            Expanded(child: _buildEditor(expand: true))
          else
            _buildEditor(expand: false),
          if (showEditor) _DescriptionStamp(note: editingNote),
        ],
      ),
    );
  }
}

class _AddObservationAffordance extends StatelessWidget {
  const _AddObservationAffordance({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        key: const Key('evidence_inspector_add_observation'),
        onPressed: onPressed,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 2),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          foregroundColor: AppColors.onCanvasSecondary,
          textStyle: AppTextStyles.caption.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        child: const Text(EvidenceInspectorSemantics.addObservationAffordance),
      ),
    );
  }
}

class _DescriptionStamp extends StatelessWidget {
  const _DescriptionStamp({required this.note});

  final ContextItem? note;

  @override
  Widget build(BuildContext context) {
    final item = note;
    final text = item?.displayTitle.trim() ?? '';
    if (item == null || text.isEmpty) {
      return const SizedBox.shrink();
    }

    final updated =
        item.updatedAt != null && item.updatedAt!.isAfter(item.addedAt);
    final when = (updated ? item.updatedAt : null) ?? item.addedAt;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xxs),
      child: Row(
        key: const Key('evidence_inspector_description_stamp'),
        children: [
          const Icon(
            Icons.schedule_rounded,
            size: 13,
            color: AppColors.textMuted,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              WorkspaceEvidenceFormatters.descriptionStamp(
                when,
                updated: updated,
              ),
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textMuted,
                fontSize: 12,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExistingObservations extends StatelessWidget {
  const _ExistingObservations({required this.items});

  final List<ContextItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.xxs),
          Text(
            items[i].displayTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodySmall.copyWith(
              height: 1.35,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}
