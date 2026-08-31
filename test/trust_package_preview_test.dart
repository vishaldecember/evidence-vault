import 'package:evidence_vault/controllers/workspace_evidence_controller.dart';
import 'package:evidence_vault/domain/trust_package/trust_package.dart';
import 'package:evidence_vault/domain/trust_package/trust_package_assembler.dart';
import 'package:evidence_vault/models/evidence_relationship.dart';
import 'package:evidence_vault/models/verification_factory.dart';
import 'package:evidence_vault/models/workspace_evidence_item.dart';
import 'package:evidence_vault/repositories/narrative_event_repository.dart';
import 'package:evidence_vault/screens/trust_package_screen.dart';
import 'package:evidence_vault/services/trust_package_scorecard_service.dart';
import 'package:evidence_vault/widgets/trust_package/preview/trust_package_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

TrustPackage _samplePackage() {
  final date = DateTime(2026, 7, 28, 12);
  return TrustPackage(
    incidentSummary: TrustPackageIncidentSummary(
      incidentName: 'Workplace Incident',
      incidentType: 'General Incident',
      incidentStatus: 'Active',
      dateCreated: date,
      dateUpdated: date,
      investigationConfidence: 'Building',
      reconstructionHealth: 'Needs Review',
    ),
    investigationSummary: TrustPackageInvestigationSummary(
      timelineAnchorCount: 2,
      relationshipGroupCount: 1,
      narrativeEventCount: 2,
      primaryEvidenceCount: 2,
      supportingEvidenceCount: 1,
      contextEntryCount: 1,
      witnessCount: 0,
      documentCount: 0,
    ),
    timelineSection: TrustPackageTimelineSection(
      entries: [
        TrustPackageTimelineEntry(
          timestamp: date,
          title: 'Arrival Photo',
          relatedEvidenceIds: ['photo'],
          relationshipGroupIds: ['group-1'],
          timelineAnchorId: 'anchor-1',
          capturedEvidenceId: 'photo',
        ),
      ],
    ),
    relationshipGroupsSection: TrustPackageRelationshipGroupsSection(
      groups: [
        TrustPackageRelationshipGroupEntry(
          groupId: 'group-1',
          colorHex: '#FF3B36F4',
          groupName: 'Group 1',
          supportingEvidenceIds: ['video'],
          connectedTimelineAnchorIds: ['photo'],
          confidenceLevel: 'Medium',
          validationStatus: '🟡 Medium',
        ),
      ],
    ),
    reconstructionSection: TrustPackageReconstructionSection(
      events: [
        TrustPackageReconstructionEventEntry(
          eventId: 'event-1',
          title: 'Arrival',
          summary: 'The subject arrived at the entrance.',
          evidenceReferenceIds: ['photo'],
          confidence: 'Medium',
          validationStatus: '🟡 Medium',
        ),
      ],
    ),
    evidenceAppendix: TrustPackageEvidenceAppendix(
      entries: [
        TrustPackageEvidenceAppendixEntry(
          evidenceId: 'photo',
          title: 'Arrival Photo',
          evidenceType: 'Photo',
          timestamp: date,
          device: 'Moto G35 5G',
          location: 'Pokhara, Nepal',
          context: 'Entrance captured on camera.',
          relationshipGroupIds: ['group-1'],
        ),
      ],
    ),
    integritySummary: TrustPackageIntegritySummary(
      evidenceCount: 2,
      timelineIntegrity: 'Complete',
      relationshipIntegrity: 'Complete',
      missingReferences: [],
      validationStatus: 'Needs Review',
    ),
    metadata: TrustPackageMetadata(
      packageVersion: DefaultTrustPackageAssembler.packageVersion,
      generatedAt: date,
      generatedBy: DefaultTrustPackageAssembler.generatedBy,
      incidentVersion: '1',
      trustPackageId: 'incident-1@trust-package/v1',
    ),
  );
}

