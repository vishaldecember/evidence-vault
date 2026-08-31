import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_text_styles.dart';

/// Progressive naming extension on the top edge of the Capture card.
///
/// Expands upward from a fixed slot without shifting workspace layout.
class IncidentIdentityDrawer extends StatefulWidget {
  const IncidentIdentityDrawer({
    super.key,
    required this.isExpanded,
    required this.onToggle,
    required this.incidentName,
    required this.onIncidentNameChanged,
    this.animateEntry = false,
  });

  static const String fieldLabel = 'Name Incident…';
  static const String placeholderExample = 'e.g. Travel issue';

  static const double chevronEdgeInset = 18;
  static const double fieldHeight = 36;
  static const double chevronSize = 40;
  static const double chevronIconSize = 24;
  static const double collapsedTabHeight = 30;
  static const double _slideDistance = 14;
  static const Duration _overlayDuration = Duration(milliseconds: 175);

  final bool isExpanded;
  final VoidCallback onToggle;
  final String incidentName;
  final ValueChanged<String> onIncidentNameChanged;
  final bool animateEntry;

  @override
  State<IncidentIdentityDrawer> createState() => _IncidentIdentityDrawerState();
}

class _IncidentIdentityDrawerState extends State<IncidentIdentityDrawer>
    with TickerProviderStateMixin {
  late final TextEditingController _nameController;
  late final FocusNode _focusNode;
  late final AnimationController _entryController;
  late final AnimationController _expandController;
  late final Animation<double> _expandSlide;
  bool _showPlaceholder = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.incidentName);
    _focusNode = FocusNode()..addListener(_handleFocusChange);

    _entryController = AnimationController(
      vsync: this,
      duration: IncidentIdentityDrawer._overlayDuration,
    );

    _expandController = AnimationController(
      vsync: this,
      duration: IncidentIdentityDrawer._overlayDuration,
    );
    _expandSlide = Tween<double>(
      begin: IncidentIdentityDrawer._slideDistance,
      end: 0,
    ).animate(
      CurvedAnimation(
        parent: _expandController,
        curve: AppMotion.enter,
        reverseCurve: AppMotion.exit,
      ),
    );

    if (widget.isExpanded) {
      _expandController.value = 1;
    }

    if (widget.animateEntry) {
      _entryController.forward();
    } else {
      _entryController.value = 1;
    }
  }

  @override
  void didUpdateWidget(IncidentIdentityDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Always sync when the bound incident name changes (incl. Clear Vault → '').
    if (widget.incidentName != oldWidget.incidentName &&
        widget.incidentName != _nameController.text) {
      _nameController.text = widget.incidentName;
      _showPlaceholder = widget.incidentName.trim().isEmpty;
    } else if (widget.incidentName != _nameController.text) {
      _nameController.text = widget.incidentName;
    }
    if (widget.animateEntry && !oldWidget.animateEntry) {
      _entryController.forward(from: 0);
    }
    if (widget.isExpanded != oldWidget.isExpanded) {
      if (widget.isExpanded) {
        _expandController.forward();
      } else {
        _expandController.reverse();
      }
    }
    if (!oldWidget.isExpanded && widget.isExpanded && _nameController.text.isEmpty) {
      _showPlaceholder = true;
    }
  }

  void _handleFocusChange() {
    if (_focusNode.hasFocus && _showPlaceholder) {
      setState(() => _showPlaceholder = false);
    }
  }

  void _activateField() {
    if (_showPlaceholder) {
      setState(() => _showPlaceholder = false);
    }
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _entryController.dispose();
    _expandController.dispose();
    _focusNode
      ..removeListener(_handleFocusChange)
      ..dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _entryController,
      child: AnimatedBuilder(
        animation: _expandController,
        builder: (context, _) {
          final expandT = _expandController.value;

          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            fit: StackFit.expand,
            children: [
              IgnorePointer(
                ignoring: expandT > 0.01,
                child: Opacity(
                  opacity: 1 - expandT,
                  child: _CollapsedReminderTab(
                    incidentName: widget.incidentName,
                    onExpand: widget.onToggle,
                  ),
                ),
              ),
              IgnorePointer(
                ignoring: expandT < 0.99,
                child: Opacity(
                  opacity: expandT,
                  child: Transform.translate(
                    offset: Offset(0, _expandSlide.value),
                    child: _ExpandedNamingField(
                      nameController: _nameController,
                      focusNode: _focusNode,
                      showPlaceholder: _showPlaceholder,
                      onActivate: _activateField,
                      onChanged: widget.onIncidentNameChanged,
                      onCollapse: widget.onToggle,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ExpandedNamingField extends StatelessWidget {
  const _ExpandedNamingField({
    required this.nameController,
    required this.focusNode,
    required this.showPlaceholder,
    required this.onActivate,
    required this.onChanged,
    required this.onCollapse,
  });

  final TextEditingController nameController;
  final FocusNode focusNode;
  final bool showPlaceholder;
  final VoidCallback onActivate;
  final ValueChanged<String> onChanged;
  final VoidCallback onCollapse;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted.withValues(alpha: 0.35),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppSpacing.cardRadius),
          topRight: Radius.circular(AppSpacing.cardRadius),
        ),
        border: Border(
          bottom: BorderSide(
            color: AppColors.border.withValues(alpha: 0.55),
          ),
        ),
      ),
      child: SizedBox(
        height: IncidentIdentityDrawer.fieldHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: GestureDetector(
                onTap: onActivate,
                behavior: HitTestBehavior.opaque,
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    if (showPlaceholder && nameController.text.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                        ),
                        child: _NamingPlaceholder(),
                      ),
                    TextField(
                      controller: nameController,
                      focusNode: focusNode,
                      onChanged: onChanged,
                      onTap: onActivate,
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        height: 1.1,
                        color: AppColors.navy,
                      ),
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xxs,
                        ),
                      ),
                      textInputAction: TextInputAction.done,
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (_) => focusNode.unfocus(),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(
                right: IncidentIdentityDrawer.chevronEdgeInset,
              ),
              child: _CollapseChevron(onPressed: onCollapse),
            ),
          ],
        ),
      ),
    );
  }
}

