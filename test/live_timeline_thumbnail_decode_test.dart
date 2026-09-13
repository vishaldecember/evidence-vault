import 'dart:io';

import 'package:evidence_vault/models/verification_factory.dart';
import 'package:evidence_vault/models/workspace_evidence_item.dart';
import 'package:evidence_vault/widgets/capture/live_evidence_timeline.dart';
import 'package:evidence_vault/widgets/evidence_inspector/evidence_media_source.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('56px timeline badge requests a small decode, not a camera original', () {
    final cacheWidth = EvidenceMediaSource.decodeWidth(
      logicalWidth: 56,
      devicePixelRatio: 2.5,
    );
    final image = Image.file(
      File('original.jpg'),
      cacheWidth: cacheWidth,
      cacheHeight: cacheWidth,
    );
    expect(image.image, isA<ResizeImage>());
    final resized = image.image as ResizeImage;
    expect(resized.width, 140);
    expect(resized.height, 140);
    expect(cacheWidth, lessThan(256));
  });

  testWidgets('timeline still lists photo evidence when no file is present', (
    tester,
  ) async {
    final item = WorkspaceEvidenceItem(
      id: 'photo-1',
      kind: WorkspaceEvidenceKind.image,
      title: 'Photo',
      lastPreservedAt: DateTime(2026, 9, 10, 12),
      integrityVerified: false,
      verification: VerificationFactory.initial(),
      filePath: '/absent/original.jpg',
      thumbnailPath: '/absent/original.jpg',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LiveEvidenceTimeline(items: [item]),
        ),
      ),
    );

    expect(find.byKey(const Key('live_timeline_item_photo-1')), findsOneWidget);
    expect(find.byKey(const Key('live_timeline_kind_photo-1')), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });
}
