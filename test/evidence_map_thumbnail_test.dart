import 'dart:io';
import 'dart:typed_data';

import 'package:evidence_vault/models/evidence_artifact_model.dart';
import 'package:evidence_vault/models/verification_factory.dart';
import 'package:evidence_vault/models/workspace_evidence_item.dart';
import 'package:evidence_vault/widgets/evidence/evidence_artifact_card.dart';
import 'package:evidence_vault/widgets/workspace/evidence_map_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

WorkspaceEvidenceItem _item({
  required String id,
  required WorkspaceEvidenceKind kind,
  String? filePath,
  String? thumbnailPath,
  String? notePreview,
  String? fileName,
  String? downloadUrl,
}) {
  return WorkspaceEvidenceItem(
    id: id,
    kind: kind,
    title: kind.label,
    lastPreservedAt: DateTime(2026, 8, 12, 10),
    integrityVerified: true,
    verification: VerificationFactory.initial(),
    filePath: filePath,
    thumbnailPath: thumbnailPath,
    notePreview: notePreview,
    fileName: fileName,
    downloadUrl: downloadUrl,
  );
}

Future<File> _writeTinyJpeg(Directory dir, String name) async {
  final image = img.Image(width: 16, height: 16);
  img.fill(image, color: img.ColorRgb8(40, 120, 200));
  final bytes = Uint8List.fromList(img.encodeJpg(image, quality: 70));
  final file = File('${dir.path}/$name');
  await file.writeAsBytes(bytes, flush: true);
  return file;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempRoot;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('ev_map_thumb_');
  });

  tearDown(() async {
    if (await tempRoot.exists()) {
      await tempRoot.delete(recursive: true);
    }
  });

  group('EvidenceArtifactModel preview paths (Map media wiring)', () {
    test('1. photo evidence resolves real thumbnail path', () async {
      final photo = await _writeTinyJpeg(tempRoot, 'shot.jpg');
      final thumb = await _writeTinyJpeg(tempRoot, 'shot_thumb.jpg');
      final model = EvidenceArtifactModel.fromWorkspaceItem(
        _item(
          id: 'p1',
          kind: WorkspaceEvidenceKind.image,
          filePath: photo.path,
          thumbnailPath: thumb.path,
        ),
      );
      expect(model.type, EvidenceArtifactType.photo);
      expect(model.previewImagePath, thumb.path);
      expect(model.thumbnailPath, thumb.path);
      expect(model.filePath, photo.path);
    });

    test('2. video evidence resolves representative frame thumb', () async {
      final frame = await _writeTinyJpeg(tempRoot, 'frame.jpg');
      final model = EvidenceArtifactModel.fromWorkspaceItem(
        _item(
          id: 'v1',
          kind: WorkspaceEvidenceKind.video,
          filePath: '${tempRoot.path}/clip.mp4',
          thumbnailPath: frame.path,
        ),
      );
      expect(model.type, EvidenceArtifactType.video);
      expect(model.previewImagePath, frame.path);
      // Never treat the mp4 as an image preview.
      expect(model.previewImagePath!.endsWith('.mp4'), isFalse);
    });

    test('3. missing thumbnail falls back to null preview path', () {
      final model = EvidenceArtifactModel.fromWorkspaceItem(
        _item(
          id: 'v2',
          kind: WorkspaceEvidenceKind.video,
          filePath: '${tempRoot.path}/clip.mp4',
        ),
      );
      expect(model.previewImagePath, isNull);
    });

    test('4. missing media paths stay null (no crash in model)', () {
      final model = EvidenceArtifactModel.fromWorkspaceItem(
        _item(id: 'p-missing', kind: WorkspaceEvidenceKind.image),
      );
      expect(model.previewImagePath, isNull);
      expect(model.filePath, isNull);
      expect(model.thumbnailPath, isNull);
    });

    test('5. voice never resolves image preview', () {
      final model = EvidenceArtifactModel.fromWorkspaceItem(
        _item(
          id: 'a1',
          kind: WorkspaceEvidenceKind.voice,
          filePath: '${tempRoot.path}/voice.m4a',
        ),
      );
      expect(model.type, EvidenceArtifactType.voiceRecording);
      expect(model.previewImagePath, isNull);
    });

    test('6. note uses note preview text, not image path', () {
      final model = EvidenceArtifactModel.fromWorkspaceItem(
        _item(
          id: 'n1',
          kind: WorkspaceEvidenceKind.note,
          notePreview: 'Witness said hello',
          filePath: '${tempRoot.path}/note.jpg',
        ),
      );
      expect(model.type, EvidenceArtifactType.note);
      expect(model.notePreview, 'Witness said hello');
      expect(model.previewImagePath, isNull);
    });

    test('7. file uses safe document representation paths', () {
      final pdf = EvidenceArtifactModel.fromWorkspaceItem(
        _item(
          id: 'f1',
          kind: WorkspaceEvidenceKind.attachment,
          fileName: 'policy.pdf',
          filePath: '${tempRoot.path}/policy.pdf',
        ),
      );
      expect(pdf.type, EvidenceArtifactType.document);
      expect(pdf.fileName, 'policy.pdf');
      expect(pdf.previewImagePath, isNull);
      expect(pdf.documentImagePreviewPath, isNull);
    });

    test('8. multiple evidence models resolve independently', () async {
      final photo = await _writeTinyJpeg(tempRoot, 'a.jpg');
      final frame = await _writeTinyJpeg(tempRoot, 'b.jpg');
      final models = [
        EvidenceArtifactModel.fromWorkspaceItem(
          _item(
            id: 'ev-photo',
            kind: WorkspaceEvidenceKind.image,
            thumbnailPath: photo.path,
          ),
        ),
        EvidenceArtifactModel.fromWorkspaceItem(
          _item(
            id: 'ev-video',
            kind: WorkspaceEvidenceKind.video,
            thumbnailPath: frame.path,
          ),
        ),
        EvidenceArtifactModel.fromWorkspaceItem(
          _item(id: 'ev-voice', kind: WorkspaceEvidenceKind.voice),
        ),
        EvidenceArtifactModel.fromWorkspaceItem(
          _item(
            id: 'ev-note',
            kind: WorkspaceEvidenceKind.note,
            notePreview: 'Independent note',
          ),
        ),
        EvidenceArtifactModel.fromWorkspaceItem(
          _item(
            id: 'ev-file',
            kind: WorkspaceEvidenceKind.attachment,
            fileName: 'report.pdf',
          ),
        ),
      ];
      expect(models.map((m) => m.id).toSet(), hasLength(5));
      expect(models[0].previewImagePath, photo.path);
      expect(models[1].previewImagePath, frame.path);
      expect(models[2].previewImagePath, isNull);
      expect(models[3].notePreview, 'Independent note');
      expect(models[4].fileName, 'report.pdf');
    });

    test('10. fromWorkspaceItem keeps evidence id association', () {
      final model = EvidenceArtifactModel.fromWorkspaceItem(
        _item(
          id: 'incident-ev-99',
          kind: WorkspaceEvidenceKind.image,
          thumbnailPath: '${tempRoot.path}/x.jpg',
        ),
      );
      expect(model.id, 'incident-ev-99');
    });
  });

  group('Evidence Map card UI (safe fallbacks / type reps)', () {
    testWidgets('3/4/9. missing media falls back; map does not crash',
        (tester) async {
      // Null paths → icon fallback without Image.file decode in tests.
      final missingPhoto = _item(
        id: 'missing-photo',
        kind: WorkspaceEvidenceKind.image,
      );
      final missingVideo = _item(
        id: 'missing-video',
        kind: WorkspaceEvidenceKind.video,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                EvidenceArtifactCard(
                  artifact:
                      EvidenceArtifactModel.fromWorkspaceItem(missingPhoto),
                ),
                EvidenceArtifactCard(
                  artifact:
                      EvidenceArtifactModel.fromWorkspaceItem(missingVideo),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Photo'), findsOneWidget);
      expect(find.text('Video'), findsOneWidget);
      expect(find.byKey(const Key('evidence_map_thumb_missing-photo')),
          findsOneWidget);
      expect(find.byKey(const Key('evidence_map_thumb_missing-video')),
          findsOneWidget);
      expect(find.byIcon(Icons.photo_outlined), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    });

    testWidgets('5. voice uses audio representation', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EvidenceArtifactCard(
              artifact: EvidenceArtifactModel.fromWorkspaceItem(
                _item(id: 'voice-1', kind: WorkspaceEvidenceKind.voice),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Voice Recording'), findsOneWidget);
      expect(find.byKey(const Key('evidence_map_thumb_voice-1')), findsOneWidget);
    });

    testWidgets('6. note uses note representation', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EvidenceArtifactCard(
              artifact: EvidenceArtifactModel.fromWorkspaceItem(
                _item(
                  id: 'note-1',
                  kind: WorkspaceEvidenceKind.note,
                  notePreview: 'Door was unlocked at 9pm',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.textContaining('Door was unlocked'), findsOneWidget);
    });

    testWidgets('7. file uses document representation', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EvidenceArtifactCard(
              artifact: EvidenceArtifactModel.fromWorkspaceItem(
                _item(
                  id: 'file-1',
                  kind: WorkspaceEvidenceKind.attachment,
                  fileName: 'terms.pdf',
                  filePath: '${tempRoot.path}/terms.pdf',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byIcon(Icons.insert_drive_file_outlined), findsOneWidget);
      expect(find.text('terms.pdf'), findsOneWidget);
    });

    testWidgets(
      '8/9. Evidence Map section renders independent nodes without blocking',
      (tester) async {
        final items = [
          _item(id: 'ev-photo', kind: WorkspaceEvidenceKind.image),
          _item(id: 'ev-video', kind: WorkspaceEvidenceKind.video),
          _item(id: 'ev-voice', kind: WorkspaceEvidenceKind.voice),
          _item(
            id: 'ev-note',
            kind: WorkspaceEvidenceKind.note,
            notePreview: 'Independent note',
          ),
          _item(
            id: 'ev-file',
            kind: WorkspaceEvidenceKind.attachment,
            fileName: 'report.pdf',
          ),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: EvidenceMapSection(
                  evidence: items,
                  onEvidenceSelected: (_) {},
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(EvidenceArtifactCard), findsNWidgets(5));
        expect(find.byKey(const Key('evidence_map_thumb_ev-photo')), findsOneWidget);
        expect(find.byKey(const Key('evidence_map_thumb_ev-video')), findsOneWidget);
        expect(find.byKey(const Key('evidence_map_thumb_ev-voice')), findsOneWidget);
        expect(find.byKey(const Key('evidence_map_thumb_ev-note')), findsOneWidget);
        expect(find.byKey(const Key('evidence_map_thumb_ev-file')), findsOneWidget);
        expect(find.text('Independent note'), findsOneWidget);
        expect(find.text('report.pdf'), findsOneWidget);
      },
    );
  });
}