class _NamingPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: IncidentIdentityDrawer.fieldLabel,
            style: AppTextStyles.caption.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.warning.withValues(alpha: 0.85),
              height: 1.1,
            ),
          ),
          TextSpan(
            text: ' ${IncidentIdentityDrawer.placeholderExample}',
            style: AppTextStyles.caption.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: AppColors.warning.withValues(alpha: 0.55),
              height: 1.1,
            ),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _CollapsedReminderTab extends StatelessWidget {
  const _CollapsedReminderTab({
    required this.incidentName,
    required this.onExpand,
  });

  final String incidentName;
  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    final hasName = incidentName.trim().isNotEmpty;
    final label = hasName ? incidentName.trim() : 'Name incident';

    return Material(
      color: AppColors.warning.withValues(alpha: 0.14),
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(AppSpacing.cardRadius),
        topRight: Radius.circular(AppSpacing.cardRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onExpand,
        child: SizedBox(
          height: IncidentIdentityDrawer.collapsedTabHeight,
          child: Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.sm,
              right: IncidentIdentityDrawer.chevronEdgeInset,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.drive_file_rename_outline_rounded,
                  size: 15,
                  color: AppColors.warning.withValues(alpha: 0.95),
                ),
                const SizedBox(width: AppSpacing.xxs),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.warning.withValues(alpha: 0.95),
                      height: 1,
                    ),
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_up_rounded,
                  size: IncidentIdentityDrawer.chevronIconSize,
                  color: AppColors.warning.withValues(alpha: 0.9),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CollapseChevron extends StatelessWidget {
  const _CollapseChevron({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Collapse name incident field',
      child: SizedBox(
        width: IncidentIdentityDrawer.chevronSize,
        height: IncidentIdentityDrawer.chevronSize,
        child: IconButton(
          onPressed: onPressed,
          padding: EdgeInsets.zero,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            size: IncidentIdentityDrawer.chevronIconSize,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
