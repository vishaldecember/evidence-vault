import '../../domain/collection/evidence_collection.dart';
import '../../domain/groups/group_intelligence.dart';
import '../../domain/participant/related_person_link.dart';
import '../../models/workspace_evidence_item.dart';

/// Derives Groups intelligence from stored evidence/context relationships.
///
/// Does not invent people, locations, relationships, or patterns. Empty
/// when the underlying facts are missing.
abstract final class GroupIntelligenceEngine {
  static GroupIntelligenceSnapshot derive({
    required List<WorkspaceEvidenceItem> evidence,
    required List<EvidenceCollection> collections,
  }) {
    final facts = [
      for (final item in evidence) _factFor(item),
    ];
    final people = _people(facts, collections);
    final locations = _locations(facts, collections);
    final relationships = _relationships(people);
    final patterns = _patterns(people, locations, relationships);
    final customGroups = [
      for (final collection in collections)
        if ((collection.category == null || collection.category == 'custom') &&
            collection.memberEvidenceIds.isNotEmpty)
          collection,
    ]..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    return GroupIntelligenceSnapshot(
      people: people,
      locations: locations,
      relationships: relationships,
      patterns: patterns,
      customGroups: customGroups,
    );
  }

  static GroupEvidenceFact _factFor(WorkspaceEvidenceItem item) {
    final isContext = item.isContextual || !item.kind.isPrimaryChronology;
    return GroupEvidenceFact(
      id: item.id,
      title: item.title,
      isMoment: item.kind.isPrimaryChronology && !item.isContextual,
      isTextContext: isContext && item.kind == WorkspaceEvidenceKind.note,
      isVoiceContext: isContext && item.kind == WorkspaceEvidenceKind.voice,
      people: item.relatedPeople.isNotEmpty
          ? item.relatedPeople
          : [
              if ((item.relatedPersonName ?? '').trim().isNotEmpty)
                RelatedPersonLink(
                  participantId: item.participantId ?? '',
                  displayName: item.relatedPersonName!.trim(),
                  roleName: item.relatedPersonRole,
                ),
            ],
      latitude: item.latitude,
      longitude: item.longitude,
    );
  }

