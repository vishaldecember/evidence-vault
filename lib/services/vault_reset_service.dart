import 'investigation_data_deletion_service.dart';
import 'user_session_service.dart';

/// Clears every investigation while preserving the signed-in account.
class VaultResetService {
  const VaultResetService({
    this.investigationDataDeletionService =
        const InvestigationDataDeletionService(),
  });

  final InvestigationDataDeletionService investigationDataDeletionService;

  static bool vaultWasCleared = false;

  Future<void> clearVault() async {
    final accountBeforeReset = UserSessionService.account;
    await investigationDataDeletionService.deleteAllInvestigationData();
    if (UserSessionService.account == null && accountBeforeReset != null) {
      UserSessionService.establishSession(
        email: accountBeforeReset.email,
        name: accountBeforeReset.name,
        userId: accountBeforeReset.userId,
      );
    }
    vaultWasCleared = true;
  }

  static void acknowledgeVaultCleared() {
    vaultWasCleared = false;
  }

  static void resetForTests() {
    vaultWasCleared = false;
  }
}
