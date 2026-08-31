import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../domain/participant/evidence_person_relationship.dart';
import '../../domain/participant/participant.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../common/app_bottom_sheet.dart';

/// Draft from the related-person sheet before persistence.
class RelatedPersonDraft {
  const RelatedPersonDraft({
    required this.displayName,
    required this.relationship,
    this.existingParticipantId,
  });

  final String displayName;
  final EvidencePersonRelationship relationship;
  final String? existingParticipantId;
}

/// Lightweight sheet for linking evidence to a related person inline.
Future<RelatedPersonDraft?> showAddRelatedPersonSheet({
  required BuildContext context,
  Participant? existingParticipant,
  String? existingName,
  String? existingRelationship,
  List<Participant> recognizedPeople = const [],
  Set<String> excludeParticipantIds = const {},
  bool editing = false,
}) {
  return showAppBottomSheet<RelatedPersonDraft>(
    context: context,
    useRootNavigator: true,
    builder: (context) {
      return AddRelatedPersonSheet(
        existingParticipant: existingParticipant,
        existingName: existingName,
        existingRelationship: existingRelationship,
        recognizedPeople: recognizedPeople,
        excludeParticipantIds: excludeParticipantIds,
        editing: editing,
      );
    },
  );
}

class AddRelatedPersonSheet extends StatefulWidget {
  const AddRelatedPersonSheet({
    super.key,
    this.existingParticipant,
    this.existingName,
    this.existingRelationship,
    this.recognizedPeople = const [],
    this.excludeParticipantIds = const {},
    this.editing = false,
  });

  final Participant? existingParticipant;
  final String? existingName;
  final String? existingRelationship;
  final List<Participant> recognizedPeople;
  final Set<String> excludeParticipantIds;
  final bool editing;

  @override
  State<AddRelatedPersonSheet> createState() => _AddRelatedPersonSheetState();
}

class _AddRelatedPersonSheetState extends State<AddRelatedPersonSheet> {
  late final TextEditingController _nameController;
  late EvidencePersonRelationship _relationship;
  String? _selectedParticipantId;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingParticipant;
    final seededName = widget.existingName?.trim();
    _nameController = TextEditingController(
      text: (seededName != null && seededName.isNotEmpty)
          ? seededName
          : (existing?.displayName ?? ''),
    );
    _selectedParticipantId = existing?.id;
    _relationship = _relationshipFrom(
          widget.existingRelationship,
        ) ??
        (existing == null
            ? EvidencePersonRelationship.witness
            : EvidencePersonRelationship.fromParticipantRole(existing.role) ??
                EvidencePersonRelationship.other);
  }

  EvidencePersonRelationship? _relationshipFrom(String? roleName) {
    if (roleName == null || roleName.isEmpty) {
      return null;
    }
    for (final relationship in EvidencePersonRelationship.values) {
      if (relationship.name == roleName) {
        return relationship;
      }
    }
    return null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool get _canCommit => _nameController.text.trim().isNotEmpty;

  RelatedPersonDraft get _draft => RelatedPersonDraft(
        displayName: _nameController.text.trim(),
        relationship: _relationship,
        existingParticipantId: _selectedParticipantId,
      );

  List<Participant> get _suggestions {
    final excluded = widget.excludeParticipantIds;
    return [
      for (final person in widget.recognizedPeople)
        if (!excluded.contains(person.id)) person,
    ];
  }

  void _commit() {
    if (!_canCommit) {
      return;
    }
    Navigator.pop(context, _draft);
  }

  void _selectRecognized(Participant person) {
    setState(() {
      _selectedParticipantId = person.id;
      _nameController.text = person.displayName;
    });
  }

  void _selectRelationship(EvidencePersonRelationship option) {
    _relationship = option;
    if (_canCommit) {
      Navigator.pop(context, _draft);
      return;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = _suggestions;
    return PopScope(
      canPop: !_canCommit,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || !_canCommit) {
          return;
        }
        Navigator.pop(context, _draft);
      },
      child: BottomSheetInsets(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BottomSheetHeader(
              title: widget.editing ? 'Change Person' : 'Add Person',
              caption: 'Who does this evidence relate to?',
            ),
            if (suggestions.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                "I've seen these people before.",
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.xxs,
                runSpacing: AppSpacing.xxs,
                children: [
                  for (final person in suggestions)
                    ChoiceChip(
                      key: Key('recognized_person_${person.id}'),
                      label: Text(person.displayName),
                      selected: _selectedParticipantId == person.id,
                      onSelected: (_) => _selectRecognized(person),
                      labelStyle: AppTextStyles.caption.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      selectedColor: AppColors.warning.withValues(alpha: 0.16),
                      side: BorderSide(
                        color: _selectedParticipantId == person.id
                            ? AppColors.warning.withValues(alpha: 0.7)
                            : AppColors.border,
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            TextField(
              key: const Key('related_person_name_field'),
              controller: _nameController,
              autofocus: suggestions.isEmpty,
              decoration: InputDecoration(
                labelText: 'Name',
                labelStyle: AppTextStyles.caption,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.fieldRadius),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
              ),
              style: AppTextStyles.label,
              textInputAction: TextInputAction.done,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) {
                setState(() {
                  _selectedParticipantId = null;
                });
              },
              onSubmitted: (_) => _commit(),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Relationship',
              style: AppTextStyles.caption.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xxs,
              runSpacing: AppSpacing.xxs,
              children: [
                for (final option in EvidencePersonRelationship.values)
                  ChoiceChip(
                    key: Key('related_person_relationship_${option.name}'),
                    label: Text(option.label),
                    selected: _relationship == option,
                    onSelected: (_) => _selectRelationship(option),
                    labelStyle: AppTextStyles.caption.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    selectedColor: AppColors.warning.withValues(alpha: 0.16),
                    side: BorderSide(
                      color: _relationship == option
                          ? AppColors.warning.withValues(alpha: 0.7)
                          : AppColors.border,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
