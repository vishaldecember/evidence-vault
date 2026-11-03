import 'dart:ui';

import 'package:evidence_vault/domain/collection/evidence_collection.dart';
import 'package:evidence_vault/domain/organize/organize_context_anchor.dart';
import 'package:evidence_vault/models/verification_factory.dart';
import 'package:evidence_vault/models/workspace_evidence_item.dart';
import 'package:evidence_vault/services/investigation/connection_trace_engine.dart';
import 'package:evidence_vault/services/investigation/reconstruction_canvas_layout.dart';
import 'package:flutter_test/flutter_test.dart';

WorkspaceEvidenceItem _item({
  required String id,
  WorkspaceEvidenceKind kind = WorkspaceEvidenceKind.image,
  DateTime? capturedAt,
  double? latitude,
  double? longitude,
  String? parentEvidenceId,
  String incidentId = 'inc-A',
}) {
  return WorkspaceEvidenceItem(
    id: id,
    kind: kind,
    title: 'Evidence $id',
    lastPreservedAt: capturedAt ?? DateTime.utc(2026, 8, 28, 4, 42),
    capturedAt: capturedAt,
    integrityVerified: true,
    verification: VerificationFactory.initial(),
    incidentId: incidentId,
    latitude: latitude,
    longitude: longitude,
    parentEvidenceId: parentEvidenceId,
  );
}

