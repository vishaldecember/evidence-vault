import 'package:flutter/material.dart';

import '../../controllers/workspace_session.dart';
import '../../domain/incident/incident_composition.dart';
import '../../engines/library_insight_engine.dart';
import '../../engines/rule_based_library_insight_engine.dart';
import '../../models/library_incident_summary.dart';
import '../../models/library_insight_model.dart';
import '../../constants/app_spacing.dart';
import '../../navigation/incident_action_hierarchy.dart';
import '../../navigation/incident_workspace_entry.dart';
import '../../services/persistence/incident_library_service.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_text_styles.dart';
import 'first_incident_card.dart';
import 'home_incident_display_state.dart';
import 'quick_capture_button.dart';
import 'quick_capture_section.dart';
import 'library_of_truth_section.dart';
import 'session_resume_card.dart';
import '../library/library_insights_section.dart';

/// Fallback until the sticky Capture Layer is measured on first layout.
const double kHomeCaptureLayerFallbackHeight = 280;

/// Composes the Home Launch Pad into scrollable content and a sticky Capture Layer.
class HomeBody extends StatefulWidget {
  const HomeBody({
    super.key,
    required this.onCaptureTap,
    required this.onContinueCapture,
    required this.onResume,
    required this.onIncidentTap,
    required this.onCaptureNewIncident,
    this.libraryInsightEngine = const RuleBasedLibraryInsightEngine(),
  });

  final ValueChanged<QuickCaptureType> onCaptureTap;
  final ValueChanged<String> onContinueCapture;
  final ValueChanged<String> onResume;
  final ValueChanged<String> onIncidentTap;
  final VoidCallback onCaptureNewIncident;
  final LibraryInsightEngine libraryInsightEngine;

  @override
  State<HomeBody> createState() => _HomeBodyState();
}

class _HomeBodyState extends State<HomeBody> {
  final GlobalKey _captureLayerKey = GlobalKey();
  double _captureLayerHeight = kHomeCaptureLayerFallbackHeight;

  @override
  void initState() {
    super.initState();
    IncidentLibraryService.instance.refresh();
    WidgetsBinding.instance.addPostFrameCallback(_measureCaptureLayer);
  }

  @override
  void didUpdateWidget(HomeBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback(_measureCaptureLayer);
  }

  List<LibraryInsightModel> _computeLibraryInsights() {
    return widget.libraryInsightEngine.generateInsights(
      LibraryInsightContext(
        incidents: [
          for (final record in IncidentLibraryService.instance.records)
            if (!IncidentLibraryService.instance.isRecentlyDeletedId(record.id))
              record,
        ],
      ),
    );
  }

  void _measureCaptureLayer(_) {
    final captureContext = _captureLayerKey.currentContext;
    if (captureContext == null) {
      return;
    }

    final measuredHeight = captureContext.size?.height;
    if (measuredHeight == null ||
        measuredHeight <= 0 ||
        measuredHeight == _captureLayerHeight) {
      return;
    }

    setState(() => _captureLayerHeight = measuredHeight);
  }

  @override
  Widget build(BuildContext context) {
    final session = WorkspaceSession.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([
        IncidentLibraryService.instance,
        session,
        session.controller,
      ]),
      builder: (context, _) {
        final currentIncident = session.controller.currentIncident;
        final composition = IncidentComposition.fromStore(
          session.controller.aggregate.store,
        );
        final display = HomeIncidentDisplayState.resolve(
          libraryIncidents: IncidentLibraryService.instance.summaries,
          sessionIncidentId: currentIncident.id,
          sessionTitle: currentIncident.title,
          sessionEvidenceCount: composition.evidenceCount,
          sessionNarrativeCount: currentIncident.narrativeEventCount,
          sessionContextEnrichedCount: composition.contextEnrichedCount,
        );
        final libraryInsights = _computeLibraryInsights();

        return _buildLayout(display: display, libraryInsights: libraryInsights);
      },
    );
  }

  Widget _buildLayout({
    required HomeIncidentDisplayState display,
    required List<LibraryInsightModel> libraryInsights,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          fit: StackFit.expand,
          children: [
            NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is ScrollStartNotification) {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                }
                return false;
              },
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: AnimatedPadding(
                  duration: AppMotion.layer,
                  curve: AppMotion.enter,
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.screenHorizontal,
                    AppSpacing.xxs,
                    AppSpacing.screenHorizontal,
                    _captureLayerHeight + AppSpacing.sm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: AppSpacing.xxs),
                      Center(
                        child: ExcludeSemantics(
                          child: SizedBox(
                            width: 112,
                            height: 80,
                            child: Image.asset(
                              'assets/images/branding/splash_logo.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Preserve your truth now.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.heroTitle.copyWith(
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Protect that matters later',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.heroSubtitle.copyWith(
                          height: 1.45,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      if (display.kind ==
                          HomeIncidentDisplayKind.firstIncident) ...[
                        FirstIncidentCard(
                          onCaptureNewIncident: widget.onCaptureNewIncident,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ] else if (display.kind ==
                              HomeIncidentDisplayKind.continuePreserving &&
                          display.continueIncident != null) ...[
                        _ContinueCard(
                          incident: display.continueIncident!,
                          sessionIncidentId: WorkspaceSession
                              .instance.controller.currentIncident.id,
                          onContinueCapture: widget.onContinueCapture,
                          onContinueInvestigation: widget.onResume,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      LibraryOfTruthSection(
                        incidents: display.visibleLibraryIncidents,
                        onIncidentTap: widget.onIncidentTap,
                      ),
                      if (libraryInsights.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.lg),
                        LibraryInsightsSection(insights: libraryInsights),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: AppSpacing.md,
              right: AppSpacing.md,
              bottom: AppSpacing.xs,
              child: KeyedSubtree(
                key: _captureLayerKey,
                child: QuickCaptureSection(onCaptureTap: widget.onCaptureTap),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Home continue card — action visibility from existing Organize readiness.
class _ContinueCard extends StatelessWidget {
  const _ContinueCard({
    required this.incident,
    required this.sessionIncidentId,
    required this.onContinueCapture,
    required this.onContinueInvestigation,
  });

  final LibraryIncidentSummary incident;
  final String sessionIncidentId;
  final ValueChanged<String> onContinueCapture;
  final ValueChanged<String> onContinueInvestigation;

  @override
  Widget build(BuildContext context) {
    final sessionMatches = sessionIncidentId.trim() == incident.id.trim();
    final readiness = sessionMatches
        ? IncidentWorkspaceEntry.tryAssess(
            WorkspaceSession.instance.controller,
          )
        : null;
    final visibility = IncidentActionHierarchy.from(
      archived: incident.isArchived,
      readiness: readiness,
    );
    return SessionResumeCard(
      incidentTitle: incident.title,
      evidenceCount: incident.evidenceCount,
      lastActivityLabel: incident.lastPreserved,
      onContinueCapture: () => onContinueCapture(incident.id),
      onContinueInvestigation: visibility.showInvestigate
          ? () => onContinueInvestigation(incident.id)
          : null,
    );
  }
}
