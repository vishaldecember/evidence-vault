import 'dart:math' as math;

import 'package:evidence_vault/domain/collection/evidence_collection.dart';
import 'package:evidence_vault/domain/organize/organize_context_anchor.dart';
import 'package:evidence_vault/domain/participant/related_person_link.dart';
import 'package:evidence_vault/models/verification_factory.dart';
import 'package:evidence_vault/models/workspace_evidence_item.dart';
import 'package:evidence_vault/services/investigation/spatial_graph_layout.dart';
import 'package:evidence_vault/services/relationship/relationship_engine.dart';
import 'package:evidence_vault/theme/app_colors.dart';
import 'package:evidence_vault/utils/evidence_formatters.dart';
import 'package:evidence_vault/widgets/investigation/investigation_graph_workspace.dart';
import 'package:evidence_vault/widgets/workspace/organize_context_anchor_arrow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

WorkspaceEvidenceItem _item({
  required String id,
  WorkspaceEvidenceKind kind = WorkspaceEvidenceKind.image,
  DateTime? lastPreservedAt,
  String title = '',
  String? parentEvidenceId,
  String? notePreview,
  List<RelatedPersonLink> relatedPeople = const [],
  bool isContextual = false,
  String? thumbnailPath,
  double? latitude,
  double? longitude,
}) {
  final at = lastPreservedAt ?? DateTime(2026, 8, 14, 10);
  return WorkspaceEvidenceItem(
    id: id,
    kind: kind,
    title: title.isEmpty ? 'Evidence $id' : title,
    lastPreservedAt: at,
    capturedAt: kind.isPrimaryChronology ? at : null,
    recordedAt: kind.isPrimaryChronology ? null : at,
    integrityVerified: true,
    verification: VerificationFactory.initial(),
    incidentId: 'inc-graph',
    parentEvidenceId: parentEvidenceId,
    relatedPeople: relatedPeople,
    isContextual: isContextual,
    notePreview: notePreview,
    thumbnailPath: thumbnailPath,
    latitude: latitude,
    longitude: longitude,
  );
}

InvestigationGraphView _graph({
  required List<WorkspaceEvidenceItem> items,
  Map<String, List<String>> supporting = const {},
  List<EvidenceCollection> collections = const [],
  Set<String>? primaryIds,
}) {
  return InvestigationGraphView(
    primaryEvidenceIds: [
      ...(primaryIds ??
          {
            for (final item in items)
              if (item.kind.isPrimaryChronology &&
                  (item.parentEvidenceId == null ||
                      item.parentEvidenceId!.isEmpty))
                item.id,
          }),
    ],
    supportingByPrimaryId: supporting,
    edges: const [],
    collections: collections,
    evidenceById: {for (final item in items) item.id: item},
  );
}

bool _boxesOverlap(SpatialGraphNode a, SpatialGraphNode b) {
  return SpatialGraphLayout.nodeBox(a).overlaps(SpatialGraphLayout.nodeBox(b));
}

bool _axisAligned(List<Offset> points) {
  for (var i = 0; i < points.length - 1; i++) {
    final a = points[i];
    final b = points[i + 1];
    final diagonal = (a.dx - b.dx).abs() > 0.6 && (a.dy - b.dy).abs() > 0.6;
    if (diagonal) {
      return false;
    }
  }
  return true;
}

void _assertPersonRouting(SpatialGraphLayout layout) {
  for (final edge in layout.edges) {
    if (edge.route == SpatialGraphRouteKind.location ||
        edge.route == SpatialGraphRouteKind.hinge) {
      for (final point in edge.points) {
        expect(point.dx, lessThan(layout.axisX + 0.01));
      }
      continue;
    }
    for (final point in edge.points) {
      expect(point.dx + 0.01, greaterThanOrEqualTo(layout.axisX));
    }
    if (edge.route == SpatialGraphRouteKind.person) {
      expect(_axisAligned(edge.points), isTrue);
    }
  }
}

