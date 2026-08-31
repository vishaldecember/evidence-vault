import '../../domain/memory/memory_recall_item.dart';
import '../../models/library_incident_summary.dart';
import 'memory_recall_provider.dart';

/// Deterministic Memory Recall — no AI (Sprint 5D).
///
/// Uses only library incident summaries. Never fabricates memories.
class DeterministicMemoryRecallProvider implements MemoryRecallProvider {
  const DeterministicMemoryRecallProvider({
    this.maxItems = 3,
  });

  final int maxItems;

  static const Duration _oldThreshold = Duration(days: 90);
  static const Duration _recentChangeWindow = Duration(days: 7);
  static const Duration _firstIncidentWindow = Duration(days: 14);

  @override
  Future<List<MemoryRecallItem>> load(MemoryRecallContext context) async {
    if (context.incidents.isEmpty) {
      return const [];
    }

    final candidates = <MemoryRecallItem>[];
    for (final incident in context.incidents) {
      candidates.addAll(_candidatesFor(incident, context));
    }

    final filtered = [
      for (final item in candidates)
        if (!context.dismissedIds.contains(item.id)) item,
    ]..sort((a, b) => b.score.compareTo(a.score));

    // One card per incident — highest-scoring type wins.
    final seenIncidents = <String>{};
    final selected = <MemoryRecallItem>[];
    for (final item in filtered) {
      if (!seenIncidents.add(item.incidentId)) {
        continue;
      }
      selected.add(item);
      if (selected.length >= maxItems) {
        break;
      }
    }
    return selected;
  }

  @override
  MemoryMonthSummary monthSummary(MemoryRecallContext context) {
    final now = context.now;
    final start = DateTime(now.year, now.month);
    var evidence = 0;
    var touched = 0;
    var strengthened = 0;
    var ready = 0;

    for (final incident in context.incidents) {
      final created = incident.createdAt;
      final updated = incident.updatedAt ?? created;
      final touchedThisMonth =
          updated != null && !updated.isBefore(start);
      if (!touchedThisMonth) {
        continue;
      }
      touched++;
      // Count evidence only for incidents created this month — avoids
      // inflating "captured" with older incident totals that were merely opened.
      if (created != null && !created.isBefore(start)) {
        evidence += incident.evidenceCount;
      }
      if (incident.contextEnrichedCount > 0 || incident.narrativeCount > 0) {
        strengthened++;
      }
      if (!incident.isInProgress && incident.integrityVerified) {
        ready++;
      }
    }

    return MemoryMonthSummary(
      evidenceCaptured: evidence,
      incidentsTouched: touched,
      investigationsStrengthened: strengthened,
      becameReady: ready,
    );
  }

