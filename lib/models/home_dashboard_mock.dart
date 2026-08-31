import 'package:flutter/material.dart';

import 'library_incident_record.dart';
import 'library_incident_summary.dart';
import 'workspace_evidence_item.dart';

/// Presentation-layer mock data for the Home dashboard (Sprint 3.4).
/// Replaced by real incident state in Sprint 4.
abstract final class HomeDashboardMock {
  static const activeIncident = ActiveIncidentSummary(
    statusLabel: 'Draft Incident',
    lastUpdated: 'Today • 2 minutes ago',
    evidenceSummary: [
      EvidenceSummaryItem(
        icon: Icons.photo_camera_outlined,
        label: '3 Photos',
      ),
      EvidenceSummaryItem(
        icon: Icons.mic_outlined,
        label: '1 Voice Note',
      ),
      EvidenceSummaryItem(
        icon: Icons.edit_note_outlined,
        label: '1 Note',
      ),
    ],
  );

  /// When null, no in-progress incident shows Resume in the Library.
  static ActiveIncidentSummary? unfinishedIncident = activeIncident;

  /// When empty, the Home Library shows the aspirational preview.
  static List<LibraryIncidentSummary> libraryIncidents = [];

  /// Preserved incidents analyzed for cross-incident Library Intelligence.
  static List<LibraryIncidentRecord> libraryIncidentRecords =
      activeLibraryIncidentRecords;

  static final activeLibraryIncidentRecords = [
    LibraryIncidentRecord(
      id: 'incident-workplace-concern',
      title: 'Workplace Concern',
      preservedAt: DateTime(2026, 7, 29, 14, 30),
      location: 'Harbour Office, Level 3',
      organisation: 'Northbridge Consulting',
      referencedPeople: ['Alex Morgan'],
      evidenceTypes: [
        WorkspaceEvidenceKind.image,
        WorkspaceEvidenceKind.voice,
        WorkspaceEvidenceKind.note,
      ],
    ),
    LibraryIncidentRecord(
      id: 'incident-commute-incident',
      title: 'Commute Incident',
      preservedAt: DateTime(2026, 7, 27, 8, 15),
      location: 'Harbour Office, Level 3',
      organisation: 'Northbridge Consulting',
      referencedPeople: ['Alex Morgan', 'Jordan Lee'],
      evidenceTypes: [
        WorkspaceEvidenceKind.image,
        WorkspaceEvidenceKind.note,
      ],
    ),
    LibraryIncidentRecord(
      id: 'incident-vehicle-damage',
      title: 'Vehicle Damage',
      preservedAt: DateTime(2026, 7, 28, 17, 45),
      location: 'Central Parking Structure',
      organisation: 'City Parking Services',
      referencedPeople: ['Jordan Lee'],
      evidenceTypes: [
        WorkspaceEvidenceKind.image,
        WorkspaceEvidenceKind.attachment,
      ],
    ),
  ];

  static const activeLibraryIncidents = [
    LibraryIncidentSummary(
      id: 'incident-workplace-concern',
      title: 'Workplace Concern',
      evidenceCount: 5,
      contextEnrichedCount: 1,
      integrityVerified: true,
      lastPreserved: 'Today • 2 minutes ago',
      narrativeCount: 2,
      isInProgress: true,
    ),
  ];

  static const recentActivity = [
    RecentActivityEntry(
      icon: Icons.photo_camera_outlined,
      title: 'Photo added',
      relativeTimestamp: '2 minutes ago',
    ),
    RecentActivityEntry(
      icon: Icons.mic_outlined,
      title: 'Voice note added',
      relativeTimestamp: '18 minutes ago',
    ),
    RecentActivityEntry(
      icon: Icons.edit_note_outlined,
      title: 'Text note added',
      relativeTimestamp: '1 hour ago',
    ),
  ];

  static void resetToEmpty() {
    unfinishedIncident = null;
    libraryIncidents = [];
    libraryIncidentRecords = [];
  }
}

class ActiveIncidentSummary {
  const ActiveIncidentSummary({
    required this.statusLabel,
    required this.lastUpdated,
    required this.evidenceSummary,
  });

  final String statusLabel;
  final String lastUpdated;
  final List<EvidenceSummaryItem> evidenceSummary;
}

class EvidenceSummaryItem {
  const EvidenceSummaryItem({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;
}

class RecentActivityEntry {
  const RecentActivityEntry({
    required this.icon,
    required this.title,
    required this.relativeTimestamp,
  });

  final IconData icon;
  final String title;
  final String relativeTimestamp;
}
