import '../services/workspace_coaching_service.dart';



/// Maturity stages for Incident Status visualization.

///

/// Derived exclusively from [EnrichmentEngine] via [EnrichmentSnapshot].

/// UI components receive a [JourneyStage] value — they do not compute it.

enum JourneyStage {

  empty,

  building,

  rich,

  reflective;



  /// Permanent timeline order for display.

  static const List<JourneyStage> timeline = [

    JourneyStage.empty,

    JourneyStage.building,

    JourneyStage.rich,

  ];



  String get label => switch (this) {

        JourneyStage.empty => 'EMPTY',

        JourneyStage.building => 'BUILDING',

        JourneyStage.rich => 'RICH',

        JourneyStage.reflective => 'REFLECTIVE',

      };



  /// Actionable coaching for this stage — sourced from [WorkspaceCoachingService].

  String get coachingCopy => WorkspaceCoachingService.messageForStage(this);



  /// Alias retained for existing presentation widgets.

  String get canonicalCopy => coachingCopy;



  /// Alias for presentation widgets.

  String get description => coachingCopy;



  /// Human-readable stage name for [IncidentOverviewCard].

  String get overviewLabel => switch (this) {

        JourneyStage.empty => 'Empty',

        JourneyStage.building => 'Building',

        JourneyStage.rich => 'Rich',

        JourneyStage.reflective => 'Reflective',

      };

}