void main() {
  setUp(() {
    InMemoryNarrativeEventRepository.resetForTests();
  });

  group('TrustPackageScorecardService', () {
    test('derives investigation quality from trust package only', () {
      final quality = TrustPackageScorecardService.evaluate(_samplePackage());

      expect(quality.overallRating.label, isNotEmpty);
      expect(quality.indicators, hasLength(6));
      expect(
        quality.indicators.map((entry) => entry.label),
        contains(TrustPackageScorecardService.timelineReferencesLabel),
      );
    });
  });

  group('TrustPackagePreview', () {
    testWidgets('renders all trust package sections read-only', (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(1200, 900));

      await tester.pumpWidget(
        MaterialApp(
          home: TrustPackagePreview(package: _samplePackage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Trust Package'), findsOneWidget);
      expect(find.text('Executive Summary'), findsWidgets);
      expect(find.text('Investigation Quality'), findsWidgets);
      expect(find.text('Chronological Timeline'), findsOneWidget);
      expect(find.text('Relationship Groups'), findsOneWidget);
      expect(find.text('Reconstruction Narrative'), findsOneWidget);
      expect(find.text('Evidence Appendix'), findsWidgets);
      expect(find.text('Integrity & Provenance'), findsWidgets);
      expect(find.text('Integrity Report'), findsWidgets);
      expect(find.text('Arrival'), findsOneWidget);
    });

    testWidgets('section tabs scroll the matching section into view',
        (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(390, 844));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TrustPackagePreview(package: _samplePackage()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      Finder verticalScrollable() {
        return find.byWidgetPredicate(
          (widget) => widget is Scrollable && widget.axisDirection == AxisDirection.down,
        );
      }

      final documentScroll = tester.state<ScrollableState>(verticalScrollable());
      expect(documentScroll.position.pixels, 0);

      await tester.drag(verticalScrollable(), const Offset(0, -640));
      await tester.pumpAndSettle();
      expect(documentScroll.position.pixels, greaterThan(80));

      await tester.tap(find.widgetWithText(TextButton, 'Executive Summary'));
      await tester.pumpAndSettle();

      final viewportTop = tester.getTopLeft(verticalScrollable());
      final summaryTitle = tester.getRect(find.text('Executive Summary').last);
      expect(summaryTitle.top, greaterThanOrEqualTo(viewportTop.dy - 0.5));
      expect(summaryTitle.height, greaterThan(8));

      await tester.ensureVisible(
        find.widgetWithText(TextButton, 'Integrity Report'),
      );
      await tester.tap(find.widgetWithText(TextButton, 'Integrity Report'));
      await tester.pumpAndSettle();

      expect(documentScroll.position.pixels, greaterThan(80));
      final integrityTitle = tester.getTopLeft(find.text('Integrity Report').last);
      expect(integrityTitle.dy, greaterThanOrEqualTo(viewportTop.dy - 0.5));
    });

    testWidgets('screen opens preview from assembled domain package',
        (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(1200, 900));

      final controller = WorkspaceEvidenceController(
        initialState: WorkspaceEvidenceState(
          incidentName: 'Workplace Incident',
          items: [
            WorkspaceEvidenceItem(
              id: 'photo',
              kind: WorkspaceEvidenceKind.image,
              title: 'Arrival Photo',
              lastPreservedAt: DateTime(2026, 7, 28, 12),
              integrityVerified: true,
              verification: VerificationFactory.initial(),
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: TrustPackageScreen(
            controller: controller,
            onNavigateToInvestigation: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Trust Package Preview'), findsOneWidget);
      expect(find.text('Workplace Incident'), findsWidgets);
    });

    testWidgets('evidence appendix tap navigates to investigation instead of editing',
        (tester) async {
      var navigated = false;
      final controller = WorkspaceEvidenceController(
        initialState: WorkspaceEvidenceState(
          incidentName: 'Workplace Incident',
          items: [
            WorkspaceEvidenceItem(
              id: 'photo',
              kind: WorkspaceEvidenceKind.image,
              title: 'Arrival Photo',
              lastPreservedAt: DateTime(2026, 7, 28, 12),
              integrityVerified: true,
              verification: VerificationFactory.initial(),
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: TrustPackageScreen(
            controller: controller,
            trustPackage: _samplePackage(),
            onNavigateToInvestigation: () => navigated = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.drag(find.byType(Scrollable).first, const Offset(0, -1200));
      await tester.pumpAndSettle();

      final appendixTitle = find.text('Arrival Photo');
      expect(appendixTitle, findsWidgets);
      await tester.ensureVisible(appendixTitle.last);
      await tester.tap(
        find.ancestor(
          of: appendixTitle.last,
          matching: find.byType(InkWell),
        ),
      );
      await tester.pumpAndSettle();

      expect(navigated, isTrue);
      expect(find.text('Evidence Inspector'), findsNothing);
    });
  });
}