void main() {
  test('formatTimeGap uses the simplest unit', () {
    final t0 = DateTime(2026, 8, 14, 10);
    expect(
      SpatialGraphLayout.formatTimeGap(t0, t0.add(const Duration(seconds: 20))),
      isNull,
    );
    expect(
      SpatialGraphLayout.formatTimeGap(t0, t0.add(const Duration(minutes: 8))),
      '+ 8m',
    );
    expect(
      SpatialGraphLayout.formatTimeGap(t0, t0.add(const Duration(minutes: 1))),
      '+ 1m',
    );
    expect(
      SpatialGraphLayout.formatTimeGap(
        t0,
        t0.add(const Duration(hours: 3, minutes: 17)),
      ),
      '+ 3h 17m',
    );
    expect(
      SpatialGraphLayout.formatTimeGap(t0, t0.add(const Duration(days: 2))),
      '+ 2 days',
    );
    expect(
      SpatialGraphLayout.formatTimeGap(
        t0,
        t0.add(const Duration(days: 3, hours: 6)),
      ),
      '+ 3d 6h',
    );
  });

  test('significant gap is the comparative outlier, not every interval', () {
    expect(
      SpatialGraphLayout.significantConsecutiveGapIndex([
        const Duration(minutes: 5),
        const Duration(minutes: 12),
        const Duration(minutes: 8),
        const Duration(hours: 7),
        const Duration(minutes: 19),
        const Duration(minutes: 14),
      ]),
      3,
    );
    expect(
      SpatialGraphLayout.significantConsecutiveGapIndex([
        const Duration(hours: 2),
        const Duration(hours: 3),
        const Duration(days: 3),
        const Duration(hours: 5),
      ]),
      2,
    );
    expect(
      SpatialGraphLayout.significantConsecutiveGapIndex([
        const Duration(minutes: 10),
        const Duration(minutes: 12),
        const Duration(minutes: 11),
        const Duration(minutes: 13),
      ]),
      isNull,
    );
    expect(
      SpatialGraphLayout.significantConsecutiveGapIndex([
        const Duration(hours: 2),
        const Duration(hours: 3),
        const Duration(hours: 5),
      ]),
      isNull,
    );
    expect(
      SpatialGraphLayout.significantConsecutiveGapIndex([
        const Duration(hours: 6),
      ]),
      isNull,
    );
    expect(
      SpatialGraphLayout.significantConsecutiveGapIndex([
        const Duration(hours: 6),
        const Duration(minutes: 12),
        const Duration(hours: 6),
        const Duration(minutes: 19),
      ]),
      0,
    );
  });

  test('preserved moments sit on a vertical chronology spine', () {
    final photo = _item(
      id: 'photo',
      lastPreservedAt: DateTime(2026, 8, 14, 10),
    );
    final video = _item(
      id: 'video',
      kind: WorkspaceEvidenceKind.video,
      lastPreservedAt: DateTime(2026, 8, 14, 10, 12),
    );
    final file = _item(
      id: 'file',
      kind: WorkspaceEvidenceKind.attachment,
      lastPreservedAt: DateTime(2026, 8, 14, 10, 18),
    );
    final note = _item(
      id: 'note',
      kind: WorkspaceEvidenceKind.note,
      lastPreservedAt: DateTime(2026, 8, 14, 10, 40),
      notePreview: 'Door was unlocked',
    );
    final layout = SpatialGraphLayout.fromGraph(
      _graph(items: [photo, video, file, note]),
    );

    expect(layout.axisX, greaterThan(40));
    final moments = [
      for (final id in ['photo', 'video', 'file', 'note']) layout.nodeById(id)!,
    ];
    for (final moment in moments) {
      expect(moment.kind, SpatialGraphNodeKind.moment);
      expect(moment.position.dx, layout.axisX);
      expect(moment.subtitle, isNotNull);
      expect(RegExp(r'^\d{2}:\d{2}$').hasMatch(moment.subtitle!), isTrue);
      expect(moment.dateLabel, '14 Aug 2026');
    }
    expect(moments[1].position.dy, greaterThan(moments[0].position.dy));
    expect(moments[2].position.dy, greaterThan(moments[1].position.dy));
    expect(moments[3].position.dy, greaterThan(moments[2].position.dy));
    expect(
      layout.nodeById('file')!.evidenceKind,
      WorkspaceEvidenceKind.attachment,
    );
  });

  test('people on the same moment never overlap', () {
    final photo = _item(
      id: 'moment-a',
      relatedPeople: const [
        RelatedPersonLink(
          participantId: 'p-jacob',
          displayName: 'Jacob',
          roleName: 'witness',
        ),
        RelatedPersonLink(
          participantId: 'p-sarah',
          displayName: 'Sarah',
          roleName: 'witness',
        ),
        RelatedPersonLink(
          participantId: 'p-lee',
          displayName: 'Lee',
          roleName: 'participant',
        ),
        RelatedPersonLink(
          participantId: 'p-ana',
          displayName: 'Ana',
          roleName: 'participant',
        ),
      ],
    );
    final layout = SpatialGraphLayout.fromGraph(_graph(items: [photo]));
    final people = layout.nodes
        .where((node) => node.kind == SpatialGraphNodeKind.person)
        .toList();
    expect(people, hasLength(4));
    for (final person in people) {
      expect(person.position.dx, greaterThan(layout.axisX));
      expect(person.position.dx, isNot(layout.axisX));
    }
    for (var i = 0; i < people.length; i++) {
      for (var j = i + 1; j < people.length; j++) {
        expect(_boxesOverlap(people[i], people[j]), isFalse);
      }
    }
  });

  test('locations sit left of the spine and contexts sit left', () {
    final photo = _item(
      id: 'moment-a',
      notePreview: 'Crowd near the lobby doors',
      relatedPeople: const [
        RelatedPersonLink(
          participantId: 'p-jacob',
          displayName: 'Jacob',
          roleName: 'witness',
        ),
      ],
    );
    final context = _item(
      id: 'ctx-file',
      kind: WorkspaceEvidenceKind.attachment,
      parentEvidenceId: 'moment-a',
      isContextual: true,
    );
    final layout = SpatialGraphLayout.fromGraph(
      _graph(
        items: [photo, context],
        supporting: const {
          'moment-a': ['ctx-file'],
        },
        collections: [
          EvidenceCollection(
            id: 'loc-1',
            incidentId: 'inc-graph',
            name: 'Lobby',
            category: 'location',
            systemGenerated: true,
            displayOrder: 0,
            createdAt: DateTime(2026, 8, 14),
            updatedAt: DateTime(2026, 8, 14),
            memberEvidenceIds: const ['moment-a'],
          ),
        ],
      ),
      organizeCreatedIds: const {'ctx-file'},
      contextAnchors: const [
        OrganizeContextAnchor(
          contextEvidenceId: 'ctx-file',
          capturedEvidenceId: 'moment-a',
        ),
      ],
    );

    final moment = layout.nodeById('moment-a')!;
    final location = layout.nodes.singleWhere(
      (node) => node.kind == SpatialGraphNodeKind.location,
    );
    expect(location.position.dx, lessThan(layout.axisX));
    expect(location.position.dx, lessThan(moment.position.dx));
    expect(
      layout.axisX - location.position.dx,
      closeTo(SpatialGraphLayout.locationInset, 0.5),
    );
    expect((location.position.dx - layout.axisX).abs(), greaterThan(24));
    expect(
      SpatialGraphLayout.nodeBox(
        location,
      ).overlaps(SpatialGraphLayout.nodeBox(moment)),
      isFalse,
    );
    expect(location.label, 'Lobby');

    final person = layout.nodes.singleWhere(
      (node) => node.kind == SpatialGraphNodeKind.person,
    );
    expect(person.label, 'Jacob');

    final description = layout.nodes.singleWhere(
      (node) => node.kind == SpatialGraphNodeKind.description,
    );
    expect(description.position.dx, lessThan(layout.axisX));

    final fileNode = layout.nodeById('ctx-file')!;
    expect(fileNode.kind, SpatialGraphNodeKind.context);
    expect(fileNode.organizeContext, isTrue);
    expect(fileNode.position.dx, lessThan(layout.axisX));
    expect(fileNode.position.dx, isNot(layout.axisX));
    expect(
      (SpatialGraphLayout.markCenter(fileNode).dy -
              SpatialGraphLayout.markCenter(moment).dy)
          .abs(),
      lessThan(2),
    );
    expect(person.position.dx, greaterThan(moment.position.dx));
    expect(fileNode.position.dx, lessThan(moment.position.dx));
    expect(person.position.dx, isNot(layout.axisX));
    expect(layout.nodeById('moment-a')!.kind, SpatialGraphNodeKind.moment);

    final satellites = [
      for (final node in layout.nodes)
        if (node.kind != SpatialGraphNodeKind.moment) node,
    ];
    for (var i = 0; i < satellites.length; i++) {
      for (var j = i + 1; j < satellites.length; j++) {
        expect(_boxesOverlap(satellites[i], satellites[j]), isFalse);
      }
    }
  });

  test('Organize toolbar items are not timeline moments', () {
    final photo = _item(id: 'photo');
    final orgVoice = _item(
      id: 'org-voice',
      kind: WorkspaceEvidenceKind.voice,
      lastPreservedAt: DateTime(2026, 8, 14, 10, 5),
    );
    final layout = SpatialGraphLayout.fromGraph(
      _graph(items: [photo, orgVoice]),
      organizeCreatedIds: const {'org-voice'},
    );
    expect(layout.nodeById('photo')!.kind, SpatialGraphNodeKind.moment);
    expect(layout.nodeById('org-voice'), isNull);
  });

  List<WorkspaceEvidenceItem> staggered({
    required List<Duration> gapsAfterFirst,
    List<WorkspaceEvidenceKind>? kinds,
  }) {
    var at = DateTime(2026, 8, 14, 10);
    final items = <WorkspaceEvidenceItem>[
      _item(
        id: 'm0',
        kind: kinds?[0] ?? WorkspaceEvidenceKind.image,
        lastPreservedAt: at,
      ),
    ];
    for (var i = 0; i < gapsAfterFirst.length; i++) {
      at = at.add(gapsAfterFirst[i]);
      items.add(
        _item(
          id: 'm${i + 1}',
          kind: kinds != null && kinds.length > i + 1
              ? kinds[i + 1]
              : WorkspaceEvidenceKind.image,
          lastPreservedAt: at,
        ),
      );
    }
    return items;
  }

  test(
    'a significant 7-hour pause is labelled on the left, not stretched in space',
    () {
      final items = staggered(
        gapsAfterFirst: const [
          Duration(minutes: 5),
          Duration(minutes: 12),
          Duration(minutes: 8),
          Duration(hours: 7),
          Duration(minutes: 19),
          Duration(minutes: 14),
        ],
        kinds: const [
          WorkspaceEvidenceKind.image,
          WorkspaceEvidenceKind.video,
          WorkspaceEvidenceKind.voice,
          WorkspaceEvidenceKind.image,
          WorkspaceEvidenceKind.image,
          WorkspaceEvidenceKind.attachment,
          WorkspaceEvidenceKind.image,
        ],
      );
      final layout = SpatialGraphLayout.fromGraph(_graph(items: items));

      expect(layout.gaps, hasLength(1));
      expect(layout.gaps.single.label, '+ 7h');
      expect(layout.gaps.single.fromMomentId, 'm3');
      expect(layout.gaps.single.toMomentId, 'm4');

      final moments = [
        for (var i = 0; i < items.length; i++) layout.nodeById('m$i')!,
      ];
      for (final moment in moments) {
        expect(moment.subtitle, isNotNull);
        expect(moment.kind, SpatialGraphNodeKind.moment);
        expect(moment.position.dx, layout.axisX);
        expect(RegExp(r'^\d{2}:\d{2}$').hasMatch(moment.subtitle!), isTrue);
        expect(moment.dateLabel, isNotNull);
      }

      final ordinary = moments[1].position.dy - moments[0].position.dy;
      final significant = moments[4].position.dy - moments[3].position.dy;
      expect(significant, greaterThan(ordinary));
      expect(ordinary, greaterThan(40));
      expect(significant, lessThan(ordinary * 3));
    },
  );

  test('does not invent a highlight when consecutive gaps are similar', () {
    final items = staggered(
      gapsAfterFirst: const [
        Duration(minutes: 10),
        Duration(minutes: 12),
        Duration(minutes: 11),
        Duration(minutes: 13),
        Duration(minutes: 9),
      ],
    );
    final layout = SpatialGraphLayout.fromGraph(_graph(items: items));
    expect(layout.gaps, isEmpty);
  });

  testWidgets(
    'does not render Where, Add location, or invented missing-event claims',
    (tester) async {
      final items = staggered(
        gapsAfterFirst: const [
          Duration(minutes: 5),
          Duration(minutes: 12),
          Duration(minutes: 8),
          Duration(hours: 7),
          Duration(minutes: 19),
          Duration(minutes: 14),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InvestigationGraphWorkspace(
              graph: _graph(items: items),
              onEvidenceTap: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('+ 7h'), findsOneWidget);
      expect(find.text('Where'), findsNothing);
      expect(find.text('Add location'), findsNothing);
      expect(find.text('Missing Evidence'), findsNothing);
      expect(find.text('Unknown Event'), findsNothing);
      expect(find.text('Unexplained Event'), findsNothing);
      expect(
        find.byKey(InvestigationGraphWorkspace.gapKey('m3', '+ 7h')),
        findsOneWidget,
      );
      expect(
        find.byKey(InvestigationGraphWorkspace.nodeKey('m3')),
        findsOneWidget,
      );
      expect(
        find.byKey(InvestigationGraphWorkspace.nodeKey('m4')),
        findsOneWidget,
      );
    },
  );

  test('orange chronology constants stay restrained', () {
    expect(
      InvestigationGraphWorkspace.chronologyColor,
      AppColors.timelineChronology,
    );
    expect(InvestigationGraphWorkspace.spineStrokeWidth, greaterThan(1.0));
    expect(InvestigationGraphWorkspace.spineStrokeWidth, lessThan(2.0));
  });

  test('timestamps stay on the evidence node as military time then date', () {
    final photo = _item(id: 'photo');
    final video = _item(
      id: 'video',
      kind: WorkspaceEvidenceKind.video,
      lastPreservedAt: DateTime(2026, 8, 14, 17),
    );
    final layout = SpatialGraphLayout.fromGraph(_graph(items: [photo, video]));
    for (final moment in [
      layout.nodeById('photo')!,
      layout.nodeById('video')!,
    ]) {
      expect(moment.position.dx, layout.axisX);
      expect(moment.subtitle, isNotNull);
      expect(RegExp(r'^\d{2}:\d{2}$').hasMatch(moment.subtitle!), isTrue);
      expect(moment.dateLabel, '14 Aug 2026');
    }
    expect(layout.nodeById('photo')!.subtitle, '10:00');
    expect(layout.nodeById('video')!.subtitle, '17:00');
    expect(
      layout.nodeById('video')!.position.dy,
      greaterThan(layout.nodeById('photo')!.position.dy),
    );
    expect(layout.gaps, isEmpty);
  });

  test(
    'location pin sits immediately left of its moment, never on the axis',
    () {
      final located = _item(id: 'photo', latitude: 27.7, longitude: 85.3);
      final missing = _item(
        id: 'video',
        kind: WorkspaceEvidenceKind.video,
        lastPreservedAt: DateTime(2026, 8, 14, 10, 12),
      );
      final layout = SpatialGraphLayout.fromGraph(
        _graph(items: [located, missing]),
      );
      final photo = layout.nodeById('photo')!;
      final location = layout.nodes.singleWhere(
        (node) => node.kind == SpatialGraphNodeKind.location,
      );
      expect(location.position.dx, lessThan(layout.axisX));
      expect(location.position.dx, lessThan(photo.position.dx));
      expect(location.position.dx, isNot(layout.axisX));
      expect(
        layout.axisX - location.position.dx,
        SpatialGraphLayout.locationInset,
      );
      expect(
        (SpatialGraphLayout.markCenter(photo).dy -
                SpatialGraphLayout.markCenter(location).dy)
            .abs(),
        lessThan(2),
      );
      expect(photo.position.dx, layout.axisX);
      expect(
        SpatialGraphLayout.nodeBox(
          location,
        ).overlaps(SpatialGraphLayout.nodeBox(photo)),
        isFalse,
      );
      expect(
        layout.nodeById(SpatialGraphLayout.locationNodeId('video')),
        isNull,
      );
    },
  );

  test('people sit to the right of their own moment, never on the axis', () {
    final first = _item(
      id: 'moment-a',
      relatedPeople: const [
        RelatedPersonLink(
          participantId: 'p-jacob',
          displayName: 'Jacob',
          roleName: 'witness',
        ),
      ],
    );
    final second = _item(
      id: 'moment-b',
      kind: WorkspaceEvidenceKind.video,
      lastPreservedAt: DateTime(2026, 8, 14, 10, 20),
      relatedPeople: const [
        RelatedPersonLink(
          participantId: 'p-sarah',
          displayName: 'Sarah',
          roleName: 'witness',
        ),
      ],
    );
    final layout = SpatialGraphLayout.fromGraph(_graph(items: [first, second]));
    final jacob = layout.nodes.singleWhere((node) => node.label == 'Jacob');
    final sarah = layout.nodes.singleWhere((node) => node.label == 'Sarah');
    final a = layout.nodeById('moment-a')!;
    final b = layout.nodeById('moment-b')!;
    expect(jacob.position.dx, greaterThan(a.position.dx));
    expect(sarah.position.dx, greaterThan(b.position.dx));
    expect(jacob.position.dx, isNot(layout.axisX));
    expect(sarah.position.dx, isNot(layout.axisX));
    expect(_boxesOverlap(jacob, sarah), isFalse);
    expect(
      layout.edges.any(
        (edge) =>
            edge.toId.contains('person::') || edge.fromId.contains('person::'),
      ),
      isTrue,
    );
  });

  test(
    'Organize context hangs off captured evidence, not the chronology axis',
    () {
      final photo = _item(
        id: 'photo',
        lastPreservedAt: DateTime(2026, 8, 14, 10, 40),
      );
      final voice = _item(
        id: 'org-voice',
        kind: WorkspaceEvidenceKind.voice,
        lastPreservedAt: DateTime(2026, 8, 14, 10, 47),
        isContextual: true,
      );
      final note = _item(
        id: 'org-note',
        kind: WorkspaceEvidenceKind.note,
        lastPreservedAt: DateTime(2026, 8, 14, 10, 48),
        isContextual: true,
      );
      final layout = SpatialGraphLayout.fromGraph(
        _graph(items: [photo, voice, note]),
        organizeCreatedIds: const {'org-voice', 'org-note'},
        contextAnchors: const [
          OrganizeContextAnchor(
            contextEvidenceId: 'org-voice',
            capturedEvidenceId: 'photo',
          ),
          OrganizeContextAnchor(
            contextEvidenceId: 'org-note',
            capturedEvidenceId: 'photo',
          ),
        ],
      );

      final moment = layout.nodeById('photo')!;
      final voiceNode = layout.nodeById('org-voice')!;
      final noteNode = layout.nodeById('org-note')!;
      expect(moment.kind, SpatialGraphNodeKind.moment);
      expect(moment.position.dx, layout.axisX);
      expect(moment.subtitle, '10:40');
      expect(moment.dateLabel, '14 Aug 2026');
      expect(voiceNode.kind, SpatialGraphNodeKind.context);
      expect(noteNode.kind, SpatialGraphNodeKind.context);
      expect(voiceNode.organizeContext, isTrue);
      expect(noteNode.organizeContext, isTrue);
      expect(voiceNode.position.dx, lessThan(layout.axisX));
      expect(noteNode.position.dx, lessThan(layout.axisX));
      expect(voiceNode.position.dx, isNot(layout.axisX));
      expect(
        (SpatialGraphLayout.markCenter(voiceNode).dy -
                SpatialGraphLayout.markCenter(moment).dy)
            .abs(),
        lessThan(2),
      );
      expect(
        (SpatialGraphLayout.markCenter(noteNode).dy -
                SpatialGraphLayout.markCenter(voiceNode).dy)
            .abs(),
        lessThan(2),
      );
      expect(voiceNode.position.dx, greaterThan(noteNode.position.dx));
      expect(
        SpatialGraphLayout.markCenter(moment).dx -
            SpatialGraphLayout.markRadius(moment) -
            SpatialGraphLayout.markCenter(voiceNode).dx -
            SpatialGraphLayout.markRadius(voiceNode),
        closeTo(SpatialGraphLayout.fingerGap, 8),
      );
      expect(voiceNode.subtitle, '10:47');
      expect(noteNode.subtitle, '10:48');
      expect(voiceNode.timestamp, DateTime(2026, 8, 14, 10, 47));
      expect(
        layout.nodes.where((node) => node.kind == SpatialGraphNodeKind.moment),
        hasLength(1),
      );
      expect(
        layout.edges.where(
          (edge) =>
              edge.fromId == 'photo' &&
              (edge.toId == 'org-voice' || edge.toId == 'org-note') &&
              edge.route == SpatialGraphRouteKind.hinge,
        ),
        hasLength(1),
      );
      final hinge = layout.edges.firstWhere(
        (edge) =>
            edge.fromId == 'photo' && edge.route == SpatialGraphRouteKind.hinge,
      );
      expect(hinge.toId, 'org-note');
      expect(hinge.points.every((point) => point.dx != layout.axisX), isTrue);
      expect(hinge.points, hasLength(2));
      expect((hinge.points.first.dy - hinge.points.last.dy).abs(), lessThan(1));
    },
  );

  test('does not invent Organize context from supporting links alone', () {
    final photo = _item(id: 'photo');
    final orgVoice = _item(
      id: 'org-voice',
      kind: WorkspaceEvidenceKind.voice,
      isContextual: true,
    );
    final layout = SpatialGraphLayout.fromGraph(
      _graph(
        items: [photo, orgVoice],
        supporting: const {
          'photo': ['org-voice'],
        },
      ),
      organizeCreatedIds: const {'org-voice'},
    );
    expect(layout.nodeById('photo')!.kind, SpatialGraphNodeKind.moment);
    expect(layout.nodeById('org-voice'), isNull);
  });

  test('graph nodes never copy thumbnail paths', () {
    final photo = _item(id: 'photo', thumbnailPath: '/tmp/thumb.jpg');
    final layout = SpatialGraphLayout.fromGraph(_graph(items: [photo]));
    expect(layout.nodeById('photo')!.thumbnailPath, isNull);
  });

  testWidgets(
    'graph uses type icons, not thumbnails, with clocks on the node',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(412, 915));

      final photo = _item(id: 'photo', thumbnailPath: '/tmp/thumb.jpg');
      final video = _item(
        id: 'video',
        kind: WorkspaceEvidenceKind.video,
        lastPreservedAt: DateTime(2026, 8, 14, 10, 12),
      );
      final voice = _item(
        id: 'voice',
        kind: WorkspaceEvidenceKind.voice,
        lastPreservedAt: DateTime(2026, 8, 14, 10, 18),
      );
      final note = _item(
        id: 'note',
        kind: WorkspaceEvidenceKind.note,
        lastPreservedAt: DateTime(2026, 8, 14, 10, 24),
      );
      final file = _item(
        id: 'file',
        kind: WorkspaceEvidenceKind.attachment,
        lastPreservedAt: DateTime(2026, 8, 14, 10, 30),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InvestigationGraphWorkspace(
              graph: _graph(items: [photo, video, voice, note, file]),
              onEvidenceTap: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Image), findsNothing);
      expect(find.byIcon(Icons.photo_outlined), findsWidgets);
      expect(find.byIcon(Icons.videocam_outlined), findsOneWidget);
      expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);
      expect(find.byIcon(Icons.notes_rounded), findsOneWidget);
      expect(find.byIcon(Icons.insert_drive_file_outlined), findsOneWidget);

      expect(
        InvestigationGraphWorkspace.iconFor(WorkspaceEvidenceKind.image),
        Icons.photo_outlined,
      );
      expect(
        InvestigationGraphWorkspace.iconFor(WorkspaceEvidenceKind.video),
        Icons.videocam_outlined,
      );
      expect(
        InvestigationGraphWorkspace.iconFor(WorkspaceEvidenceKind.voice),
        Icons.mic_none_rounded,
      );
      expect(
        InvestigationGraphWorkspace.iconFor(WorkspaceEvidenceKind.note),
        Icons.notes_rounded,
      );
      expect(
        InvestigationGraphWorkspace.iconFor(WorkspaceEvidenceKind.attachment),
        Icons.insert_drive_file_outlined,
      );

      final spine = tester.getRect(
        find.byKey(InvestigationGraphWorkspace.spineKey),
      );
      final photoBox = tester.getRect(
        find.byKey(InvestigationGraphWorkspace.nodeKey('photo')),
      );
      final timestamp = tester.getRect(
        find.byKey(InvestigationGraphWorkspace.timestampKey('photo')),
      );
      expect((spine.center.dx - photoBox.center.dx).abs(), lessThan(10));
      expect((timestamp.center.dx - photoBox.center.dx).abs(), lessThan(8));
      expect(timestamp.top, greaterThan(photoBox.top));
      final timestampText = tester.widget<Text>(
        find.byKey(InvestigationGraphWorkspace.timestampKey('photo')),
      );
      expect(timestampText.data, '10:00');
      expect(timestampText.style?.color, const Color(0xFFFFFFFF));
      expect(find.text('14 Aug 2026'), findsWidgets);
    },
  );

  testWidgets('Organize context renders white and keeps its own clock', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(412, 915));

    final photo = _item(
      id: 'photo',
      lastPreservedAt: DateTime(2026, 8, 14, 10, 40),
    );
    final orgNote = _item(
      id: 'org-note',
      kind: WorkspaceEvidenceKind.note,
      lastPreservedAt: DateTime(2026, 8, 14, 10, 47),
      isContextual: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InvestigationGraphWorkspace(
            graph: _graph(items: [photo, orgNote]),
            organizeCreatedIds: const {'org-note'},
            contextAnchors: const [
              OrganizeContextAnchor(
                contextEvidenceId: 'org-note',
                capturedEvidenceId: 'photo',
              ),
            ],
            onEvidenceTap: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final mark = tester.widget<Container>(
      find.byKey(InvestigationGraphWorkspace.nodeMarkKey('org-note')),
    );
    final decoration = mark.decoration! as BoxDecoration;
    expect(decoration.color, Colors.white);
    expect((decoration.border! as Border).top.color, Colors.white);

    final photoBox = tester.getRect(
      find.byKey(InvestigationGraphWorkspace.nodeKey('photo')),
    );
    final contextBox = tester.getRect(
      find.byKey(InvestigationGraphWorkspace.nodeKey('org-note')),
    );
    final spine = tester.getRect(
      find.byKey(InvestigationGraphWorkspace.spineKey),
    );
    expect(contextBox.center.dx, lessThan(spine.center.dx - 16));
    expect((contextBox.center.dy - photoBox.center.dy).abs(), lessThan(28));
    expect(find.text('10:47'), findsOneWidget);
    expect(find.text('10:40'), findsOneWidget);
    expect(
      find.byKey(InvestigationGraphWorkspace.timestampKey('org-note')),
      findsNothing,
    );
    expect(
      find.byKey(InvestigationGraphWorkspace.timestampKey('photo')),
      findsOneWidget,
    );
  });

  testWidgets('location pin is red and sits in the left lane', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(412, 915));

    final photo = _item(id: 'photo', latitude: 27.7, longitude: 85.3);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InvestigationGraphWorkspace(
            graph: _graph(
              items: [photo],
              collections: [
                EvidenceCollection(
                  id: 'loc-1',
                  incidentId: 'inc-graph',
                  name: 'Cafe',
                  category: 'location',
                  systemGenerated: true,
                  displayOrder: 0,
                  createdAt: DateTime(2026, 8, 14),
                  updatedAt: DateTime(2026, 8, 14),
                  memberEvidenceIds: const ['photo'],
                ),
              ],
            ),
            onEvidenceTap: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final pin = tester.widget<Icon>(find.byIcon(Icons.place_rounded));
    expect(pin.color, InvestigationGraphWorkspace.locationPinColor);
    expect(find.text('Cafe'), findsOneWidget);

    final locationBox = tester.getRect(
      find.byKey(
        InvestigationGraphWorkspace.nodeKey(
          SpatialGraphLayout.locationNodeId('photo'),
        ),
      ),
    );
    final photoBox = tester.getRect(
      find.byKey(InvestigationGraphWorkspace.nodeKey('photo')),
    );
    final spine = tester.getRect(
      find.byKey(InvestigationGraphWorkspace.spineKey),
    );
    expect(locationBox.center.dx, lessThan(spine.center.dx));
    expect(locationBox.right, lessThan(photoBox.left + 1));
    expect(find.text('People'), findsNothing);
    expect(find.text('Where'), findsNothing);
    expect(find.text('Add location'), findsNothing);
  });

  test('moments sit on the spine; each located moment keeps its own pin', () {
    final cafePhoto = _item(
      id: 'photo',
      lastPreservedAt: DateTime(2026, 8, 14, 14, 3, 21),
    );
    final cafeVideo = _item(
      id: 'video',
      kind: WorkspaceEvidenceKind.video,
      lastPreservedAt: DateTime(2026, 8, 14, 14, 5, 47),
    );
    final hotelVoice = _item(
      id: 'voice',
      kind: WorkspaceEvidenceKind.voice,
      lastPreservedAt: DateTime(2026, 8, 14, 14, 8, 12),
    );
    final layout = SpatialGraphLayout.fromGraph(
      _graph(
        items: [cafePhoto, cafeVideo, hotelVoice],
        collections: [
          EvidenceCollection(
            id: 'cafe',
            incidentId: 'inc-graph',
            name: 'Cafe',
            category: 'location',
            systemGenerated: true,
            displayOrder: 0,
            createdAt: DateTime(2026, 8, 14),
            updatedAt: DateTime(2026, 8, 14),
            memberEvidenceIds: const ['photo', 'video'],
          ),
          EvidenceCollection(
            id: 'hotel',
            incidentId: 'inc-graph',
            name: 'Hotel',
            category: 'location',
            systemGenerated: true,
            displayOrder: 1,
            createdAt: DateTime(2026, 8, 14),
            updatedAt: DateTime(2026, 8, 14),
            memberEvidenceIds: const ['voice'],
          ),
        ],
      ),
    );

    final photo = layout.nodeById('photo')!;
    final video = layout.nodeById('video')!;
    final voice = layout.nodeById('voice')!;
    expect(photo.subtitle, '14:03');
    expect(video.subtitle, '14:05');
    expect(voice.subtitle, '14:08');
    expect(photo.dateLabel, '14 Aug 2026');
    expect(photo.position.dx, layout.axisX);
    expect(video.position.dx, layout.axisX);
    expect(voice.position.dx, layout.axisX);
    expect(video.position.dy, greaterThan(photo.position.dy));
    expect(voice.position.dy, greaterThan(video.position.dy));

    final photoPin = layout.nodeById(
      SpatialGraphLayout.locationNodeId('photo'),
    )!;
    final videoPin = layout.nodeById(
      SpatialGraphLayout.locationNodeId('video'),
    )!;
    final hotel = layout.nodeById(SpatialGraphLayout.locationNodeId('voice'))!;
    expect(photoPin.label, 'Cafe');
    expect(videoPin.label, 'Cafe');
    expect(hotel.label, 'Hotel');
    expect(photoPin.position.dx, lessThan(layout.axisX));
    expect(hotel.position.dx, lessThan(layout.axisX));
    expect(
      (SpatialGraphLayout.markCenter(photoPin).dy -
              SpatialGraphLayout.markCenter(photo).dy)
          .abs(),
      lessThan(2),
    );
    expect(
      (SpatialGraphLayout.markCenter(hotel).dy -
              SpatialGraphLayout.markCenter(voice).dy)
          .abs(),
      lessThan(2),
    );

    for (var i = 0; i < layout.nodes.length; i++) {
      for (var j = i + 1; j < layout.nodes.length; j++) {
        expect(_boxesOverlap(layout.nodes[i], layout.nodes[j]), isFalse);
      }
    }

    expect(
      layout.edges.where(
        (edge) => edge.route == SpatialGraphRouteKind.chronology,
      ),
      isEmpty,
    );
  });

  test('Organize context arrow remains Context → Evidence', () {
    expect(OrganizeContextAnchorArrow.pointsTowardEvidence, isTrue);
  });

  testWidgets(
    '390×844 keeps location left, evidence on the spine, people on the right',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(390, 844));

      final photo = _item(
        id: 'photo',
        lastPreservedAt: DateTime(2026, 8, 14, 14, 3, 21),
        relatedPeople: const [
          RelatedPersonLink(
            participantId: 'p-jacob',
            displayName: 'Jacob',
            roleName: 'witness',
          ),
        ],
      );
      final orgNote = _item(
        id: 'org-note',
        kind: WorkspaceEvidenceKind.note,
        lastPreservedAt: DateTime(2026, 8, 14, 14, 4, 10),
        isContextual: true,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InvestigationGraphWorkspace(
              graph: _graph(
                items: [photo, orgNote],
                collections: [
                  EvidenceCollection(
                    id: 'loc-1',
                    incidentId: 'inc-graph',
                    name: 'Cafe',
                    category: 'location',
                    systemGenerated: true,
                    displayOrder: 0,
                    createdAt: DateTime(2026, 8, 14),
                    updatedAt: DateTime(2026, 8, 14),
                    memberEvidenceIds: const ['photo'],
                  ),
                ],
              ),
              organizeCreatedIds: const {'org-note'},
              contextAnchors: const [
                OrganizeContextAnchor(
                  contextEvidenceId: 'org-note',
                  capturedEvidenceId: 'photo',
                ),
              ],
              onEvidenceTap: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Where'), findsNothing);
      expect(find.text('Add location'), findsNothing);
      expect(find.text('Cafe'), findsOneWidget);
      expect(find.text('Jacob'), findsOneWidget);
      expect(find.text('14:03'), findsWidgets);
      expect(find.text('14 Aug 2026'), findsOneWidget);

      final locationBox = tester.getRect(
        find.byKey(
          InvestigationGraphWorkspace.nodeKey(
            SpatialGraphLayout.locationNodeId('photo'),
          ),
        ),
      );
      final photoBox = tester.getRect(
        find.byKey(InvestigationGraphWorkspace.nodeKey('photo')),
      );
      final peopleBox = tester.getRect(
        find.byKey(
          InvestigationGraphWorkspace.nodeKey(
            SpatialGraphLayout.personNodeId('p-jacob'),
          ),
        ),
      );
      final contextBox = tester.getRect(
        find.byKey(InvestigationGraphWorkspace.nodeKey('org-note')),
      );
      final spine = tester.getRect(
        find.byKey(InvestigationGraphWorkspace.spineKey),
      );
      final timestamp = tester.getRect(
        find.byKey(InvestigationGraphWorkspace.timestampKey('photo')),
      );

      expect(locationBox.center.dx, lessThan(spine.center.dx));
      expect((photoBox.center.dx - spine.center.dx).abs(), lessThan(10));
      expect(peopleBox.center.dx, greaterThan(photoBox.center.dx));
      expect(peopleBox.center.dx, isNot(spine.center.dx));
      expect(contextBox.center.dx, lessThan(photoBox.center.dx));
      expect(contextBox.center.dx, lessThan(spine.center.dx));
      expect((contextBox.center.dy - photoBox.center.dy).abs(), lessThan(28));
      expect((timestamp.center.dx - photoBox.center.dx).abs(), lessThan(8));
    },
  );

  test('repeated person is one node with a shared D trunk', () {
    final jacob = const RelatedPersonLink(
      participantId: 'p-jacob',
      displayName: 'Jacob',
      roleName: 'witness',
    );
    final items = [
      _item(id: 'm0', relatedPeople: [jacob]),
      _item(
        id: 'm1',
        kind: WorkspaceEvidenceKind.video,
        lastPreservedAt: DateTime(2026, 8, 14, 10, 12),
        relatedPeople: [jacob],
      ),
      _item(
        id: 'm2',
        kind: WorkspaceEvidenceKind.voice,
        lastPreservedAt: DateTime(2026, 8, 14, 10, 24),
        relatedPeople: [jacob],
      ),
      _item(
        id: 'm3',
        kind: WorkspaceEvidenceKind.note,
        lastPreservedAt: DateTime(2026, 8, 14, 10, 36),
        relatedPeople: [jacob],
      ),
    ];
    final layout = SpatialGraphLayout.fromGraph(_graph(items: items));
    final people = layout.nodes
        .where((node) => node.kind == SpatialGraphNodeKind.person)
        .toList();
    expect(people, hasLength(1));
    expect(people.single.id, SpatialGraphLayout.personNodeId('p-jacob'));
    expect(people.single.position.dx, greaterThan(layout.axisX));

    final personEdges = layout.edges
        .where((edge) => edge.route == SpatialGraphRouteKind.person)
        .toList();
    expect(personEdges, isNotEmpty);
    expect({
      for (final edge in personEdges)
        if (edge.fromId != people.single.id) edge.fromId,
    }, containsAll(['m0', 'm1', 'm2', 'm3']));
    expect(personEdges.every((edge) => edge.toId == people.single.id), isTrue);

    final person = people.single;
    final toPerson = personEdges.where(
      (edge) =>
          (edge.points.last - SpatialGraphLayout.markCenter(person)).distance <
          SpatialGraphLayout.markRadius(person) + 0.8,
    );
    expect(toPerson, isNotEmpty);
    expect(
      (toPerson.first.points.last - SpatialGraphLayout.markCenter(person))
          .distance,
      closeTo(SpatialGraphLayout.markRadius(person), 0.6),
    );

    for (final id in ['m0', 'm1', 'm2', 'm3']) {
      final moment = layout.nodeById(id)!;
      final center = SpatialGraphLayout.markCenter(moment);
      final radius = SpatialGraphLayout.markRadius(moment);
      final branch = personEdges.firstWhere(
        (edge) =>
            edge.fromId == id &&
            (edge.points.first - center).distance - radius < 0.8 &&
            (edge.points.first - center).distance - radius > -0.8,
      );
      expect((branch.points.first - center).distance, closeTo(radius, 0.6));
    }
    _assertPersonRouting(layout);
  });

  test('several people on one moment share a single relationship line', () {
    final layout = SpatialGraphLayout.fromGraph(
      _graph(
        items: [
          _item(
            id: 'photo',
            relatedPeople: const [
              RelatedPersonLink(
                participantId: 'p-a',
                displayName: 'Ana',
                roleName: 'witness',
              ),
              RelatedPersonLink(
                participantId: 'p-b',
                displayName: 'Ben',
                roleName: 'witness',
              ),
              RelatedPersonLink(
                participantId: 'p-c',
                displayName: 'Cara',
                roleName: 'participant',
              ),
            ],
          ),
        ],
      ),
    );
    final people = [
      for (final name in ['Ana', 'Ben', 'Cara'])
        layout.nodes.singleWhere((node) => node.label == name),
    ];
    expect(people, hasLength(3));
    expect(people[0].position.dx, lessThan(people[1].position.dx));
    expect(people[1].position.dx, lessThan(people[2].position.dx));
    expect((people[0].position.dy - people[2].position.dy).abs(), lessThan(12));
    final personEdges = layout.edges
        .where((edge) => edge.route == SpatialGraphRouteKind.person)
        .toList();
    expect(personEdges, hasLength(1));
    expect(personEdges.single.fromId, 'photo');
    expect(personEdges.single.toId, SpatialGraphLayout.personNodeId('p-c'));
    expect(personEdges.single.points, hasLength(2));
    _assertPersonRouting(layout);
  });

  testWidgets('tapping an evidence node reports that item', (tester) async {
    WorkspaceEvidenceItem? tapped;
    final photo = _item(id: 'photo');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InvestigationGraphWorkspace(
            graph: _graph(items: [photo]),
            onEvidenceTap: (item) => tapped = item,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(InvestigationGraphWorkspace.nodeKey('photo')));
    await tester.pumpAndSettle();
    expect(tapped?.id, 'photo');
  });

  testWidgets('tapping GPS reveals the full stored coordinate pair', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(360, 800));

    const latitude = 30.086731;
    const longitude = 78.267608;
    final pair = EvidenceFormatters.coordinates(latitude, longitude);
    WorkspaceEvidenceItem? tapped;
    final photo = _item(
      id: 'photo',
      latitude: latitude,
      longitude: longitude,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InvestigationGraphWorkspace(
            graph: _graph(items: [photo]),
            onEvidenceTap: (item) => tapped = item,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final locationKey = InvestigationGraphWorkspace.nodeKey(
      SpatialGraphLayout.locationNodeId('photo'),
    );
    expect(find.byKey(locationKey), findsOneWidget);
    expect(
      find.byKey(InvestigationGraphWorkspace.gpsCoordinateTitleKey),
      findsNothing,
    );
    expect(find.text(pair), findsNothing);
    expect(find.textContaining('30.086'), findsNothing);

    await tester.tap(find.byKey(locationKey));
    await tester.pumpAndSettle();

    expect(
      find.byKey(InvestigationGraphWorkspace.gpsCoordinateTitleKey),
      findsOneWidget,
    );
    expect(find.text(pair), findsOneWidget);
    expect(pair, '30.08673, 78.26761');
    expect(tapped, isNull);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(locationKey));
    await tester.pumpAndSettle();
    expect(
      find.byKey(InvestigationGraphWorkspace.gpsCoordinateTitleKey),
      findsNothing,
    );

    await tester.tap(find.byKey(locationKey));
    await tester.pumpAndSettle();
    expect(find.text(pair), findsOneWidget);

    await tester.tap(find.byKey(InvestigationGraphWorkspace.nodeKey('photo')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(InvestigationGraphWorkspace.gpsCoordinateTitleKey),
      findsNothing,
    );
    expect(tapped?.id, 'photo');
  });

  testWidgets('named location tap still shows the GPS coordinate pair', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(412, 915));

    const latitude = 27.7172;
    const longitude = 85.3240;
    final pair = EvidenceFormatters.coordinates(latitude, longitude);
    final photo = _item(
      id: 'photo',
      latitude: latitude,
      longitude: longitude,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InvestigationGraphWorkspace(
            graph: _graph(
              items: [photo],
              collections: [
                EvidenceCollection(
                  id: 'loc-1',
                  incidentId: 'inc-graph',
                  name: 'Cafe',
                  category: 'location',
                  systemGenerated: true,
                  displayOrder: 0,
                  createdAt: DateTime(2026, 8, 14),
                  updatedAt: DateTime(2026, 8, 14),
                  memberEvidenceIds: const ['photo'],
                ),
              ],
            ),
            onEvidenceTap: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cafe'), findsOneWidget);
    await tester.tap(
      find.byKey(
        InvestigationGraphWorkspace.nodeKey(
          SpatialGraphLayout.locationNodeId('photo'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Cafe'), findsOneWidget);
    expect(find.text(pair), findsOneWidget);
  });

  test('a person appearing once stays a single horizontal to one node', () {
    final layout = SpatialGraphLayout.fromGraph(
      _graph(
        items: [
          _item(
            id: 'photo',
            relatedPeople: const [
              RelatedPersonLink(
                participantId: 'p-lee',
                displayName: 'Lee',
                roleName: 'participant',
              ),
            ],
          ),
        ],
      ),
    );
    final people = layout.nodes
        .where((node) => node.kind == SpatialGraphNodeKind.person)
        .toList();
    expect(people, hasLength(1));
    final personEdges = layout.edges
        .where((edge) => edge.route == SpatialGraphRouteKind.person)
        .toList();
    expect(personEdges, isNotEmpty);
    expect(_axisAligned(personEdges.single.points), isTrue);
    expect(personEdges.single.points, hasLength(2));
    _assertPersonRouting(layout);
  });

  test('two different repeated people stay two nodes', () {
    const jacob = RelatedPersonLink(
      participantId: 'p-jacob',
      displayName: 'Jacob',
      roleName: 'witness',
    );
    const sarah = RelatedPersonLink(
      participantId: 'p-sarah',
      displayName: 'Sarah',
      roleName: 'witness',
    );
    final layout = SpatialGraphLayout.fromGraph(
      _graph(
        items: [
          _item(id: 'm0', relatedPeople: const [jacob, sarah]),
          _item(
            id: 'm1',
            kind: WorkspaceEvidenceKind.video,
            lastPreservedAt: DateTime(2026, 8, 14, 10, 15),
            relatedPeople: const [jacob],
          ),
          _item(
            id: 'm2',
            kind: WorkspaceEvidenceKind.voice,
            lastPreservedAt: DateTime(2026, 8, 14, 10, 30),
            relatedPeople: const [sarah],
          ),
        ],
      ),
    );
    final people = layout.nodes
        .where((node) => node.kind == SpatialGraphNodeKind.person)
        .toList();
    expect(people, hasLength(2));
    expect(people.map((node) => node.id).toSet(), {
      SpatialGraphLayout.personNodeId('p-jacob'),
      SpatialGraphLayout.personNodeId('p-sarah'),
    });
    expect(_boxesOverlap(people[0], people[1]), isFalse);
    _assertPersonRouting(layout);
  });

  test(
    'location stubs and context tangents are the only traces left of the axis',
    () {
      final layout = SpatialGraphLayout.fromGraph(
        _graph(
          items: [
            _item(
              id: 'photo',
              latitude: 27.7,
              longitude: 85.3,
              relatedPeople: const [
                RelatedPersonLink(
                  participantId: 'p-jacob',
                  displayName: 'Jacob',
                  roleName: 'witness',
                ),
              ],
            ),
            _item(
              id: 'video',
              kind: WorkspaceEvidenceKind.video,
              lastPreservedAt: DateTime(2026, 8, 14, 10, 12),
              latitude: 27.71,
              longitude: 85.31,
            ),
          ],
          collections: [
            EvidenceCollection(
              id: 'cafe',
              incidentId: 'inc-graph',
              name: 'Cafe',
              category: 'location',
              systemGenerated: true,
              displayOrder: 0,
              createdAt: DateTime(2026, 8, 14),
              updatedAt: DateTime(2026, 8, 14),
              memberEvidenceIds: const ['photo'],
            ),
            EvidenceCollection(
              id: 'hotel',
              incidentId: 'inc-graph',
              name: 'Hotel',
              category: 'location',
              systemGenerated: true,
              displayOrder: 1,
              createdAt: DateTime(2026, 8, 14),
              updatedAt: DateTime(2026, 8, 14),
              memberEvidenceIds: const ['video'],
            ),
          ],
        ),
      );
      expect(
        layout.nodes.where(
          (node) => node.kind == SpatialGraphNodeKind.location,
        ),
        hasLength(2),
      );
      final leftRelationship = [
        for (final edge in layout.edges)
          if (edge.points.any((point) => point.dx < layout.axisX - 0.01)) edge,
      ];
      expect(
        leftRelationship.every(
          (edge) =>
              edge.route == SpatialGraphRouteKind.location ||
              edge.route == SpatialGraphRouteKind.hinge,
        ),
        isTrue,
      );
      _assertPersonRouting(layout);
    },
  );

  test(
    'multiple contexts share one left tangent ordered by their own clocks',
    () {
      final photo = _item(
        id: 'photo',
        lastPreservedAt: DateTime(2026, 8, 14, 14, 20),
      );
      final c1 = _item(
        id: 'c1',
        kind: WorkspaceEvidenceKind.note,
        parentEvidenceId: 'photo',
        isContextual: true,
        lastPreservedAt: DateTime(2026, 8, 14, 14, 22),
      );
      final c2 = _item(
        id: 'c2',
        kind: WorkspaceEvidenceKind.voice,
        parentEvidenceId: 'photo',
        isContextual: true,
        lastPreservedAt: DateTime(2026, 8, 14, 14, 26),
      );
      final c3 = _item(
        id: 'c3',
        kind: WorkspaceEvidenceKind.attachment,
        parentEvidenceId: 'photo',
        isContextual: true,
        lastPreservedAt: DateTime(2026, 8, 14, 14, 41),
      );
      final layout = SpatialGraphLayout.fromGraph(
        _graph(
          items: [photo, c1, c2, c3],
          supporting: const {
            'photo': ['c1', 'c2', 'c3'],
          },
        ),
      );
      final moment = layout.nodeById('photo')!;
      final nodes = [
        layout.nodeById('c1')!,
        layout.nodeById('c2')!,
        layout.nodeById('c3')!,
      ];
      expect(moment.subtitle, '14:20');
      expect(nodes[0].subtitle, '14:22');
      expect(nodes[1].subtitle, '14:26');
      expect(nodes[2].subtitle, '14:41');
      for (final node in nodes) {
        expect(node.kind, SpatialGraphNodeKind.context);
        expect(node.position.dx, lessThan(layout.axisX));
        expect(
          (SpatialGraphLayout.markCenter(node).dy -
                  SpatialGraphLayout.markCenter(moment).dy)
              .abs(),
          lessThan(2),
        );
      }
      expect(nodes[0].position.dx, greaterThan(nodes[1].position.dx));
      expect(nodes[1].position.dx, greaterThan(nodes[2].position.dx));
      for (var i = 0; i < nodes.length; i++) {
        for (var j = i + 1; j < nodes.length; j++) {
          expect(_boxesOverlap(nodes[i], nodes[j]), isFalse);
        }
      }
      final hinges = layout.edges
          .where((edge) => edge.route == SpatialGraphRouteKind.hinge)
          .toList();
      expect(hinges, hasLength(1));
      expect(hinges.single.points, hasLength(2));
      expect(
        (hinges.single.points.first.dy - hinges.single.points.last.dy).abs(),
        lessThan(0.5),
      );
      expect(
        layout.nodes.where((node) => node.kind == SpatialGraphNodeKind.moment),
        hasLength(1),
      );
      expect(layout.size.width, greaterThan(layout.axisX + 40));
      expect(
        [for (final node in layout.nodes) SpatialGraphLayout.nodeBox(node).left]
            .reduce(math.min),
        lessThan(layout.axisX - 40),
      );
    },
  );

  test('inferred location is marked uncertain; GPS location is not', () {
    final gps = _item(id: 'gps', latitude: 27.7, longitude: 85.3);
    final inferred = _item(
      id: 'inferred',
      kind: WorkspaceEvidenceKind.video,
      lastPreservedAt: DateTime(2026, 8, 14, 10, 12),
    );
    final layout = SpatialGraphLayout.fromGraph(
      _graph(
        items: [gps, inferred],
        collections: [
          EvidenceCollection(
            id: 'loc-1',
            incidentId: 'inc-graph',
            name: 'Lobby',
            category: 'location',
            systemGenerated: true,
            pending: true,
            displayOrder: 0,
            createdAt: DateTime(2026, 8, 14),
            updatedAt: DateTime(2026, 8, 14),
            memberEvidenceIds: const ['gps', 'inferred'],
          ),
        ],
      ),
    );
    final gpsPin = layout.nodeById(SpatialGraphLayout.locationNodeId('gps'))!;
    final inferredPin = layout.nodeById(
      SpatialGraphLayout.locationNodeId('inferred'),
    )!;
    expect(gpsPin.locationUncertain, isFalse);
    expect(inferredPin.locationUncertain, isTrue);
    expect(inferredPin.position.dx, lessThan(layout.axisX));
  });

  test('significant gap sits close to the axis without touching it', () {
    final items = staggered(
      gapsAfterFirst: const [
        Duration(minutes: 5),
        Duration(hours: 7),
        Duration(minutes: 8),
      ],
    );
    final layout = SpatialGraphLayout.fromGraph(_graph(items: items));
    expect(layout.gaps, hasLength(1));
    final gap = layout.gaps.single;
    expect(gap.x + 36, lessThan(layout.axisX));
    expect(layout.axisX - (gap.x + 48), greaterThanOrEqualTo(8));
    expect(layout.axisX - gap.x, lessThan(70));
  });
}
