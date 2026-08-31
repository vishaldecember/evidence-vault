import '../domain/relationship/relationship_group.dart';

import '../models/evidence_relationship.dart';

import '../models/relationship_type.dart';

import '../models/workspace_evidence_factory.dart';

import '../services/relationship_group_color_service.dart';

import 'incident_store.dart';

import 'relationship_repository.dart';



/// In-memory [RelationshipRepository] backed by [IncidentStore].

class InMemoryRelationshipRepository implements RelationshipRepository {

  InMemoryRelationshipRepository(this._store);



  final IncidentStore _store;



  @override

  List<EvidenceRelationship> get all =>

      List<EvidenceRelationship>.unmodifiable(_store.relationships);



  @override

  List<RelationshipGroup> get groups =>

      List<RelationshipGroup>.unmodifiable(_store.relationshipGroups);



  @override

  List<EvidenceRelationship> linkedFrom(String evidenceId) {

    return _store.relationships

        .where((relationship) => relationship.sourceEvidenceId == evidenceId)

        .toList();

  }



  @override

  bool isLinked({

    required String sourceEvidenceId,

    required String targetEvidenceId,

  }) {

    return _store.relationships.any(

      (relationship) =>

          relationship.sourceEvidenceId == sourceEvidenceId &&

          relationship.targetEvidenceId == targetEvidenceId,

    );

  }



  @override

  EvidenceRelationship? linkEvidence({
    required String sourceEvidenceId,
    required String targetEvidenceId,
    required RelationshipType type,
    String? reason,
    String? source,
  }) {
    if (sourceEvidenceId == targetEvidenceId) {
      return null;
    }

    final sourceExists = _containsEvidenceId(sourceEvidenceId);
    final targetExists = _containsEvidenceId(targetEvidenceId);

    if (!sourceExists || !targetExists) {
      return null;
    }

    if (isLinked(
      sourceEvidenceId: sourceEvidenceId,
      targetEvidenceId: targetEvidenceId,
    )) {
      return null;
    }

    final relationship = EvidenceRelationship(
      id: WorkspaceEvidenceFactory.nextRelationshipId(),
      sourceEvidenceId: sourceEvidenceId,
      targetEvidenceId: targetEvidenceId,
      type: type,
      createdAt: DateTime.now(),
      reason: reason,
      source: source,
    );

    _store.relationships.add(relationship);
    _touchIncident();
    return relationship;
  }



  @override

  RelationshipGroup? commitRelationshipGroup({

    required List<String> evidenceIds,

    RelationshipType type = RelationshipType.relatedTo,

  }) {

    final uniqueIds = evidenceIds.toSet().toList()..sort();

    if (uniqueIds.length < 2) {

      return null;

    }



    for (final id in uniqueIds) {

      if (!_containsEvidenceId(id)) {

        return null;

      }

    }



    final colorIndex =

        RelationshipGroupColorService.nextColorIndex(_store.relationshipGroups);



    final group = RelationshipGroup(

      id: WorkspaceEvidenceFactory.nextRelationshipGroupId(),

      incidentId: _store.incident.id,

      memberEvidenceIds: List.unmodifiable(uniqueIds),

      type: type,

      createdAt: DateTime.now(),

      colorIndex: colorIndex,

    );



    _store.relationshipGroups.add(group);

    _rebuildLinksForGroup(group);

    _touchIncident();

    return group;

  }



  @override

  RelationshipGroup? moveSupportingToGroup({

    required String supportingEvidenceId,

    required String targetGroupId,

  }) {

    if (!_isSupportingEvidence(supportingEvidenceId)) {

      return null;

    }



    final targetIndex = _groupIndex(targetGroupId);

    if (targetIndex == -1) {

      return null;

    }



    final sourceGroup = _groupContaining(supportingEvidenceId);

    if (sourceGroup == null || sourceGroup.id == targetGroupId) {

      return null;

    }



    final sourceMembers = sourceGroup.memberEvidenceIds

        .where((id) => id != supportingEvidenceId)

        .toList();

    _replaceGroupMembers(sourceGroup.id, sourceMembers);

    _deleteEmptyGroup(sourceGroup.id);



    final targetGroup = _store.relationshipGroups[_groupIndex(targetGroupId)];

    final targetMembers = {

      ...targetGroup.memberEvidenceIds,

      supportingEvidenceId,

    }.toList()

      ..sort();

    final updatedTarget = _replaceGroupMembers(targetGroup.id, targetMembers);

    _touchIncident();

    return updatedTarget;

  }



  @override

  RelationshipGroup? removeSupportingFromGroup({

    required String supportingEvidenceId,

    required String groupId,

  }) {

    if (!_isSupportingEvidence(supportingEvidenceId)) {

      return null;

    }



    final group = _groupById(groupId);

    if (group == null || !group.memberEvidenceIds.contains(supportingEvidenceId)) {

      return null;

    }



    final members = group.memberEvidenceIds

        .where((id) => id != supportingEvidenceId)

        .toList();

    final updated = _replaceGroupMembers(groupId, members);

    _deleteEmptyGroup(groupId);

    _touchIncident();

    return updated;

  }



  @override

  RelationshipGroup? mergeGroups({

    required String sourceGroupId,

    required String targetGroupId,

  }) {

    if (sourceGroupId == targetGroupId) {

      return null;

    }



    final source = _groupById(sourceGroupId);

    final target = _groupById(targetGroupId);

    if (source == null || target == null) {

      return null;

    }



    final mergedMembers = {

      ...target.memberEvidenceIds,

      ...source.memberEvidenceIds,

    }.toList()

      ..sort();



    _removeGroup(sourceGroupId);

    final updated = _replaceGroupMembers(targetGroupId, mergedMembers);

    _touchIncident();

    return updated;

  }



