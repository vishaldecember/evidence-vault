import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:evidence_vault/domain/evidence/evidence_record_type.dart';
import 'package:evidence_vault/domain/evidence/evidence_sync_status.dart';
import 'package:evidence_vault/services/storage/cached_evidence_entry.dart';
import 'package:evidence_vault/services/storage/local_evidence_cache.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.root);
  final String root;

  @override
  Future<String?> getApplicationDocumentsPath() async => root;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempRoot;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('ev_index_corruption_');
    PathProviderPlatform.instance = _FakePathProvider(tempRoot.path);
    LocalEvidenceCache.resetForTests();
  });

  tearDown(() async {
    LocalEvidenceCache.resetForTests();
    if (await tempRoot.exists()) {
      await tempRoot.delete(recursive: true);
    }
  });

  test('blocks access and preserves the original corrupt index', () async {
    final entry = CachedEvidenceEntry(
      evidenceId: 'ev-regression-001',
      incidentId: 'incident-regression-001',
      userId: 'test-user',
      evidenceType: EvidenceRecordType.photo,
      createdAt: DateTime.utc(2026, 1, 1),
      capturedAt: DateTime.utc(2026, 1, 1),
      syncStatus: EvidenceSyncStatus.localCaptured,
    );

    final indexFile = File(
      p.join(tempRoot.path, 'evidence_cache', 'metadata_index.json'),
    );
    await indexFile.parent.create(recursive: true);

    final originalContent =
        '${jsonEncode([entry.toJson()])}CORRUPT_TRAILING_DATA';
    await indexFile.writeAsString(originalContent);

    await expectLater(
      LocalEvidenceCache.all(),
      throwsA(isA<StateError>()),
    );
    expect(await indexFile.readAsString(), originalContent);

    await expectLater(
      LocalEvidenceCache.upsert(entry),
      throwsA(isA<StateError>()),
    );
    expect(await indexFile.readAsString(), originalContent);
  });
}