  static List<GroupPersonInsight> _people(
    List<GroupEvidenceFact> facts,
    List<EvidenceCollection> collections,
  ) {
    final byId = <String, _PersonAccumulator>{};
    void addLink(RelatedPersonLink link, GroupEvidenceFact fact) {
      final key = link.participantId.trim().isNotEmpty
          ? link.participantId
          : 'name:${link.displayName.trim().toLowerCase()}';
      final acc = byId.putIfAbsent(
        key,
        () => _PersonAccumulator(
          participantId: key,
          name: link.displayName.trim(),
        ),
      );
      acc.evidenceIds.add(fact.id);
      if (fact.isMoment) {
        acc.momentIds.add(fact.id);
      }
      if (fact.isTextContext) {
        acc.textIds.add(fact.id);
      }
      if (fact.isVoiceContext) {
        acc.voiceIds.add(fact.id);
      }
    }

    for (final fact in facts) {
      for (final person in fact.people) {
        if (person.displayName.trim().isEmpty) {
          continue;
        }
        addLink(person, fact);
      }
    }

    for (final collection in collections) {
      if (collection.pending || collection.category != 'personParticipant') {
        continue;
      }
      final name = collection.name.trim();
      if (name.isEmpty || collection.memberEvidenceIds.isEmpty) {
        continue;
      }
      final key = 'collection:${collection.id}';
      final existing = [
        for (final acc in byId.values)
          if (acc.name.toLowerCase() == name.toLowerCase()) acc,
      ];
      final acc = existing.isNotEmpty
          ? existing.first
          : byId.putIfAbsent(
              key,
              () => _PersonAccumulator(participantId: key, name: name),
            );
      acc.userProvided = true;
      for (final id in collection.memberEvidenceIds) {
        acc.evidenceIds.add(id);
        GroupEvidenceFact? fact;
        for (final candidate in facts) {
          if (candidate.id == id) {
            fact = candidate;
            break;
          }
        }
        if (fact == null) {
          continue;
        }
        if (fact.isMoment) {
          acc.momentIds.add(id);
        }
        if (fact.isTextContext) {
          acc.textIds.add(id);
        }
        if (fact.isVoiceContext) {
          acc.voiceIds.add(id);
        }
      }
    }

    final insights = [
      for (final acc in byId.values)
        if (acc.evidenceIds.isNotEmpty)
          GroupPersonInsight(
            participantId: acc.participantId,
            name: acc.name,
            momentCount: acc.momentIds.length,
            contextCount: acc.textIds.length + acc.voiceIds.length,
            textContextCount: acc.textIds.length,
            voiceContextCount: acc.voiceIds.length,
            evidenceIds: acc.evidenceIds.toList(),
            explanation: _personExplanation(acc),
            source: acc.userProvided
                ? GroupObservationSource.userProvided
                : GroupObservationSource.representedInEvidence,
          ),
    ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return insights;
  }

  static String _personExplanation(_PersonAccumulator acc) {
    final parts = <String>[];
    if (acc.momentIds.isNotEmpty) {
      parts.add(
        '${acc.momentIds.length} preserved '
        '${acc.momentIds.length == 1 ? 'moment' : 'moments'}',
      );
    }
    if (acc.textIds.isNotEmpty) {
      parts.add(
        '${acc.textIds.length} text '
        '${acc.textIds.length == 1 ? 'context' : 'contexts'}',
      );
    }
    if (acc.voiceIds.isNotEmpty) {
      parts.add(
        '${acc.voiceIds.length} voice '
        '${acc.voiceIds.length == 1 ? 'context' : 'contexts'}',
      );
    }
    if (parts.isEmpty) {
      return 'Identified on ${acc.evidenceIds.length} '
          '${acc.evidenceIds.length == 1 ? 'item' : 'items'}.';
    }
    if (parts.length == 1) {
      return 'Identified in ${parts.first}.';
    }
    if (parts.length == 2) {
      return 'Identified in ${parts[0]} and referenced in ${parts[1]}.';
    }
    return 'Identified in ${parts[0]}, ${parts[1]}, and ${parts[2]}.';
  }

  static List<GroupLocationInsight> _locations(
    List<GroupEvidenceFact> facts,
    List<EvidenceCollection> collections,
  ) {
    final insights = <GroupLocationInsight>[];
    for (final collection in collections) {
      if (collection.pending || collection.category != 'location') {
        continue;
      }
      final name = collection.name.trim();
      if (name.isEmpty || collection.memberEvidenceIds.isEmpty) {
        continue;
      }
      final members = collection.memberEvidenceIds;
      var moments = 0;
      for (final id in members) {
        for (final fact in facts) {
          if (fact.id == id && fact.isMoment) {
            moments += 1;
          }
        }
      }
      insights.add(
        GroupLocationInsight(
          id: collection.id,
          name: name,
          momentCount: moments,
          evidenceIds: members,
          explanation: moments == 0
              ? 'Associated with ${members.length} '
                  '${members.length == 1 ? 'item' : 'items'}.'
              : 'Appears across $moments preserved '
                  '${moments == 1 ? 'moment' : 'moments'}.',
          source: GroupObservationSource.userProvided,
        ),
      );
    }
    insights.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return insights;
  }

  static List<GroupRelationshipInsight> _relationships(
    List<GroupPersonInsight> people,
  ) {
    final insights = <GroupRelationshipInsight>[];
    for (var i = 0; i < people.length; i++) {
      for (var j = i + 1; j < people.length; j++) {
        final left = people[i];
        final right = people[j];
        final shared = [
          for (final id in left.evidenceIds)
            if (right.evidenceIds.contains(id)) id,
        ];
        if (shared.isEmpty) {
          continue;
        }
        insights.add(
          GroupRelationshipInsight(
            id: '${left.participantId}::${right.participantId}',
            title: '${left.name} ↔ ${right.name}',
            explanation: shared.length == 1
                ? 'Both appear in the same preserved moment.'
                : 'Both appear in ${shared.length} preserved moments.',
            evidenceIds: shared,
            source: GroupObservationSource.inferred,
          ),
        );
      }
    }
    for (final person in people) {
      if (person.momentCount < 2) {
        continue;
      }
      insights.add(
        GroupRelationshipInsight(
          id: '${person.participantId}::incident',
          title: '${person.name} → Incident',
          explanation:
              '${person.name} is referenced across ${person.momentCount} '
              'preserved moments.',
          evidenceIds: person.evidenceIds,
          source: GroupObservationSource.representedInEvidence,
        ),
      );
    }
    return insights;
  }

  static List<GroupPatternInsight> _patterns(
    List<GroupPersonInsight> people,
    List<GroupLocationInsight> locations,
    List<GroupRelationshipInsight> relationships,
  ) {
    final insights = <GroupPatternInsight>[];
    for (final pair in relationships) {
      if (!pair.title.contains('↔') || pair.evidenceIds.length < 2) {
        continue;
      }
      insights.add(
        GroupPatternInsight(
          id: 'pattern-contact-${pair.id}',
          title: 'Repeated contact',
          explanation:
              'Similar contact appears across ${pair.evidenceIds.length} '
              'preserved moments.',
          evidenceIds: pair.evidenceIds,
          qualification: 'Inferred from repeated co-appearance.',
        ),
      );
    }
    for (final person in people) {
      if (person.momentCount < 3) {
        continue;
      }
      insights.add(
        GroupPatternInsight(
          id: 'pattern-presence-${person.participantId}',
          title: 'Repeated presence',
          explanation:
              '${person.name} appears across ${person.momentCount} '
              'preserved moments.',
          evidenceIds: person.evidenceIds,
          qualification: 'Inferred from repeated identification.',
        ),
      );
    }
    for (final location in locations) {
      if (location.momentCount < 2) {
        continue;
      }
      insights.add(
        GroupPatternInsight(
          id: 'pattern-location-${location.id}',
          title: 'Repeated occurrence at the same location',
          explanation:
              'Related moments are associated with ${location.name}.',
          evidenceIds: location.evidenceIds,
          qualification: 'Inferred from repeated location association.',
        ),
      );
    }
    return insights;
  }
}

class _PersonAccumulator {
  _PersonAccumulator({
    required this.participantId,
    required this.name,
  });

  final String participantId;
  final String name;
  final Set<String> evidenceIds = {};
  final Set<String> momentIds = {};
  final Set<String> textIds = {};
  final Set<String> voiceIds = {};
  bool userProvided = false;
}
