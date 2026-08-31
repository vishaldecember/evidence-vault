import '../models/library_incident_record.dart';
import '../models/library_insight_model.dart';
import '../models/library_insight_type.dart';
import '../models/workspace_evidence_item.dart';
import 'library_insight_engine.dart';

/// Rule-based cross-incident pattern detection from observable library facts.
class RuleBasedLibraryInsightEngine implements LibraryInsightEngine {
  const RuleBasedLibraryInsightEngine();

  static const _minimumIncidents = 2;

  static int _counter = 0;

  static String _nextId() {
    _counter += 1;
    return 'library-insight-$_counter';
  }

  @override
  List<LibraryInsightModel> generateInsights(LibraryInsightContext context) {
    if (context.incidentCount < _minimumIncidents) {
      return const [];
    }

    final insights = <LibraryInsightModel>[
      ..._sharedLocationInsights(context.incidents),
      ..._sharedOrganisationInsights(context.incidents),
      ..._sharedPersonInsights(context.incidents),
      ..._similarTimePeriodInsights(context.incidents),
      ..._recurringEvidenceTypeInsights(context.incidents),
    ];

    insights.sort((a, b) => b.incidentCount.compareTo(a.incidentCount));
    return insights;
  }

  List<LibraryInsightModel> _sharedLocationInsights(
    List<LibraryIncidentRecord> incidents,
  ) {
    return _groupedStringInsights(
      incidents: incidents,
      valueSelector: (incident) => incident.location,
      type: LibraryInsightType.sharedLocation,
      messageBuilder: (subject, count) {
        final incidentWord = count == 1 ? 'incident' : 'incidents';
        return 'This location appears in $count preserved $incidentWord.';
      },
    );
  }

  List<LibraryInsightModel> _sharedOrganisationInsights(
    List<LibraryIncidentRecord> incidents,
  ) {
    return _groupedStringInsights(
      incidents: incidents,
      valueSelector: (incident) => incident.organisation,
      type: LibraryInsightType.sharedOrganisation,
      messageBuilder: (subject, count) {
        final incidentWord = count == 1 ? 'incident' : 'incidents';
        return 'This organisation is referenced in $count $incidentWord.';
      },
    );
  }

  List<LibraryInsightModel> _sharedPersonInsights(
    List<LibraryIncidentRecord> incidents,
  ) {
    final grouped = <String, List<LibraryIncidentRecord>>{};

    for (final incident in incidents) {
      for (final person in incident.referencedPeople) {
        final key = _normalize(person);
        if (key.isEmpty) {
          continue;
        }
        grouped.putIfAbsent(key, () => []).add(incident);
      }
    }

    final insights = <LibraryInsightModel>[];

    for (final entry in grouped.entries) {
      final uniqueIncidents = _uniqueIncidents(entry.value);
      if (uniqueIncidents.length < _minimumIncidents) {
        continue;
      }

      final count = uniqueIncidents.length;
      final displayName = entry.value
          .expand((incident) => incident.referencedPeople)
          .firstWhere((person) => _normalize(person) == entry.key);
      final incidentWord = count == 1 ? 'incident' : 'incidents';

      insights.add(
        LibraryInsightModel(
          id: _nextId(),
          type: LibraryInsightType.sharedPersonOrWitness,
          subject: displayName,
          incidentCount: count,
          relatedIncidentIds: uniqueIncidents.map((item) => item.id).toList(),
          message: '$displayName is referenced in $count $incidentWord.',
        ),
      );
    }

    return insights;
  }

  List<LibraryInsightModel> _similarTimePeriodInsights(
    List<LibraryIncidentRecord> incidents,
  ) {
    final grouped = <String, List<LibraryIncidentRecord>>{};

    for (final incident in incidents) {
      final key =
          '${incident.preservedAt.year}-${incident.preservedAt.month.toString().padLeft(2, '0')}';
      grouped.putIfAbsent(key, () => []).add(incident);
    }

    final insights = <LibraryInsightModel>[];

    for (final entry in grouped.entries) {
      final uniqueIncidents = _uniqueIncidents(entry.value);
      if (uniqueIncidents.length < _minimumIncidents) {
        continue;
      }

      final count = uniqueIncidents.length;
      final incidentWord = count == 1 ? 'incident' : 'incidents';

      insights.add(
        LibraryInsightModel(
          id: _nextId(),
          type: LibraryInsightType.similarTimePeriod,
          subject: entry.key,
          incidentCount: count,
          relatedIncidentIds: uniqueIncidents.map((item) => item.id).toList(),
          message: '$count $incidentWord occurred within a similar time period.',
        ),
      );
    }

    return insights;
  }

  List<LibraryInsightModel> _recurringEvidenceTypeInsights(
    List<LibraryIncidentRecord> incidents,
  ) {
    final grouped = <WorkspaceEvidenceKind, List<LibraryIncidentRecord>>{};

    for (final incident in incidents) {
      for (final evidenceType in incident.evidenceTypes.toSet()) {
        grouped.putIfAbsent(evidenceType, () => []).add(incident);
      }
    }

    final insights = <LibraryInsightModel>[];

    for (final entry in grouped.entries) {
      final uniqueIncidents = _uniqueIncidents(entry.value);
      if (uniqueIncidents.length < _minimumIncidents) {
        continue;
      }

      final count = uniqueIncidents.length;
      final typeLabel = entry.key.label;
      final incidentWord = count == 1 ? 'incident' : 'incidents';

      insights.add(
        LibraryInsightModel(
          id: _nextId(),
          type: LibraryInsightType.recurringEvidenceType,
          subject: typeLabel,
          incidentCount: count,
          relatedIncidentIds: uniqueIncidents.map((item) => item.id).toList(),
          message: '$typeLabel appears in $count preserved $incidentWord.',
        ),
      );
    }

    return insights;
  }

  List<LibraryInsightModel> _groupedStringInsights({
    required List<LibraryIncidentRecord> incidents,
    required String? Function(LibraryIncidentRecord incident) valueSelector,
    required LibraryInsightType type,
    required String Function(String subject, int count) messageBuilder,
  }) {
    final grouped = <String, List<LibraryIncidentRecord>>{};

    for (final incident in incidents) {
      final value = valueSelector(incident);
      final key = _normalize(value);
      if (key.isEmpty) {
        continue;
      }
      grouped.putIfAbsent(key, () => []).add(incident);
    }

    final insights = <LibraryInsightModel>[];

    for (final entry in grouped.entries) {
      final uniqueIncidents = _uniqueIncidents(entry.value);
      if (uniqueIncidents.length < _minimumIncidents) {
        continue;
      }

      final count = uniqueIncidents.length;
      final displayValue = valueSelector(entry.value.first)!;

      insights.add(
        LibraryInsightModel(
          id: _nextId(),
          type: type,
          subject: displayValue,
          incidentCount: count,
          relatedIncidentIds: uniqueIncidents.map((item) => item.id).toList(),
          message: messageBuilder(displayValue, count),
        ),
      );
    }

    return insights;
  }

  List<LibraryIncidentRecord> _uniqueIncidents(
    List<LibraryIncidentRecord> incidents,
  ) {
    final seen = <String>{};
    final unique = <LibraryIncidentRecord>[];

    for (final incident in incidents) {
      if (seen.add(incident.id)) {
        unique.add(incident);
      }
    }

    return unique;
  }

  String _normalize(String? value) => value?.trim().toLowerCase() ?? '';
}