void main() {
  group('ReconstructionCanvasLayout', () {
    test(
      'places later moments farther along X and shared locations on the same Y',
      () {
        final cafe = DateTime.utc(2026, 8, 28, 4, 30);
        final street = DateTime.utc(2026, 8, 28, 4, 42);
        final laterCafe = DateTime.utc(2026, 8, 28, 5, 5);
        final plot = ReconstructionCanvasLayout.fromEvidence(
          evidence: [
            _item(
              id: 'a',
              capturedAt: cafe,
              latitude: 27.7172,
              longitude: 85.3240,
            ),
            _item(
              id: 'b',
              capturedAt: street,
              latitude: 27.7100,
              longitude: 85.3100,
            ),
            _item(
              id: 'c',
              capturedAt: laterCafe,
              latitude: 27.7172,
              longitude: 85.3240,
            ),
          ],
        );

        final a = plot.nodeById('a')!;
        final b = plot.nodeById('b')!;
        final c = plot.nodeById('c')!;
        expect(a.position.dx < b.position.dx, isTrue);
        expect(b.position.dx < c.position.dx, isTrue);
        expect(a.locationKey, c.locationKey);
        expect(a.position.dy, closeTo(c.position.dy, 0.5));
        expect(a.position.dy, isNot(closeTo(b.position.dy, 8)));
        expect(plot.bands, hasLength(2));
      },
    );

    test('unknown location keeps time on X and a read-only unavailable band', () {
      final plot = ReconstructionCanvasLayout.fromEvidence(
        evidence: [
          _item(
            id: 'known',
            capturedAt: DateTime.utc(2026, 8, 28, 4, 30),
            latitude: 27.7172,
            longitude: 85.3240,
          ),
          _item(id: 'lost', capturedAt: DateTime.utc(2026, 8, 28, 4, 50)),
        ],
      );

      final known = plot.nodeById('known')!;
      final lost = plot.nodeById('lost')!;
      expect(lost.position.dx > known.position.dx, isTrue);
      expect(lost.locationKey, ReconstructionCanvasLayout.unknownKey);
      final unknown = plot.bands.singleWhere(
        (band) => band.key == ReconstructionCanvasLayout.unknownKey,
      );
      expect(
        unknown.label,
        ReconstructionCanvasLayout.locationUnavailableLabel,
      );
      expect(unknown.y < known.position.dy, isTrue);
    });

    test(
      'location collection without GPS stays unavailable, not a user name',
      () {
        final plot = ReconstructionCanvasLayout.fromEvidence(
          evidence: [
            _item(id: 'photo', capturedAt: DateTime.utc(2026, 8, 28, 4, 42)),
          ],
          collections: [
            EvidenceCollection(
              id: 'loc-1',
              incidentId: 'inc-A',
              name: 'Café ABC',
              systemGenerated: false,
              displayOrder: 0,
              createdAt: DateTime.utc(2026, 8, 28),
              updatedAt: DateTime.utc(2026, 8, 28),
              category: 'location',
              memberEvidenceIds: const ['photo'],
            ),
          ],
        );

        expect(plot.bands, hasLength(1));
        expect(
          plot.bands.single.label,
          ReconstructionCanvasLayout.locationUnavailableLabel,
        );
        expect(plot.bands.single.key, ReconstructionCanvasLayout.unknownKey);
      },
    );

    test(
      'location collections beat coordinates; labels stay unique per band',
      () {
        final plot = ReconstructionCanvasLayout.fromEvidence(
          evidence: [
            _item(
              id: 'photo',
              capturedAt: DateTime.utc(2026, 8, 28, 4, 42),
              latitude: 27.7172,
              longitude: 85.3240,
            ),
          ],
          collections: [
            EvidenceCollection(
              id: 'loc-1',
              incidentId: 'inc-A',
              name: 'Café ABC',
              systemGenerated: false,
              displayOrder: 0,
              createdAt: DateTime.utc(2026, 8, 28),
              updatedAt: DateTime.utc(2026, 8, 28),
              category: 'location',
              memberEvidenceIds: const ['photo'],
            ),
          ],
        );

        expect(plot.bands, hasLength(1));
        expect(plot.bands.single.label, 'Café ABC');
        expect(plot.bands.single.key, 'loc:loc-1');
      },
    );

    test(
      'location band keeps stored coordinates for the complete GPS reveal',
      () {
        final plot = ReconstructionCanvasLayout.fromEvidence(
          evidence: [
            _item(
              id: 'photo',
              capturedAt: DateTime.utc(2026, 8, 28, 4, 42),
              latitude: 30.086731,
              longitude: 78.267608,
            ),
          ],
        );
        expect(plot.bands.single.latitude, 30.086731);
        expect(plot.bands.single.longitude, 78.267608);
      },
    );

    test(
      'coordinate labels use captured degrees when no place name exists',
      () {
        final plot = ReconstructionCanvasLayout.fromEvidence(
          evidence: [
            _item(
              id: 'photo',
              capturedAt: DateTime.utc(2026, 8, 28, 4, 42),
              latitude: 27.7172,
              longitude: 85.3240,
            ),
          ],
        );
        expect(plot.bands.single.label, '27.7172°, 85.3240°');
      },
    );

    test(
      'Organize context sits at the host moment, not on its own chronology',
      () {
        final hostAt = DateTime.utc(2026, 8, 28, 4, 42);
        final contextAt = DateTime.utc(2026, 8, 28, 9, 0);
        final plot = ReconstructionCanvasLayout.fromEvidence(
          evidence: [
            _item(
              id: 'photo',
              capturedAt: hostAt,
              latitude: 27.7172,
              longitude: 85.3240,
            ),
            _item(
              id: 'note',
              kind: WorkspaceEvidenceKind.note,
              capturedAt: contextAt,
            ),
          ],
          organizeCreatedIds: const {'note'},
          contextAnchors: const [
            OrganizeContextAnchor(
              contextEvidenceId: 'note',
              capturedEvidenceId: 'photo',
            ),
          ],
        );

        final photo = plot.nodeById('photo')!;
        final note = plot.nodeById('note')!;
        expect(photo.kind, ReconstructionPlotKind.evidence);
        expect(note.kind, ReconstructionPlotKind.context);
        expect(
          (photo.position - note.position).distance,
          closeTo(ConnectionTraceEngine.markSize, 0.51),
        );
        expect(note.position.dx, closeTo(photo.position.dx, 0.5));
        expect(plot.timeMarks, hasLength(1));
        expect(plot.timeMarks.single.x, closeTo(photo.position.dx, 0.5));
      },
    );

    test('same place and time cluster without overlapping nodes', () {
      final at = DateTime.utc(2026, 8, 28, 4, 42);
      final plot = ReconstructionCanvasLayout.fromEvidence(
        evidence: [
          _item(id: 'photo', capturedAt: at, latitude: 27.1, longitude: 85.3),
          _item(
            id: 'voice',
            kind: WorkspaceEvidenceKind.voice,
            capturedAt: at.add(const Duration(seconds: 8)),
            latitude: 27.1,
            longitude: 85.3,
          ),
          _item(
            id: 'file',
            kind: WorkspaceEvidenceKind.attachment,
            capturedAt: at,
            parentEvidenceId: 'photo',
          ),
        ],
      );

      expect(plot.nodes, hasLength(3));
      for (var i = 0; i < plot.nodes.length; i++) {
        for (var j = i + 1; j < plot.nodes.length; j++) {
          expect(
            (plot.nodes[i].position - plot.nodes[j].position).distance,
            greaterThanOrEqualTo(ConnectionTraceEngine.markSize),
          );
        }
      }
    });

    test('time marks stack date then time from the captured instant', () {
      final at = DateTime.utc(2026, 8, 28, 4, 42);
      final plot = ReconstructionCanvasLayout.fromEvidence(
        evidence: [
          _item(id: 'photo', capturedAt: at, latitude: 27.1, longitude: 85.3),
        ],
      );
      expect(plot.timeMarks, hasLength(1));
      expect(
        plot.timeMarks.single.dateLabel,
        ReconstructionCanvasLayout.formatDate(at),
      );
      expect(
        plot.timeMarks.single.timeLabel,
        ReconstructionCanvasLayout.formatTime(at),
      );
    });

    test('does not emit people or participant nodes', () {
      final plot = ReconstructionCanvasLayout.fromEvidence(
        evidence: [
          _item(
            id: 'photo',
            capturedAt: DateTime.utc(2026, 8, 28, 4, 42),
            latitude: 27.1,
            longitude: 85.3,
          ),
        ],
      );
      expect(
        plot.nodes.every(
          (node) => node.kind == ReconstructionPlotKind.evidence,
        ),
        isTrue,
      );
      expect(
        plot.nodes.any(
          (node) => node.item.kind == WorkspaceEvidenceKind.witness,
        ),
        isFalse,
      );
    });

    test('X spacing is ordinal UX, not elapsed time', () {
      final t0 = DateTime.utc(2026, 8, 28, 7, 15, 30);
      final plot = ReconstructionCanvasLayout.fromEvidence(
        evidence: [
          _item(id: 'a', capturedAt: t0, latitude: 27.1, longitude: 85.3),
          _item(
            id: 'b',
            capturedAt: t0.add(const Duration(seconds: 15)),
            latitude: 27.1,
            longitude: 85.3,
          ),
          _item(
            id: 'c',
            capturedAt: t0.add(const Duration(minutes: 50)),
            latitude: 27.1,
            longitude: 85.3,
          ),
        ],
      );
      final a = plot.nodeById('a')!;
      final b = plot.nodeById('b')!;
      final c = plot.nodeById('c')!;
      final firstGap = b.position.dx - a.position.dx;
      final secondGap = c.position.dx - b.position.dx;
      expect(firstGap, greaterThan(30));
      expect((firstGap - secondGap).abs(), lessThan(8));
      expect(plot.timeMarks, hasLength(3));
      expect(plot.timeMarks[0].x, closeTo(a.position.dx, 0.5));
      expect(plot.timeMarks[1].x, closeTo(b.position.dx, 0.5));
      expect(plot.timeMarks[2].x, closeTo(c.position.dx, 0.5));
    });

    test('Y spacing is ordinal location rows, not geographic distance', () {
      final t0 = DateTime.utc(2026, 8, 28, 7, 15, 30);
      final plot = ReconstructionCanvasLayout.fromEvidence(
        evidence: [
          _item(
            id: 'near',
            capturedAt: t0,
            latitude: 27.1000,
            longitude: 85.3000,
          ),
          _item(
            id: 'far',
            capturedAt: t0.add(const Duration(minutes: 1)),
            latitude: 27.5000,
            longitude: 85.8000,
          ),
        ],
      );
      final near = plot.nodeById('near')!;
      final far = plot.nodeById('far')!;
      expect(plot.bands, hasLength(2));
      expect(
        (near.position.dy - far.position.dy).abs(),
        closeTo(
          ReconstructionCanvasLayout.fingerGapFor(
                ReconstructionCanvasLayout.defaultViewport,
              ) *
              3,
          12,
        ),
      );
    });

    test('nodes never overlap, including same timestamp and location', () {
      final at = DateTime.utc(2026, 8, 28, 7, 15, 30);
      final plot = ReconstructionCanvasLayout.fromEvidence(
        evidence: [
          _item(id: 'photo', capturedAt: at, latitude: 27.1, longitude: 85.3),
          _item(
            id: 'voice',
            kind: WorkspaceEvidenceKind.voice,
            capturedAt: at,
            latitude: 27.1,
            longitude: 85.3,
          ),
        ],
      );
      expect(plot.nodes, hasLength(2));
      expect(
        (plot.nodes[0].position - plot.nodes[1].position).distance,
        greaterThanOrEqualTo(ConnectionTraceEngine.markSize),
      );
    });

    test('connected contexts stack and touch the moment circumference', () {
      final at = DateTime.utc(2026, 8, 28, 10, 2);
      final plot = ReconstructionCanvasLayout.fromEvidence(
        evidence: [
          _item(id: 'photo', capturedAt: at, latitude: 27.1, longitude: 85.3),
          _item(
            id: 'note',
            kind: WorkspaceEvidenceKind.note,
            capturedAt: at,
          ),
          _item(
            id: 'voice',
            kind: WorkspaceEvidenceKind.voice,
            capturedAt: at,
          ),
          _item(
            id: 'file',
            kind: WorkspaceEvidenceKind.attachment,
            capturedAt: at,
          ),
        ],
        organizeCreatedIds: const {'note', 'voice', 'file'},
        contextAnchors: const [
          OrganizeContextAnchor(
            contextEvidenceId: 'note',
            capturedEvidenceId: 'photo',
          ),
          OrganizeContextAnchor(
            contextEvidenceId: 'voice',
            capturedEvidenceId: 'photo',
          ),
          OrganizeContextAnchor(
            contextEvidenceId: 'file',
            capturedEvidenceId: 'photo',
          ),
        ],
      );

      final photo = plot.nodeById('photo')!;
      final stacked = [
        plot.nodeById('note')!,
        plot.nodeById('voice')!,
        plot.nodeById('file')!,
      ]..sort((a, b) => a.position.dy.compareTo(b.position.dy));

      for (final context in stacked) {
        expect(context.position.dx, closeTo(photo.position.dx, 0.5));
        expect(context.kind, ReconstructionPlotKind.context);
      }
      expect(plot.timeMarks.single.x, closeTo(photo.position.dx, 0.5));

      final column = [...stacked]
        ..sort(
          (a, b) => (a.position.dy - photo.position.dy).abs().compareTo(
            (b.position.dy - photo.position.dy).abs(),
          ),
        );
      expect(
        (column[0].position - photo.position).distance,
        closeTo(ConnectionTraceEngine.markSize, 0.51),
      );
      expect(
        (column[1].position - column[0].position).distance,
        closeTo(ConnectionTraceEngine.markSize, 0.51),
      );
      expect(
        (column[2].position - column[1].position).distance,
        closeTo(ConnectionTraceEngine.markSize, 0.51),
      );
    });

    test('axes sit one finger from the left and bottom of the viewport', () {
      const viewport = Size(390, 844);
      final plot = ReconstructionCanvasLayout.fromEvidence(
        evidence: [
          _item(
            id: 'photo',
            capturedAt: DateTime.utc(2026, 8, 28, 7, 15, 30),
            latitude: 27.1,
            longitude: 85.3,
          ),
        ],
        viewport: viewport,
      );
      final finger = ReconstructionCanvasLayout.fingerGapFor(viewport);
      expect(plot.origin.dx, closeTo(finger, 1));
      expect(plot.origin.dy, closeTo(viewport.height - finger, 1));
      expect(plot.axisYEnd.dx, plot.origin.dx);
      expect(plot.axisXEnd.dy, plot.origin.dy);
    });

    test(
      'canvas width stops after the rightmost evidence plus trailing margin',
      () {
        const viewport = Size(1200, 844);
        final plot = ReconstructionCanvasLayout.fromEvidence(
          evidence: [
            _item(
              id: 'photo',
              capturedAt: DateTime.utc(2026, 8, 28, 7, 15, 30),
              latitude: 27.1,
              longitude: 85.3,
            ),
          ],
          viewport: viewport,
        );
        final rightmost = plot.nodes.single.position.dx;
        expect(plot.size.width.isFinite, isTrue);
        expect(
          plot.size.width,
          closeTo(
            rightmost +
                ReconstructionCanvasLayout.markSize / 2 +
                ReconstructionCanvasLayout.rightPad,
            0.5,
          ),
        );
        expect(plot.size.width, lessThan(viewport.width));
        expect(
          plot.axisXEnd.dx,
          closeTo(rightmost + ReconstructionCanvasLayout.markSize / 2, 0.5),
        );
      },
    );

    test('CASE A: one evidence keeps ordinal X and a finite right edge', () {
      final plot = ReconstructionCanvasLayout.fromEvidence(
        evidence: [
          _item(
            id: 'photo',
            capturedAt: DateTime.utc(2026, 8, 28, 7, 15, 30),
            latitude: 27.1,
            longitude: 85.3,
          ),
        ],
      );
      expect(plot.nodes, hasLength(1));
      expect(plot.timeMarks, hasLength(1));
      expect(
        plot.timeMarks.single.x,
        closeTo(plot.nodes.single.position.dx, 0.5),
      );
      expect(
        plot.size.width,
        closeTo(
          plot.nodes.single.position.dx +
              ReconstructionCanvasLayout.markSize / 2 +
              ReconstructionCanvasLayout.rightPad,
          0.5,
        ),
      );
      expect(plot.size.height, ReconstructionCanvasLayout.defaultViewport.height);
    });

    test('CASE B: hours-apart evidence keep equal ordinal X gaps', () {
      final t0 = DateTime.utc(2026, 8, 28, 10, 0);
      final plot = ReconstructionCanvasLayout.fromEvidence(
        evidence: [
          _item(id: 'a', capturedAt: t0, latitude: 27.1, longitude: 85.3),
          _item(
            id: 'b',
            capturedAt: t0.add(const Duration(hours: 8)),
            latitude: 27.1,
            longitude: 85.3,
          ),
        ],
      );
      final gap = plot.nodeById('b')!.position.dx - plot.nodeById('a')!.position.dx;
      expect(gap, greaterThan(30));
      expect(
        plot.timeMarks[1].x - plot.timeMarks[0].x,
        closeTo(gap, 0.5),
      );
      expect(
        plot.size.width,
        closeTo(
          plot.nodeById('b')!.position.dx +
              ReconstructionCanvasLayout.markSize / 2 +
              ReconstructionCanvasLayout.rightPad,
          0.5,
        ),
      );
    });

    test('CASE C: close-together evidence keep finger-width X separation', () {
      final t0 = DateTime.utc(2026, 8, 28, 10, 0);
      final plot = ReconstructionCanvasLayout.fromEvidence(
        evidence: [
          _item(id: 'a', capturedAt: t0, latitude: 27.1, longitude: 85.3),
          _item(
            id: 'b',
            capturedAt: t0.add(const Duration(seconds: 1)),
            latitude: 27.1,
            longitude: 85.3,
          ),
          _item(
            id: 'c',
            capturedAt: t0.add(const Duration(seconds: 2)),
            latitude: 27.1,
            longitude: 85.3,
          ),
        ],
      );
      final ab = plot.nodeById('b')!.position.dx - plot.nodeById('a')!.position.dx;
      final bc = plot.nodeById('c')!.position.dx - plot.nodeById('b')!.position.dx;
      expect(ab, greaterThan(30));
      expect((ab - bc).abs(), lessThan(8));
      final markXs = [for (final mark in plot.timeMarks) mark.x]..sort();
      for (var i = 1; i < markXs.length; i++) {
        expect(markXs[i] - markXs[i - 1], greaterThan(30));
      }
    });

    test(
      'CASE D: burst then later item keeps ordinal gaps and a finite canvas',
      () {
        const viewport = Size(412, 915);
        final plot = ReconstructionCanvasLayout.fromEvidence(
          evidence: [
            _item(
              id: 'a',
              capturedAt: DateTime.utc(2026, 8, 28, 10, 0, 0),
              latitude: 27.1,
              longitude: 85.3,
            ),
            _item(
              id: 'b',
              capturedAt: DateTime.utc(2026, 8, 28, 10, 0, 1),
              latitude: 27.1,
              longitude: 85.3,
            ),
            _item(
              id: 'c',
              capturedAt: DateTime.utc(2026, 8, 28, 18, 0, 0),
              latitude: 27.1,
              longitude: 85.3,
            ),
          ],
          viewport: viewport,
        );
        final ab =
            plot.nodeById('b')!.position.dx - plot.nodeById('a')!.position.dx;
        final bc =
            plot.nodeById('c')!.position.dx - plot.nodeById('b')!.position.dx;
        expect(ab, greaterThan(30));
        expect(bc, greaterThan(30));
        expect((ab - bc).abs(), lessThan(8));
        expect(plot.size.width, lessThan(viewport.width * 3));
        expect(plot.size.height, viewport.height);
      },
    );

    test('one evidence still has width for the mark and trailing margin', () {
      final plot = ReconstructionCanvasLayout.fromEvidence(
        evidence: [
          _item(
            id: 'photo',
            capturedAt: DateTime.utc(2026, 8, 28, 7, 15, 30),
            latitude: 27.1,
            longitude: 85.3,
          ),
        ],
      );
      expect(plot.nodes, hasLength(1));
      expect(
        plot.size.width,
        greaterThan(
          plot.nodes.single.position.dx + ReconstructionCanvasLayout.markSize / 2,
        ),
      );
      expect(
        plot.size.width -
            (plot.nodes.single.position.dx +
                ReconstructionCanvasLayout.markSize / 2),
        closeTo(ReconstructionCanvasLayout.rightPad, 0.5),
      );
    });

    test(
      'multiple evidence bound the canvas by the rightmost laid-out position',
      () {
        final plot = ReconstructionCanvasLayout.fromEvidence(
          evidence: [
            _item(
              id: 'a',
              capturedAt: DateTime.utc(2026, 8, 28, 10, 0, 0),
              latitude: 27.1,
              longitude: 85.3,
            ),
            _item(
              id: 'b',
              capturedAt: DateTime.utc(2026, 8, 28, 10, 0, 1),
              latitude: 27.1,
              longitude: 85.3,
            ),
            _item(
              id: 'c',
              capturedAt: DateTime.utc(2026, 8, 28, 18, 0, 0),
              latitude: 27.1,
              longitude: 85.3,
            ),
          ],
        );
        var rightmost = plot.origin.dx;
        for (final node in plot.nodes) {
          if (node.position.dx > rightmost) {
            rightmost = node.position.dx;
          }
        }
        expect(
          plot.size.width,
          closeTo(
            rightmost +
                ReconstructionCanvasLayout.markSize / 2 +
                ReconstructionCanvasLayout.rightPad,
            0.5,
          ),
        );
      },
    );

    test(
      'close timestamps do not explode the InteractiveViewer child width',
      () {
        const viewport = Size(412, 915);
        final plot = ReconstructionCanvasLayout.fromEvidence(
          evidence: [
            _item(
              id: 'a',
              capturedAt: DateTime.utc(2026, 8, 28, 10, 0, 0),
              latitude: 27.1,
              longitude: 85.3,
            ),
            _item(
              id: 'b',
              capturedAt: DateTime.utc(2026, 8, 28, 10, 0, 1),
              latitude: 27.1,
              longitude: 85.3,
            ),
            _item(
              id: 'c',
              capturedAt: DateTime.utc(2026, 8, 28, 18, 0, 0),
              latitude: 27.1,
              longitude: 85.3,
            ),
          ],
          viewport: viewport,
        );
        var rightmost = plot.origin.dx;
        for (final node in plot.nodes) {
          if (node.position.dx > rightmost) {
            rightmost = node.position.dx;
          }
        }
        expect(plot.size.width.isFinite, isTrue);
        expect(
          plot.size.width,
          closeTo(
            rightmost +
                ReconstructionCanvasLayout.markSize / 2 +
                ReconstructionCanvasLayout.rightPad,
            0.5,
          ),
        );
        expect(plot.size.width, lessThan(viewport.width * 3));
        expect(
          plot.nodeById('b')!.position.dx - plot.nodeById('a')!.position.dx,
          greaterThan(30),
        );
        expect(
          plot.nodeById('c')!.position.dx - plot.nodeById('b')!.position.dx,
          greaterThan(30),
        );
        final markXs = [for (final mark in plot.timeMarks) mark.x]..sort();
        for (var i = 1; i < markXs.length; i++) {
          expect(markXs[i] - markXs[i - 1], greaterThan(30));
        }
      },
    );

    test('later evidence expands the canvas to include it', () {
      final first = ReconstructionCanvasLayout.fromEvidence(
        evidence: [
          _item(
            id: 'a',
            capturedAt: DateTime.utc(2026, 8, 28, 10, 0),
            latitude: 27.1,
            longitude: 85.3,
          ),
        ],
      );
      final later = ReconstructionCanvasLayout.fromEvidence(
        evidence: [
          _item(
            id: 'a',
            capturedAt: DateTime.utc(2026, 8, 28, 10, 0),
            latitude: 27.1,
            longitude: 85.3,
          ),
          _item(
            id: 'b',
            capturedAt: DateTime.utc(2026, 8, 28, 12, 0),
            latitude: 27.2,
            longitude: 85.4,
          ),
        ],
      );
      expect(later.size.width, greaterThan(first.size.width));
      final rightmost = later.nodeById('b')!.position.dx;
      expect(
        later.size.width,
        closeTo(
          rightmost +
              ReconstructionCanvasLayout.markSize / 2 +
              ReconstructionCanvasLayout.rightPad,
          0.5,
        ),
      );
    });

    test('empty evidence keeps the compact empty canvas', () {
      const viewport = Size(390, 844);
      final plot = ReconstructionCanvasLayout.fromEvidence(
        evidence: const [],
        viewport: viewport,
      );
      expect(plot.nodes, isEmpty);
      expect(plot.size.width, viewport.width);
      expect(plot.size.width.isFinite, isTrue);
    });

    test('nodes stay clear of both axes, including attachments', () {
      const viewport = Size(390, 844);
      final at = DateTime.utc(2026, 8, 28, 7, 15, 30);
      final plot = ReconstructionCanvasLayout.fromEvidence(
        evidence: [
          _item(
            id: 'file',
            kind: WorkspaceEvidenceKind.attachment,
            capturedAt: at,
            latitude: 27.1,
            longitude: 85.3,
          ),
          _item(id: 'photo', capturedAt: at, latitude: 27.1, longitude: 85.3),
        ],
        viewport: viewport,
      );
      final radius = ReconstructionCanvasLayout.markSize / 2;
      for (final node in plot.nodes) {
        expect(node.position.dx - radius, greaterThan(plot.origin.dx));
        expect(node.position.dy + radius, lessThan(plot.origin.dy));
        expect(node.position.dx + radius, greaterThan(plot.origin.dx));
      }
    });
  });
}
