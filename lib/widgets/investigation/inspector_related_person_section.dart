import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../controllers/workspace_evidence_controller.dart';
import '../../domain/participant/evidence_person_relationship.dart';
import '../../domain/participant/participant.dart';
import '../../domain/participant/participant_role.dart';
import '../../domain/participant/related_person_link.dart';
import '../../models/workspace_evidence_item.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'add_related_person_sheet.dart';
import 'investigate_incident_scope.dart';

/// Lightweight related-person section inside the Evidence Inspector.
class InspectorRelatedPersonSection extends StatelessWidget {
  const InspectorRelatedPersonSection({
    super.key,
    required this.evidence,
    required this.controller,
    required this.onParticipantChanged,
    this.boundIncidentId,
  });

  final WorkspaceEvidenceItem evidence;
  final WorkspaceEvidenceController controller;
  final VoidCallback onParticipantChanged;
  final String? boundIncidentId;

  List<RelatedPersonLink> get _people =>
      controller.relatedPeopleForEvidence(evidence);

  String? _relationshipLabel(String? roleName, Participant? participant) {
    if (roleName != null && roleName.isNotEmpty) {
      for (final relationship in EvidencePersonRelationship.values) {
        if (relationship.name == roleName) {
          return relationship.label;
        }
      }
      for (final role in ParticipantRole.values) {
        if (role.name == roleName) {
          return role.label;
        }
      }
    }
    return participant?.role.label;
  }

  Future<void> _handleAdd(BuildContext context) async {
    await _openSheet(context);
  }

  Future<void> _handleEdit(
    BuildContext context,
    RelatedPersonLink person,
  ) async {
    await _openSheet(context, editing: person);
  }

  Future<void> _openSheet(
    BuildContext context, {
    RelatedPersonLink? editing,
  }) async {
    final explicit = (boundIncidentId ?? '').trim();
    final fromEvidence = evidence.incidentId.trim();
    final boundIncidentIdAtStart = explicit.isNotEmpty
        ? explicit
        : (fromEvidence.isNotEmpty
            ? fromEvidence
            : controller.currentIncident.id.trim());
    if (!InvestigateIncidentScope.sessionMatchesBound(
      boundIncidentIdAtStart,
      controller.currentIncident.id,
    )) {
      return;
    }
    final linkedIds = {
      for (final person in _people)
        if (person.participantId.trim().isNotEmpty) person.participantId,
    };
    final draft = await showAddRelatedPersonSheet(
      context: context,
      existingParticipant: editing == null
          ? null
          : controller.participantRepository.getById(editing.participantId),
      existingName: editing?.displayName,
      existingRelationship: editing?.roleName,
      recognizedPeople: controller.recognizedParticipants(),
      excludeParticipantIds: {
        for (final id in linkedIds)
          if (editing == null || id != editing.participantId) id,
      },
      editing: editing != null,
    );
    if (draft == null || !context.mounted) {
      return;
    }
    if (!InvestigateIncidentScope.sessionMatchesBound(
      boundIncidentIdAtStart,
      controller.currentIncident.id,
    )) {
      return;
    }

    if (editing == null) {
      controller.addRelatedPersonToEvidence(
        evidenceId: evidence.id,
        displayName: draft.displayName,
        relationship: draft.relationship,
        existingParticipantId: draft.existingParticipantId,
      );
    } else {
      controller.replaceRelatedPersonOnEvidence(
        evidenceId: evidence.id,
        previousParticipantId: editing.participantId,
        displayName: draft.displayName,
        relationship: draft.relationship,
        existingParticipantId: draft.existingParticipantId,
      );
    }
    FocusManager.instance.primaryFocus?.unfocus();
    onParticipantChanged();
  }

  @override
  Widget build(BuildContext context) {
    final people = _people;
    return Column(
      key: const Key('evidence_inspector_related_person'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Related People',
          style: AppTextStyles.label.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        for (var i = 0; i < people.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.xxs),
          _RelatedPersonCard(
            person: people[i],
            isFirst: i == 0,
            relationship: _relationshipLabel(
              people[i].roleName,
              controller.participantRepository.getById(people[i].participantId),
            ),
            onTap: () => _handleEdit(context, people[i]),
          ),
        ],
        if (people.isNotEmpty) const SizedBox(height: AppSpacing.xxs),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => _handleAdd(context),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: AppColors.warning,
              textStyle: AppTextStyles.caption.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_rounded, size: 16, color: AppColors.warning),
                SizedBox(width: 4),
                Text('Add Person'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RelatedPersonCard extends StatelessWidget {
  const _RelatedPersonCard({
    required this.person,
    required this.isFirst,
    required this.relationship,
    required this.onTap,
  });

  final RelatedPersonLink person;
  final bool isFirst;
  final String? relationship;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: isFirst
          ? const Key('evidence_inspector_related_person_card')
          : Key('evidence_inspector_related_person_card_${person.participantId}'),
      color: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: AppColors.border.withValues(alpha: 0.9)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm,
            AppSpacing.xs,
            AppSpacing.xs,
            AppSpacing.xs,
          ),
          child: Row(
            children: [
              Icon(
                Icons.person_outline_rounded,
                size: 22,
                color: AppColors.navy.withValues(alpha: 0.75),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      person.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.label.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppColors.navy,
                        height: 1.2,
                      ),
                    ),
                    if (relationship != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        key: isFirst
                            ? const Key(
                                'evidence_inspector_related_relationship',
                              )
                            : null,
                        relationship!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
