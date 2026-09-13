import 'dart:io';

import 'package:evidence_vault/widgets/capture/capture_preview_overlay.dart';
import 'package:evidence_vault/widgets/evidence_inspector/evidence_media_source.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'photo confirmation decodes at display width, not a native JPEG',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(390, 844));

      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(size: Size(390, 844), devicePixelRatio: 2.5),
          child: MaterialApp(
            home: Center(
              child: SizedBox(
                width: 280,
                height: 420,
                child: CaptureImagePreview(path: 'missing-preview.jpg'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final image = tester.widget<Image>(find.byType(Image));
      expect(image.image, isA<ResizeImage>());
      final resized = image.image as ResizeImage;
      expect(
        resized.width,
        EvidenceMediaSource.decodeWidth(
          logicalWidth: 280,
          devicePixelRatio: 2.5,
        ),
      );
      expect(resized.width, lessThan(1024));
      expect(FileImage(File('missing-preview.jpg')), isNot(image.image));
    },
  );
}