  @override

  RelationshipGroup? splitGroup({

    required String groupId,

    required List<String> supportingEvidenceIds,

  }) {

    final group = _groupById(groupId);

    if (group == null || supportingEvidenceIds.isEmpty) {

      return null;

    }



    final uniqueSupporting = supportingEvidenceIds.toSet();

    for (final id in uniqueSupporting) {

      if (!_isSupportingEvidence(id) || !group.memberEvidenceIds.contains(id)) {

        return null;

      }

    }



    final remainingMembers = group.memberEvidenceIds

        .where((id) => !uniqueSupporting.contains(id))

        .toList();

    if (remainingMembers.length < 2) {

      return null;

    }



    _replaceGroupMembers(groupId, remainingMembers);



    final colorIndex =

        RelationshipGroupColorService.nextColorIndex(_store.relationshipGroups);

    final splitGroup = RelationshipGroup(

      id: WorkspaceEvidenceFactory.nextRelationshipGroupId(),

      incidentId: _store.incident.id,

      memberEvidenceIds: List.unmodifiable(uniqueSupporting.toList()..sort()),

      type: group.type,

      createdAt: DateTime.now(),

      colorIndex: colorIndex,

    );



    _store.relationshipGroups.add(splitGroup);

    _rebuildLinksForGroup(splitGroup);

    _touchIncident();

    return splitGroup;

  }



  @override

  bool deleteEmptyGroup({required String groupId}) {

    final deleted = _deleteEmptyGroup(groupId);

    if (deleted) {

      _touchIncident();

    }

    return deleted;

  }



  @override

  RelationshipGroup? updateGroupInvestigation({

    required String groupId,

    required String displayName,

    required String description,

  }) {

    final group = _groupById(groupId);

    if (group == null) {

      return null;

    }



    final normalizedName =

        RelationshipGroupColorService.normalizeDisplayName(displayName);

    final normalizedDescription =

        RelationshipGroupColorService.normalizeDescription(description);

    final index = _groupIndex(groupId);

    final updated = group.copyWithInvestigation(

      displayName: normalizedName,

      description: normalizedDescription,

    );

    _store.relationshipGroups[index] = updated;

    _touchIncident();

    return updated;

  }



  RelationshipGroup? _groupById(String groupId) {

    final index = _groupIndex(groupId);

    if (index == -1) {

      return null;

    }

    return _store.relationshipGroups[index];

  }



  int _groupIndex(String groupId) =>

      _store.relationshipGroups.indexWhere((group) => group.id == groupId);



  RelationshipGroup? _groupContaining(String evidenceId) {

    for (final group in _store.relationshipGroups) {

      if (group.memberEvidenceIds.contains(evidenceId)) {

        return group;

      }

    }

    return null;

  }



  RelationshipGroup? _replaceGroupMembers(String groupId, List<String> members) {

    final index = _groupIndex(groupId);

    if (index == -1) {

      return null;

    }



    final existing = _store.relationshipGroups[index];

    final updated = existing.copyWithMembers(List.unmodifiable(members));

    _store.relationshipGroups[index] = updated;

    _rebuildLinksForGroup(updated);

    return updated;

  }



  bool _deleteEmptyGroup(String groupId) {

    final group = _groupById(groupId);

    if (group == null || group.memberEvidenceIds.isNotEmpty) {

      return false;

    }



    _removeGroup(groupId);

    return true;

  }



  void _removeGroup(String groupId) {

    final group = _groupById(groupId);

    if (group == null) {

      return;

    }



    final memberSet = group.memberEvidenceIds.toSet();

    _store.relationshipGroups.removeWhere((entry) => entry.id == groupId);

    _store.relationships.removeWhere(

      (relationship) =>

          memberSet.contains(relationship.sourceEvidenceId) &&

          memberSet.contains(relationship.targetEvidenceId),

    );

  }



  void _rebuildLinksForGroup(RelationshipGroup group) {

    final memberSet = group.memberEvidenceIds.toSet();

    _store.relationships.removeWhere(

      (relationship) =>

          memberSet.contains(relationship.sourceEvidenceId) &&

          memberSet.contains(relationship.targetEvidenceId),

    );



    if (group.memberEvidenceIds.length < 2) {

      return;

    }



    final hubId = _hubIdForMembers(group.memberEvidenceIds);

    final now = DateTime.now();

    for (final memberId in group.memberEvidenceIds) {

      if (memberId == hubId) {

        continue;

      }

      _store.relationships.add(

        EvidenceRelationship(

          id: WorkspaceEvidenceFactory.nextRelationshipId(),

          sourceEvidenceId: hubId,

          targetEvidenceId: memberId,

          type: group.type,

          createdAt: now,

        ),

      );

    }

  }



  String _hubIdForMembers(List<String> memberIds) {

    final memberSet = memberIds.toSet();

    for (final anchor in _store.timelineAnchors) {

      if (memberSet.contains(anchor.capturedEvidenceId)) {

        return anchor.capturedEvidenceId;

      }

    }



    final sorted = List<String>.from(memberIds)..sort();

    return sorted.first;

  }



  bool _containsEvidenceId(String id) {

    return _store.capturedEvidence.any((item) => item.id == id) ||

        _store.supportingEvidence.any((item) => item.id == id);

  }



  bool _isSupportingEvidence(String id) =>

      _store.supportingEvidence.any((item) => item.id == id);



  void _touchIncident() {

    _store.incident = _store.incident.copyWith(updatedAt: DateTime.now());

  }

}

