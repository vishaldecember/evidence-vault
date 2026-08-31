import 'package:evidence_vault/main.dart';
import 'package:evidence_vault/providers/authentication_state_provider.dart';
import 'package:evidence_vault/services/user_session_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_auth_repository.dart';

/// Pumps [EvidenceVaultApp] for widget tests without Firebase.
Future<void> pumpEvidenceVaultApp(WidgetTester tester) async {
  UserSessionService.resetForTests();

  final authState = AuthenticationStateProvider(
    authRepository: FakeAuthRepository(),
  );

  await tester.binding.setSurfaceSize(const Size(412, 915));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(EvidenceVaultApp(authState: authState));
  await tester.pumpAndSettle();
}
