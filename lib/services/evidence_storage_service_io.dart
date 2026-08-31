import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/evidence_record.dart';
import '../models/pending_evidence.dart';
import 'evidence_storage_shared.dart';

abstract final class EvidenceStorageService {
  static Directory? _evidenceDir;
  static File? _indexFile;
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;

    final appDir = await getApplicationDocumentsDirectory();
    _evidenceDir = Directory(p.join(appDir.path, 'evidence'));
    await _evidenceDir!.create(recursive: true);
    _indexFile = File(p.join(appDir.path, 'evidence_records.json'));

    if (!await _indexFile!.exists()) {
      await _indexFile!.writeAsString('[]');
    }

    _initialized = true;
  }

  static Future<List<EvidenceRecord>> getAll() async {
    await _ensureInitialized();
    final records = await _readAll();
    return EvidenceStorageShared.filterSaved(records);
  }

  static Future<EvidenceRecord> save(PendingEvidence pending) async {
    await _ensureInitialized();

    final extension = p.extension(pending.filePath);
    final storedFileName = '${pending.metadata.evidenceId}$extension';
    final storedPath = p.join(_evidenceDir!.path, storedFileName);

    await File(pending.filePath).copy(storedPath);

    String? thumbnailPath;
    if (pending.thumbnailPath != null) {
      final thumbExt = p.extension(pending.thumbnailPath!);
      thumbnailPath = p.join(
        _evidenceDir!.path,
        '${pending.metadata.evidenceId}_thumb$thumbExt',
      );
      await File(pending.thumbnailPath!).copy(thumbnailPath);
    } else if (EvidenceStorageShared.isImageExtension(extension)) {
      thumbnailPath = storedPath;
    }

    final record = EvidenceStorageShared.recordFromPending(
      pending,
      filePath: storedPath,
      thumbnail: thumbnailPath,
    );

    final records = await _readAll();
    records.add(record);
    await _writeAll(records);

    return record;
  }

  static Future<void> discardTempFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Best-effort cleanup.
    }
  }

  static Future<void> clearAll() async {
    await _ensureInitialized();
    if (_evidenceDir != null && await _evidenceDir!.exists()) {
      await _evidenceDir!.delete(recursive: true);
      await _evidenceDir!.create(recursive: true);
    }
    await _indexFile!.writeAsString('[]');
  }

  static Future<void> clearTrustPackageExports() async {
    final appDir = await getApplicationDocumentsDirectory();
    final exportsDir = Directory(p.join(appDir.path, 'trust_package_exports'));
    if (await exportsDir.exists()) {
      await exportsDir.delete(recursive: true);
    }
  }

  static Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await init();
    }
  }

  static Future<List<EvidenceRecord>> _readAll() async {
    await _ensureInitialized();
    final contents = await _indexFile!.readAsString();
    if (contents.trim().isEmpty) {
      return [];
    }

    final decoded = jsonDecode(contents) as List<dynamic>;
    return decoded
        .map(
          (item) => EvidenceRecord.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  static Future<void> _writeAll(List<EvidenceRecord> records) async {
    await _ensureInitialized();
    final encoded = jsonEncode(records.map((record) => record.toJson()).toList());
    await _indexFile!.writeAsString(encoded);
  }
}
