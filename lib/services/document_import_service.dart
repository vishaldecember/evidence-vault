import 'dart:io';

import 'package:file_picker/file_picker.dart';

import '../diagnostics/file_p0_trace.dart';
import '../diagnostics/sprint6c_file_trace.dart';

/// Imports a user-selected document through the platform document picker.
///
/// On Android this uses the Storage Access Framework (no READ_EXTERNAL_STORAGE /
/// READ_MEDIA_* grant required). On iOS it uses the system document picker.
/// Returns null when the user cancels or no readable path is available.
///
/// Large files: [withData] is always false so the platform returns a path/URI
/// instead of loading the entire document into memory. Size is measured via
/// [File.length] only — never [File.readAsBytes].
///
/// Uses [FileType.any] on purpose: OEM SAF implementations (e.g. Moto) often
/// mishandle [FileType.custom] + [allowedExtensions], returning cancel/null
/// after the user clearly selected a PDF.
abstract final class DocumentImportService {
  static Future<String?> importDocument() async {
    FileP0Trace.step(
      'SAF_PICK_FILES_START',
      extra: 'type=any withData=false allowMultiple=false',
    );
    Sprint6cFileTrace.file('picker OPENING');
    late final FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        // Critical for large policy PDFs — path only, never full bytes.
        withData: false,
      );
    } catch (error, stack) {
      FileP0Trace.failure(
        'SAF_PICK_FILES_EXCEPTION',
        error: error,
        stackTrace: stack,
      );
      rethrow;
    }

    // User cancelled the system picker.
    if (result == null || result.files.isEmpty) {
      FileP0Trace.step(
        'SAF_PICK_FILES_RETURN',
        result: 'CANCEL_OR_EMPTY',
        extra: 'resultNull=${result == null}',
      );
      Sprint6cFileTrace.file('picker RETURNED cancel/empty');
      return null;
    }

    final platformFile = result.files.single;
    final path = platformFile.path;
    FileP0Trace.step(
      'SAF_PICK_FILES_RETURN',
      result: 'PLATFORM_FILE',
      fileName: platformFile.name,
      fileSize: platformFile.size,
      path: path,
      extra: 'pathNull=${path == null} extension=${platformFile.extension}',
    );
    if (path == null) {
      FileP0Trace.failure(
        'FILE_URI_UNRESOLVED',
        fileName: platformFile.name,
        fileSize: platformFile.size,
        extra: 'path=null',
      );
      Sprint6cFileTrace.file(
        'picker RETURNED path=null name=${platformFile.name} '
        'size=${platformFile.size}',
      );
      return null;
    }

    final file = File(path);
    if (!await file.exists()) {
      FileP0Trace.failure(
        'FILE_PATH_MISSING',
        fileName: platformFile.name,
        fileSize: platformFile.size,
        path: path,
      );
      Sprint6cFileTrace.file('picker RETURNED missing file path=$path');
      return null;
    }

    // Metadata size only — do not read file contents here.
    final bytes = await file.length();
    FileP0Trace.step(
      'FILE_METADATA',
      result: 'OK',
      fileName: platformFile.name,
      fileSize: bytes,
      path: path,
      extra: 'platformSize=${platformFile.size}',
    );
    Sprint6cFileTrace.file(
      'picker RETURNED success bytes=$bytes '
      'ext=${path.contains('.') ? path.split('.').last : '?'}',
    );
    return path;
  }
}
