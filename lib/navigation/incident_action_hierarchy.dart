import '../domain/organize/organize_readiness.dart';

/// Presentation-only visibility of Home continue actions.
///
/// Destinations remain [LibraryIncidentRoutes]. This does not assess, persist,
/// or invent readiness — it consumes the existing [OrganizeReadiness] snapshot.
///
/// Organize is reached through the workspace journey, not a Home continuation
/// step. Investigation uses the existing Organize-ready gate (Phase 3E) —
/// not evidence count alone, and not a new InvestigationReadiness engine.
abstract final class IncidentActionHierarchy {
  static const preserveLabel = 'Continue preserving';
  static const organizeLabel = 'Continue organizing';
  static const investigateLabel = 'Continue investigation';

  static IncidentActionVisibility from({
    required bool archived,
    OrganizeReadiness? readiness,
  }) {
    if (archived) {
      return const IncidentActionVisibility(
        showPreserve: false,
        showOrganize: false,
        showInvestigate: false,
      );
    }
    final organizeReady = readiness?.isReady == true;
    return IncidentActionVisibility(
      showPreserve: true,
      showOrganize: false,
      showInvestigate: organizeReady,
    );
  }
}

/// Which continue actions the Home card may show for one incident.
class IncidentActionVisibility {
  const IncidentActionVisibility({
    required this.showPreserve,
    required this.showOrganize,
    required this.showInvestigate,
  });

  final bool showPreserve;
  final bool showOrganize;
  final bool showInvestigate;
}
