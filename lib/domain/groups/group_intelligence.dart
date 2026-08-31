import '../collection/evidence_collection.dart';
import '../participant/related_person_link.dart';

/// How a Groups observation was established.
enum GroupObservationSource {
  userProvided,
  representedInEvidence,
  inferred;

  String get label => switch (this) {
        GroupObservationSource.userProvided => 'User provided',
        GroupObservationSource.representedInEvidence => 'From evidence',
        GroupObservationSource.inferred => 'Inferred',
      };
}

class GroupPersonInsight {
  const GroupPersonInsight({
    required this.participantId,
    required this.name,
    required this.momentCount,
    required this.contextCount,
    required this.textContextCount,
    required this.voiceContextCount,
    required this.evidenceIds,
    required this.explanation,
    required this.source,
  });

  final String participantId;
  final String name;
  final int momentCount;
  final int contextCount;
  final int textContextCount;
  final int voiceContextCount;
  final List<String> evidenceIds;
  final String explanation;
  final GroupObservationSource source;
}

class GroupLocationInsight {
  const GroupLocationInsight({
    required this.id,
    required this.name,
    required this.momentCount,
    required this.evidenceIds,
    required this.explanation,
    required this.source,
  });

  final String id;
  final String name;
  final int momentCount;
  final List<String> evidenceIds;
  final String explanation;
  final GroupObservationSource source;
}

class GroupRelationshipInsight {
  const GroupRelationshipInsight({
    required this.id,
    required this.title,
    required this.explanation,
    required this.evidenceIds,
    required this.source,
  });

  final String id;
  final String title;
  final String explanation;
  final List<String> evidenceIds;
  final GroupObservationSource source;
}

class GroupPatternInsight {
  const GroupPatternInsight({
    required this.id,
    required this.title,
    required this.explanation,
    required this.evidenceIds,
    required this.qualification,
  });

  final String id;
  final String title;
  final String explanation;
  final List<String> evidenceIds;
  final String qualification;
}

class GroupIntelligenceSnapshot {
  const GroupIntelligenceSnapshot({
    this.people = const [],
    this.locations = const [],
    this.relationships = const [],
    this.patterns = const [],
    this.customGroups = const [],
  });

  final List<GroupPersonInsight> people;
  final List<GroupLocationInsight> locations;
  final List<GroupRelationshipInsight> relationships;
  final List<GroupPatternInsight> patterns;
  final List<EvidenceCollection> customGroups;
}

/// Lightweight evidence facts the Groups engine may read.
class GroupEvidenceFact {
  const GroupEvidenceFact({
    required this.id,
    required this.title,
    required this.isMoment,
    required this.isTextContext,
    required this.isVoiceContext,
    required this.people,
    this.latitude,
    this.longitude,
    this.locationName,
  });

  final String id;
  final String title;
  final bool isMoment;
  final bool isTextContext;
  final bool isVoiceContext;
  final List<RelatedPersonLink> people;
  final double? latitude;
  final double? longitude;
  final String? locationName;
}
