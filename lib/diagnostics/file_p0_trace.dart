import 'package:flutter/material.dart';

import '../controllers/workspace_session.dart';
import '../navigation/app_navigator.dart';
import '../services/storage/file_attach_flow.dart';
import '../services/user_session_service.dart';

/// Temporary beta diagnostics for File attachment — filter logcat: `FILEP0`
///
/// Emits ordered STEP / FAILURE lines so device runs can identify the first
/// failing stage. Do not use for product logic.
abstract final class FileP0Trace {
  static String? lastStep;
  static String? lastFileName;
  static int? lastFileSize;
  static String? lastPath;

  static String get _ts => DateTime.now().toIso8601String();

  static String get _incident =>
      WorkspaceSession.instance.controller.currentIncident.id;

  static String get _expected =>
      FileAttachFlow.expectedIncidentId ?? 'none';

  static String get _routeHint {
    if (FileAttachFlow.workspaceRouteVisible) {
      return 'Workspace(visible=true)';
    }
    final ctx = appNavigatorKey.currentContext;
    if (ctx != null && ctx.mounted) {
      final name = ModalRoute.of(ctx)?.settings.name;
      if (name != null && name.isNotEmpty) {
        return name;
      }
      return 'mountedContext';
    }
    return 'noMountedContext';
  }

  static String _common({
    String? incidentId,
    bool? mounted,
    String? fileName,
    int? fileSize,
    String? extra,
  }) {
    final name = fileName ?? lastFileName;
    final size = fileSize ?? lastFileSize;
    final buf = StringBuffer()
      ..write('ts=$_ts')
      ..write(' incident=${incidentId ?? _incident}')
      ..write(' expectedIncident=$_expected')
      ..write(' route=$_routeHint')
      ..write(' pickerActive=${FileAttachFlow.pickerActive}')
      ..write(' attachInProgress=${FileAttachFlow.attachInProgress}')
      ..write(' workspaceVisible=${FileAttachFlow.workspaceRouteVisible}')
      ..write(
        ' evidenceCount='
        '${WorkspaceSession.instance.controller.currentIncident.evidenceCount}',
      )
      ..write(' uid=${UserSessionService.account?.userId ?? 'none'}');
    if (mounted != null) {
      buf.write(' mounted=$mounted');
    }
    if (name != null) {
      buf.write(' fileName=$name');
    }
    if (size != null) {
      buf.write(' fileSize=$size');
    }
    if (extra != null && extra.isNotEmpty) {
      buf.write(' $extra');
    }
    return buf.toString();
  }

  static void step(
    String step, {
    String? incidentId,
    bool? mounted,
    String? fileName,
    int? fileSize,
    String? path,
    String? result,
    String? extra,
  }) {
    lastStep = step;
    if (fileName != null) {
      lastFileName = fileName;
    }
    if (fileSize != null) {
      lastFileSize = fileSize;
    }
    if (path != null) {
      lastPath = path;
    }
    final resultPart = result == null ? '' : ' result=$result';
    debugPrint(
      '[FILEP0] STEP=$step$resultPart ${_common(
        incidentId: incidentId,
        mounted: mounted,
        fileName: fileName,
        fileSize: fileSize,
        extra: extra,
      )}',
    );
  }

  static void failure(
    String where, {
    Object? error,
    StackTrace? stackTrace,
    String? incidentId,
    bool? mounted,
    String? fileName,
    int? fileSize,
    String? path,
    String? extra,
  }) {
    debugPrint(
      '[FILEP0] FAILURE=$where exception=$error ${_common(
        incidentId: incidentId,
        mounted: mounted,
        fileName: fileName,
        fileSize: fileSize,
        extra: extra,
      )}',
    );
    if (stackTrace != null) {
      debugPrint('[FILEP0] STACK=$stackTrace');
    } else if (error != null) {
      debugPrintStack(
        label: '[FILEP0] STACK_TRACE',
        stackTrace: StackTrace.current,
      );
    }
  }

  static void note(String message, {String? extra}) {
    debugPrint('[FILEP0] NOTE=$message ${_common(extra: extra)}');
  }

  static void rememberMedia({
    required String fileName,
    required int fileSize,
    required String path,
  }) {
    lastFileName = fileName;
    lastFileSize = fileSize;
    lastPath = path;
  }

  static void clearMediaMemory() {
    lastFileName = null;
    lastFileSize = null;
    lastPath = null;
    lastStep = null;
  }
}
