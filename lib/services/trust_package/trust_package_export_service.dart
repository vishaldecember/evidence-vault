import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../domain/trust_package/trust_package.dart';
import '../../models/trust_package_archive_record.dart';
import '../../repositories/trust_package_archive_store.dart';
import 'trust_package_export_metadata.dart';
import 'trust_package_filename_service.dart';
import 'trust_package_pdf_renderer.dart';
import 'trust_package_serializer.dart';

/// Supported Trust Package export formats — extensible without changing domain.
enum TrustPackageExportFormat {
  pdf('PDF'),
  archive('Archive');

  const TrustPackageExportFormat(this.label);

  final String label;
}

class TrustPackageExportResult {
  const TrustPackageExportResult({
    required this.format,
    required this.fileName,
    required this.filePath,
    required this.bytes,
  });

  final TrustPackageExportFormat format;
  final String fileName;
  final String filePath;
  final Uint8List bytes;
}

/// Orchestrates Trust Package export — consumes [TrustPackage] only.
class TrustPackageExportService {
  const TrustPackageExportService({
    this._exportDirectoryProvider,
  });

  final Future<Directory> Function(TrustPackage package)?
      _exportDirectoryProvider;

  Future<TrustPackageExportResult> export(
    TrustPackage package,
    TrustPackageExportFormat format,
  ) {
    return switch (format) {
      TrustPackageExportFormat.pdf => exportPdf(package),
      TrustPackageExportFormat.archive => exportArchive(package),
    };
  }

  Future<TrustPackageExportResult> exportPdf(TrustPackage package) async {
    final bytes = await TrustPackagePdfRenderer.buildPdf(package);
    final fileName = TrustPackageFilenameService.pdf(package);
    final filePath = await _writeExportBytes(
      package: package,
      fileName: fileName,
      bytes: bytes,
    );
    return TrustPackageExportResult(
      format: TrustPackageExportFormat.pdf,
      fileName: fileName,
      filePath: filePath,
      bytes: bytes,
    );
  }

  Future<TrustPackageExportResult> exportArchive(TrustPackage package) async {
    final pdfBytes = await TrustPackagePdfRenderer.buildPdf(package);
    final manifest = _buildManifest(package, pdfBytes);
    final snapshotJson = jsonEncode(TrustPackageSerializer.toJson(package));
    final archive = Archive()
      ..addFile(
        ArchiveFile(
          'manifest.json',
          utf8.encode(jsonEncode(manifest)).length,
          utf8.encode(jsonEncode(manifest)),
        ),
      )
      ..addFile(
        ArchiveFile(
          'trust_package.json',
          utf8.encode(snapshotJson).length,
          utf8.encode(snapshotJson),
        ),
      )
      ..addFile(
        ArchiveFile(
          TrustPackageFilenameService.pdf(package),
          pdfBytes.length,
          pdfBytes,
        ),
      );

    final encoded = ZipEncoder().encode(archive);
    final bytes = Uint8List.fromList(encoded);
    final fileName = TrustPackageFilenameService.archive(package);
    final filePath = await _writeExportBytes(
      package: package,
      fileName: fileName,
      bytes: bytes,
    );

    final record = TrustPackageArchiveRecord(
      archiveId: manifest['archiveId'] as String,
      originatingIncidentId:
          TrustPackageExportMetadata.originatingIncidentId(package),
      packageVersion: package.metadata.packageVersion,
      generatedAt: package.metadata.generatedAt,
      generatedBy: package.metadata.generatedBy,
      archivedAt: DateTime.now(),
      snapshot: package,
      archiveFilePath: filePath,
    );
    TrustPackageArchiveStore.add(record);

    return TrustPackageExportResult(
      format: TrustPackageExportFormat.archive,
      fileName: fileName,
      filePath: filePath,
      bytes: bytes,
    );
  }

  Map<String, dynamic> _buildManifest(
    TrustPackage package,
    Uint8List pdfBytes,
  ) {
    final embedded = TrustPackageExportMetadata.embedded(package);
    final snapshotJson = jsonEncode(TrustPackageSerializer.toJson(package));
    return {
      'archiveId': _archiveId(package),
      'format': 'trust_package_archive_v1',
      'embeddedMetadata': embedded,
      'pdfSha256': sha256.convert(pdfBytes).toString(),
      'snapshotSha256': sha256.convert(utf8.encode(snapshotJson)).toString(),
      'archivedAt': DateTime.now().toIso8601String(),
    };
  }

  String _archiveId(TrustPackage package) {
    final incidentId = TrustPackageExportMetadata.originatingIncidentId(package);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '$incidentId@archive/$timestamp';
  }

  Future<String> _writeExportBytes({
    required TrustPackage package,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final directory = await _exportDirectory(package);
    final file = File(p.join(directory.path, fileName));
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<Directory> _exportDirectory(TrustPackage package) async {
    final provider = _exportDirectoryProvider;
    if (provider != null) {
      return provider(package);
    }

    final root = await getApplicationDocumentsDirectory();
    final incidentId =
        TrustPackageExportMetadata.originatingIncidentId(package);
    final directory = Directory(
      p.join(root.path, 'trust_package_exports', incidentId),
    );
    if (!directory.existsSync()) {
      await directory.create(recursive: true);
    }
    return directory;
  }
}
