import 'package:flutter/material.dart';

import 'diagnostics/release_logging.dart';
import 'diagnostics/sprint6c_file_trace.dart';
import 'navigation/app_navigator.dart';
import 'services/evidence_storage_service.dart';
import 'services/auth/authentication_service.dart';
import 'services/auth/firebase_bootstrap.dart';
import 'services/storage/file_attach_recovery.dart';
import 'providers/authentication_state_provider.dart';

import 'theme/app_theme.dart';

import 'widgets/auth/auth_gate.dart';
import 'widgets/evidence_inspector/pdf_document_surface.dart';
import 'widgets/evidence_inspector/pdf_native_viewer.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  installReleaseLogRedaction();
  PdfDocumentSurface.nativeBuilder = buildNativePdfViewer;

  await EvidenceStorageService.init();

  await FirebaseBootstrap.initialize();

  final authState = AuthenticationStateProvider();
  AuthenticationService.configure(stateProvider: authState);

  sprint6cLifecycleProbe.attach();
  FileAttachRecovery.install();
  Sprint6cFileTrace.session('app starting');

  runApp(EvidenceVaultApp(authState: authState));
}

class EvidenceVaultApp extends StatelessWidget {
  const EvidenceVaultApp({
    super.key,
    required this.authState,
  });

  final AuthenticationStateProvider authState;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My Truth',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      navigatorKey: appNavigatorKey,
      navigatorObservers: [sprint6cNavObserver],
      home: AuthGate(authState: authState),
    );
  }
}
