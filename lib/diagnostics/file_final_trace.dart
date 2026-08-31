import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../controllers/workspace_session.dart';
import '../navigation/app_navigator.dart';
import '../services/storage/file_attach_flow.dart';
import '../services/user_session_service.dart';

/// Temporary FINAL File P0 diagnostics — filter logcat: `FILEFINAL`
///
/// Also mirrors to [FILEP0] so prior capture instructions still work.
abstract final class FileFinalTrace {
  static String? entryPoint; // HOME_CAPTURE_NOW | WORKSPACE
  static String? sourceIncidentId;

  static String get _ts => DateTime.now().toIso8601String();

  static String get _incident =>
      sourceIncidentId ??
      WorkspaceSession.instance.controller.currentIncident.id;

  static String get _route {
    if (FileAttachFlow.workspaceRouteVisible) {
      return 'Workspace';
    }
    final ctx = appNavigatorKey.currentContext;
    if (ctx != null && ctx.mounted) {
      return ModalRoute.of(ctx)?.settings.name ?? 'mountedContext';
    }
    return 'noMountedContext';
  }

  static void stage(
    String step, {
    String? result,
    bool? mounted,
    String? fileName,
    String? extension,
    String? mimeType,
    int? fileSize,
    String? path,
    String? extra,
  }) {
    final parts = <String>[
      'ts=$_ts',
      'entry=${entryPoint ?? 'unknown'}',
      'incident=$_incident',
      'route=$_route',
      'attachInProgress=${FileAttachFlow.attachInProgress}',
      'pickerActive=${FileAttachFlow.pickerActive}',
      'workspaceVisible=${FileAttachFlow.workspaceRouteVisible}',
      'evidenceCount=${WorkspaceSession.instance.controller.currentIncident.evidenceCount}',
      'uid=${UserSessionService.account?.userId ?? 'none'}',
    ];
    if (mounted != null) {
      parts.add('mounted=$mounted');
    }
    if (fileName != null) {
      parts.add('fileName=$fileName');
    }
    if (extension != null) {
      parts.add('ext=$extension');
    }
    if (mimeType != null) {
      parts.add('mime=$mimeType');
    }
    if (fileSize != null) {
      parts.add('fileSize=$fileSize');
    }
    if (result != null) {
      parts.add('result=$result');
    }
    if (extra != null && extra.isNotEmpty) {
      parts.add(extra);
    }
    final line = '[FILEFINAL] STEP=$step ${parts.join(' ')}';
    debugPrint(line);
    debugPrint(line.replaceFirst('[FILEFINAL]', '[FILEP0]'));
  }

  static void failure(
    String stage, {
    Object? error,
    StackTrace? stackTrace,
    bool? mounted,
    String? fileName,
    String? extension,
    String? mimeType,
    int? fileSize,
    String? path,
    String? extra,
  }) {
    final parts = <String>[
      'ts=$_ts',
      'entry=${entryPoint ?? 'unknown'}',
      'incident=$_incident',
      'route=$_route',
      'attachInProgress=${FileAttachFlow.attachInProgress}',
      'exception=$error',
    ];
    if (mounted != null) {
      parts.add('mounted=$mounted');
    }
    if (fileName != null) {
      parts.add('fileName=$fileName');
    }
    if (extension != null) {
      parts.add('ext=$extension');
    }
    if (mimeType != null) {
      parts.add('mime=$mimeType');
    }
    if (fileSize != null) {
      parts.add('fileSize=$fileSize');
    }
    if (extra != null) {
      parts.add(extra);
    }
    final line = '[FILEFINAL] FILE_FAILURE=$stage ${parts.join(' ')}';
    debugPrint(line);
    debugPrint(line.replaceFirst('[FILEFINAL]', '[FILEP0]'));
    if (stackTrace != null) {
      debugPrint('[FILEFINAL] STACK=$stackTrace');
    } else if (error != null) {
      debugPrintStack(label: '[FILEFINAL] STACK_TRACE', stackTrace: StackTrace.current);
    }
  }

  static String extensionOf(String fileName) =>
      p.extension(fileName).replaceFirst('.', '').toLowerCase();
}
