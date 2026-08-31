import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../controllers/workspace_session.dart';
import '../services/storage/file_attach_flow.dart';
import '../services/user_session_service.dart';
import 'file_p0_trace.dart';

/// Temporary Sprint 6C Task 6C diagnostics — do not use for product logic.
///
/// Filter logcat / console with: FILE6C | AUTH6C | NAV6C | WORKSPACE6C |
/// SESSION6C | LIFECYCLE6C | FILEP0
abstract final class Sprint6cFileTrace {
  static void file(String message) => _log('FILE6C', message);

  static void auth(String message) => _log('AUTH6C', message);

  static void nav(String message) => _log('NAV6C', message);

  static void workspace(String message) => _log('WORKSPACE6C', message);

  static void session(String message) => _log('SESSION6C', message);

  static void lifecycle(String message) => _log('LIFECYCLE6C', message);

  static String snapshot() {
    final session = WorkspaceSession.instance;
    final account = UserSessionService.account;
    return 'incident=${session.controller.currentIncident.id} '
        'evidenceCount=${session.controller.currentIncident.evidenceCount} '
        'localSignedIn=${UserSessionService.isSignedIn} '
        'uid=${account?.userId ?? 'none'} '
        'restored=${session.isCloudRestored} '
        'restoring=${session.isRestoring}';
  }

  static void _log(String prefix, String message) {
    // Temporary Task 6C: always emit so real-device logcat works in debug/profile.
    final ts = DateTime.now().toIso8601String();
    debugPrint('[$prefix] $ts | $message | ${snapshot()}');
  }
}

/// Logs every root-navigator push/pop/replace — proves whether Home appears
/// because ContinuousCapture was popped vs AuthGate remount.
class Sprint6cNavObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    Sprint6cFileTrace.nav(
      'didPush route=${_name(route)} previous=${_name(previousRoute)} '
      'stackHint=push',
    );
    FileP0Trace.step(
      'NAV_PUSH',
      extra:
          'route=${_name(route)} previous=${_name(previousRoute)} '
          'attachInProgress=${FileAttachFlow.attachInProgress}',
    );
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    Sprint6cFileTrace.nav(
      'didPop route=${_name(route)} previous=${_name(previousRoute)} '
      '← THIS MAY SURFACE HOME if Workspace was popped',
    );
    FileP0Trace.step(
      'NAV_POP',
      result: 'MAY_SURFACE_HOME',
      extra:
          'route=${_name(route)} previous=${_name(previousRoute)} '
          'attachInProgress=${FileAttachFlow.attachInProgress}',
    );
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    Sprint6cFileTrace.nav(
      'didRemove route=${_name(route)} previous=${_name(previousRoute)}',
    );
    FileP0Trace.step(
      'NAV_REMOVE',
      extra: 'route=${_name(route)} previous=${_name(previousRoute)}',
    );
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    Sprint6cFileTrace.nav(
      'didReplace new=${_name(newRoute)} old=${_name(oldRoute)}',
    );
    FileP0Trace.step(
      'NAV_REPLACE',
      extra: 'new=${_name(newRoute)} old=${_name(oldRoute)}',
    );
  }

  static String _name(Route<dynamic>? route) {
    if (route == null) {
      return 'null';
    }
    return route.settings.name ?? route.runtimeType.toString();
  }
}

/// App-wide lifecycle probe for SAF / file-picker interruption.
class Sprint6cLifecycleProbe with WidgetsBindingObserver {
  bool _attached = false;

  void attach() {
    if (_attached) {
      return;
    }
    WidgetsBinding.instance.addObserver(this);
    _attached = true;
    Sprint6cFileTrace.lifecycle('probe attached');
  }

  void detach() {
    if (!_attached) {
      return;
    }
    WidgetsBinding.instance.removeObserver(this);
    _attached = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    Sprint6cFileTrace.lifecycle('AppLifecycleState.$state');
    FileP0Trace.step(
      'LIFECYCLE',
      result: state.name,
      extra: 'attachInProgress=${FileAttachFlow.attachInProgress}',
    );
  }
}

final sprint6cLifecycleProbe = Sprint6cLifecycleProbe();
final sprint6cNavObserver = Sprint6cNavObserver();

/// Schedule a post-frame route dump (names only).
void sprint6cDumpRoutes(BuildContext? context, String reason) {
  SchedulerBinding.instance.addPostFrameCallback((_) {
    if (context == null || !context.mounted) {
      Sprint6cFileTrace.nav('dumpRoutes($reason) context unmounted');
      FileP0Trace.step('ROUTE_DUMP', result: 'UNMOUNTED', extra: reason);
      return;
    }
    final nav = Navigator.maybeOf(context);
    Sprint6cFileTrace.nav(
      'dumpRoutes($reason) canPop=${nav?.canPop()}',
    );
    FileP0Trace.step(
      'ROUTE_DUMP',
      mounted: true,
      extra: 'reason=$reason canPop=${nav?.canPop()}',
    );
  });
}
