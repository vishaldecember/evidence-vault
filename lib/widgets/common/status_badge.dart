import 'package:flutter/material.dart';

import '../../models/journey_stage.dart';
import '../../services/narrative_validation_service.dart';

/// Official incident state indicator for [StatusBadge].
///
/// Design-system readiness / quality states — not the domain lifecycle enum in
/// `domain/incident/incident_status.dart` (`draft` / `active` / …).
///
/// If both types are needed in one library, import this file with a prefix:
/// `import '.../status_badge.dart' as indicators;`
enum IncidentStatus {
  building,
  needsReview,
  ready,
  incomplete,
  archived,
  exported,
  verified;

  /// Uppercase badge copy.
  String get label => switch (this) {
        IncidentStatus.building => 'BUILDING',
        IncidentStatus.needsReview => 'NEEDS REVIEW',
        IncidentStatus.ready => 'READY',
        IncidentStatus.incomplete => 'INCOMPLETE',
        IncidentStatus.archived => 'ARCHIVED',
        IncidentStatus.exported => 'EXPORTED',
        IncidentStatus.verified => 'VERIFIED',
      };

  /// Maps journey maturity + optional reconstruction health to a badge status.
  static IncidentStatus resolve({
    required JourneyStage journeyStage,
    ReconstructionHealthStatus? health,
  }) {
    if (health == ReconstructionHealthStatus.needsReview) {
      return IncidentStatus.needsReview;
    }
    if (journeyStage == JourneyStage.empty) {
      return IncidentStatus.incomplete;
    }
    if (health == ReconstructionHealthStatus.incomplete &&
        (journeyStage == JourneyStage.rich ||
            journeyStage == JourneyStage.reflective)) {
      return IncidentStatus.incomplete;
    }
    if (journeyStage == JourneyStage.rich ||
        journeyStage == JourneyStage.reflective) {
      return IncidentStatus.ready;
    }
    return IncidentStatus.building;
  }

  static IncidentStatus fromJourneyStage(JourneyStage stage) => resolve(
        journeyStage: stage,
      );

  static IncidentStatus fromReconstructionHealth(
    ReconstructionHealthStatus health,
  ) =>
      switch (health) {
        ReconstructionHealthStatus.excellent => IncidentStatus.ready,
        ReconstructionHealthStatus.needsReview => IncidentStatus.needsReview,
        ReconstructionHealthStatus.incomplete => IncidentStatus.incomplete,
      };

  /// Best-effort parse of legacy display strings (Trust Package, etc.).
  static IncidentStatus? tryParse(String raw) {
    final normalized = raw.trim().toLowerCase();
    return switch (normalized) {
      'building' || 'build' => IncidentStatus.building,
      'needs review' || 'needs_review' || 'needsreview' =>
        IncidentStatus.needsReview,
      'ready' || 'rich' || 'reflective' || 'excellent' || 'healthy' ||
      'complete' =>
        IncidentStatus.ready,
      'incomplete' || 'empty' || 'missing' || 'review required' =>
        IncidentStatus.incomplete,
      'archived' => IncidentStatus.archived,
      'exported' => IncidentStatus.exported,
      'verified' => IncidentStatus.verified,
      'verification pending' => IncidentStatus.needsReview,
      _ => null,
    };
  }
}

/// Premium digital incident state badge — single source of truth for status UI.
///
/// Prefer this over ad-hoc chips, coloured labels, or Material [Chip]s.
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.status,
  });

  final IncidentStatus status;

  static const double radius = 11;

  @override
  Widget build(BuildContext context) {
    final palette = _StatusBadgePalette.forStatus(status);

    return Semantics(
      label: 'Status ${status.label}',
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              palette.highlight,
              palette.background,
            ],
          ),
          border: Border.all(color: palette.border, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: palette.dot,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                status.label,
                style: TextStyle(
                  color: palette.text,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.55,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadgePalette {
  const _StatusBadgePalette({
    required this.background,
    required this.highlight,
    required this.border,
    required this.text,
    required this.dot,
  });

  final Color background;
  final Color highlight;
  final Color border;
  final Color text;
  final Color dot;

  static _StatusBadgePalette forStatus(IncidentStatus status) =>
      switch (status) {
        IncidentStatus.building => const _StatusBadgePalette(
            background: Color(0xFFFFF7ED),
            highlight: Color(0xFFFFFBF5),
            border: Color(0xFFF59E0B),
            text: Color(0xFF92400E),
            dot: Color(0xFFF59E0B),
          ),
        IncidentStatus.needsReview => const _StatusBadgePalette(
            background: Color(0xFFFFFBEB),
            highlight: Color(0xFFFFFDF5),
            border: Color(0xFFB45309),
            text: Color(0xFF92400E),
            dot: Color(0xFFEAB308),
          ),
        IncidentStatus.ready => const _StatusBadgePalette(
            background: Color(0xFFECFDF5),
            highlight: Color(0xFFF0FDF8),
            border: Color(0xFF10B981),
            text: Color(0xFF065F46),
            dot: Color(0xFF10B981),
          ),
        IncidentStatus.incomplete => const _StatusBadgePalette(
            background: Color(0xFFFEF2F2),
            highlight: Color(0xFFFFF5F5),
            border: Color(0xFFEF4444),
            text: Color(0xFF991B1B),
            dot: Color(0xFFEF4444),
          ),
        // Future statuses — calm neutral until dedicated palettes ship.
        IncidentStatus.archived ||
        IncidentStatus.exported ||
        IncidentStatus.verified =>
          const _StatusBadgePalette(
            background: Color(0xFFF8FAFC),
            highlight: Color(0xFFFCFCFD),
            border: Color(0xFF94A3B8),
            text: Color(0xFF334155),
            dot: Color(0xFF64748B),
          ),
      };
}
