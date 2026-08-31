import 'package:evidence_vault/widgets/workspace/organize_context_targeting.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const a = Offset(40, 80);
  const b = Offset(40, 200);
  final centers = <String, Offset>{'A': a, 'B': b};

  test('first alignment emits a detent; staying put does not', () {
    String? active;
    final entries = <String>[];

    void consider(Offset pointer) {
      final next = OrganizeContextTargeting.resolveDetentAlignment(
        centers: centers,
        pointer: pointer,
      );
      if (OrganizeContextTargeting.shouldEmitDetent(
        previousDetentId: active,
        nextDetentId: next,
      )) {
        entries.add(next!);
      }
      active = next;
    }

    consider(a);
    consider(a.translate(4, 2));
    consider(a.translate(-3, 1));
    expect(entries, ['A']);
  });

  test('A → B → A emits three alignment-entry events', () {
    String? active;
    final entries = <String>[];

    void consider(Offset pointer) {
      final next = OrganizeContextTargeting.resolveDetentAlignment(
        centers: centers,
        pointer: pointer,
      );
      if (OrganizeContextTargeting.shouldEmitDetent(
        previousDetentId: active,
        nextDetentId: next,
      )) {
        entries.add(next!);
      }
      active = next;
    }

    consider(a);
    consider(b);
    consider(a);
    expect(entries, ['A', 'B', 'A']);
  });

  test('exact target prefers the thumbnail under the pointer', () {
    final rects = <String, Rect>{
      'A': const Rect.fromLTWH(0, 0, 72, 72),
      'B': const Rect.fromLTWH(0, 120, 72, 72),
    };
    expect(
      OrganizeContextTargeting.resolveExactTarget(
        targetRects: rects,
        pointer: const Offset(36, 150),
      ),
      'B',
    );
    expect(
      OrganizeContextTargeting.resolveExactTarget(
        targetRects: rects,
        pointer: const Offset(36, 20),
      ),
      'A',
    );
  });

  test('exact target does not pick a horizontally distant moment', () {
    final rects = <String, Rect>{
      'A': const Rect.fromLTWH(0, 0, 72, 72),
      'B': const Rect.fromLTWH(0, 400, 72, 72),
    };
    expect(
      OrganizeContextTargeting.resolveExactTarget(
        targetRects: rects,
        pointer: const Offset(200, 36),
      ),
      isNull,
    );
  });

  test('magnet enters at 72px and retains to 84px without flipping', () {
    expect(OrganizeContextTargeting.enterDistance, 72);
    expect(OrganizeContextTargeting.retainDistance, 84);

    final close = <String, Offset>{
      'A': const Offset(0, 0),
      'B': const Offset(0, 100),
    };

    final enteredA = OrganizeContextTargeting.resolveMagnet(
      currentId: null,
      centers: close,
      pointer: const Offset(0, 40),
    );
    expect(enteredA, 'A');

    final retainedA = OrganizeContextTargeting.resolveMagnet(
      currentId: 'A',
      centers: close,
      pointer: const Offset(0, 80),
    );
    expect(retainedA, 'A');

    final releasedThenB = OrganizeContextTargeting.resolveMagnet(
      currentId: 'A',
      centers: close,
      pointer: const Offset(0, 90),
    );
    expect(releasedThenB, 'B');
  });

  test('new magnet lock still requires enterDistance', () {
    final locked = OrganizeContextTargeting.resolveMagnet(
      currentId: null,
      centers: {'A': Offset.zero},
      pointer: const Offset(72, 0),
    );
    expect(locked, isNull);

    final justInside = OrganizeContextTargeting.resolveMagnet(
      currentId: null,
      centers: {'A': Offset.zero},
      pointer: const Offset(71.5, 0),
    );
    expect(justInside, 'A');
  });
}
