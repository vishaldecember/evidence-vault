import 'package:evidence_vault/domain/organize/organize_floating_context_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('I deterministic non-overlapping positions for multiple context objects', () {
    const width = 390.0;
    final first = OrganizeFloatingContextLayout.rectFor(
      index: 0,
      canvasWidth: width,
    );
    final second = OrganizeFloatingContextLayout.rectFor(
      index: 1,
      canvasWidth: width,
    );
    final third = OrganizeFloatingContextLayout.rectFor(
      index: 2,
      canvasWidth: width,
    );

    expect(first.left, greaterThan(second.left));
    expect(second.top, greaterThan(first.top));
    expect(third.top, greaterThan(second.top));
    expect(
      OrganizeFloatingContextLayout.rectsOverlap(first, second),
      isFalse,
    );
    expect(
      OrganizeFloatingContextLayout.rectsOverlap(second, third),
      isFalse,
    );
    expect(
      OrganizeFloatingContextLayout.rectsOverlap(first, third),
      isFalse,
    );
    expect(first.left + first.width, lessThanOrEqualTo(width + 0.5));
  });
}