  List<MemoryRecallItem> _candidatesFor(
    LibraryIncidentSummary incident,
    MemoryRecallContext context,
  ) {
    final now = context.now;
    final updated = incident.updatedAt ?? incident.createdAt ?? now;
    final created = incident.createdAt ?? updated;
    final age = now.difference(updated);
    final createdAge = now.difference(created);
    final out = <MemoryRecallItem>[];

    String ageLabel() => _formatAge(age);

    // First / early investigation (gentle activation after first data).
    if (context.incidents.length == 1 && createdAge <= _firstIncidentWindow) {
      out.add(
        MemoryRecallItem(
          id: '${MemoryRecallType.buildingIncident.wireName}_${incident.id}',
          type: MemoryRecallType.buildingIncident,
          incidentId: incident.id,
          title: incident.title,
          headline: 'Your first investigation',
          reason: 'Captured ${_formatAge(createdAge)}.',
          action: MemoryRecallAction.reviewIncident,
          score: 88,
          createdAt: now,
          maturityLabel: incident.isInProgress ? 'Building' : null,
          evidenceCount: incident.evidenceCount,
          relationshipCount: incident.contextEnrichedCount,
          ageLabel: _formatAge(createdAge),
        ),
      );
    }

    if (incident.isInProgress) {
      out.add(
        MemoryRecallItem(
          id: '${MemoryRecallType.unresolvedIncident.wireName}_${incident.id}',
          type: MemoryRecallType.unresolvedIncident,
          incidentId: incident.id,
          title: incident.title,
          headline: 'Something you may want to revisit',
          reason: 'Still unresolved.',
          action: MemoryRecallAction.viewInvestigation,
          score: 70 + (age.inDays > 30 ? 10 : 0),
          createdAt: now,
          maturityLabel: 'Building',
          evidenceCount: incident.evidenceCount,
          relationshipCount: incident.contextEnrichedCount,
          ageLabel: ageLabel(),
        ),
      );
    }

    if (incident.isInProgress &&
        incident.evidenceCount > 0 &&
        incident.contextEnrichedCount == 0) {
      out.add(
        MemoryRecallItem(
          id: '${MemoryRecallType.unreviewedEvidence.wireName}_${incident.id}',
          type: MemoryRecallType.unreviewedEvidence,
          incidentId: incident.id,
          title: incident.title,
          headline: 'Evidence waiting for context',
          reason:
              'You captured ${incident.evidenceCount} evidence item${incident.evidenceCount == 1 ? '' : 's'} without relationships yet.',
          action: MemoryRecallAction.viewEvidence,
          score: 75,
          createdAt: now,
          maturityLabel: 'Building',
          evidenceCount: incident.evidenceCount,
          relationshipCount: 0,
          ageLabel: ageLabel(),
        ),
      );
    }

    if (incident.isInProgress &&
        incident.evidenceCount >= 1 &&
        incident.contextEnrichedCount == 0 &&
        incident.narrativeCount == 0) {
      out.add(
        MemoryRecallItem(
          id: '${MemoryRecallType.buildingIncident.wireName}_${incident.id}',
          type: MemoryRecallType.buildingIncident,
          incidentId: incident.id,
          title: incident.title,
          headline: 'Something you may want to revisit',
          reason: 'Investigation is still Building.',
          action: MemoryRecallAction.viewInvestigation,
          score: 65,
          createdAt: now,
          maturityLabel: 'Building',
          evidenceCount: incident.evidenceCount,
          relationshipCount: incident.contextEnrichedCount,
          ageLabel: ageLabel(),
        ),
      );
    }

    if (!incident.isInProgress &&
        incident.integrityVerified &&
        age <= _recentChangeWindow) {
      out.add(
        MemoryRecallItem(
          id: '${MemoryRecallType.recentlyChanged.wireName}_${incident.id}',
          type: MemoryRecallType.recentlyChanged,
          incidentId: incident.id,
          title: incident.title,
          headline: 'Something changed',
          reason: 'Investigation recently reached a stronger readiness state.',
          action: MemoryRecallAction.viewInvestigation,
          score: 82,
          createdAt: now,
          maturityLabel: 'Ready',
          evidenceCount: incident.evidenceCount,
          relationshipCount: incident.contextEnrichedCount,
          ageLabel: ageLabel(),
        ),
      );
    }

    if (age >= _oldThreshold) {
      out.add(
        MemoryRecallItem(
          id: '${MemoryRecallType.oldIncident.wireName}_${incident.id}',
          type: MemoryRecallType.oldIncident,
          incidentId: incident.id,
          title: incident.title,
          headline: 'You may have forgotten this',
          reason: 'Captured ${ageLabel()}.',
          action: MemoryRecallAction.reviewIncident,
          score: 55 + (incident.isInProgress ? 15 : 0),
          createdAt: now,
          maturityLabel: incident.isInProgress ? 'Building' : null,
          evidenceCount: incident.evidenceCount,
          relationshipCount: incident.contextEnrichedCount,
          ageLabel: ageLabel(),
        ),
      );
    }

    if (incident.evidenceCount >= 6) {
      out.add(
        MemoryRecallItem(
          id: '${MemoryRecallType.importantEvidence.wireName}_${incident.id}',
          type: MemoryRecallType.importantEvidence,
          incidentId: incident.id,
          title: incident.title,
          headline: 'A substantial record',
          reason:
              'You captured ${incident.evidenceCount} pieces of evidence in this incident.',
          action: MemoryRecallAction.viewEvidence,
          score: 60 + (incident.isInProgress ? 8 : 0),
          createdAt: now,
          evidenceCount: incident.evidenceCount,
          relationshipCount: incident.contextEnrichedCount,
          ageLabel: ageLabel(),
        ),
      );
    }

    return out;
  }

  static String _formatAge(Duration age) {
    if (age.inDays >= 365) {
      final years = (age.inDays / 365).floor();
      return years == 1 ? '1 year ago' : '$years years ago';
    }
    if (age.inDays >= 30) {
      final months = (age.inDays / 30).floor();
      return months == 1 ? '1 month ago' : '$months months ago';
    }
    if (age.inDays >= 1) {
      return age.inDays == 1 ? '1 day ago' : '${age.inDays} days ago';
    }
    if (age.inHours >= 1) {
      return age.inHours == 1 ? '1 hour ago' : '${age.inHours} hours ago';
    }
    return 'earlier today';
  }
}
