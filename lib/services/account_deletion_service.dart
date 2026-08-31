import 'investigation_data_deletion_service.dart';
import 'auth/authentication_service.dart';
import 'user_session_service.dart';

/// Permanently deletes the signed-in account and all investigation data.
class AccountDeletionService {
  const AccountDeletionService({
    this.investigationDataDeletionService =
        const InvestigationDataDeletionService(),
  });

  final InvestigationDataDeletionService investigationDataDeletionService;

  Future<void> deleteAccount() async {
    await investigationDataDeletionService.deleteAllInvestigationData();

    try {
      await AuthenticationService.instance.deleteFirebaseAccount();
    } catch (_) {
      // Local investigation data is cleared; Firebase deletion retried on next sign-in flow.
    }

    UserSessionService.deleteAccount();
  }
}
