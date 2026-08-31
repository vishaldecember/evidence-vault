import 'package:flutter/material.dart';

import '../constants/app_spacing.dart';
import '../services/account_deletion_service.dart';
import '../services/auth_service.dart';
import '../services/vault_reset_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/privacy/re_authentication_dialog.dart';
import '../widgets/privacy/typed_confirmation_dialog.dart';
import '../widgets/privacy/vault_cleared_dialog.dart';

class PrivacyDataScreen extends StatefulWidget {
  const PrivacyDataScreen({super.key});

  @override
  State<PrivacyDataScreen> createState() => _PrivacyDataScreenState();
}

class _PrivacyDataScreenState extends State<PrivacyDataScreen> {
  bool _busy = false;

  Future<void> _handleClearVault() async {
    final confirmed = await TypedConfirmationDialog.show(
      context,
      title: 'Clear your Vault?',
      body: 'This permanently removes every investigation from your vault.\n'
          'Your account and settings remain.\n'
          'This action cannot be undone.',
      confirmationWord: 'CLEAR',
      confirmLabel: 'Clear Vault',
    );
    if (!confirmed || !mounted) {
      return;
    }

    setState(() => _busy = true);
    try {
      await const VaultResetService().clearVault();
      if (!mounted) {
        return;
      }
      await VaultClearedDialog.show(context);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to clear vault: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _handleDeleteAccount() async {
    final confirmed = await TypedConfirmationDialog.show(
      context,
      title: 'Delete your account?',
      body: 'Deleting your account permanently removes:\n'
          '• Account\n'
          '• All Incidents\n'
          '• Evidence\n'
          '• Relationship Groups\n'
          '• Timeline Anchors\n'
          '• Reconstruction\n'
          '• Trust Packages\n'
          '• Cloud Backups\n\n'
          'This action cannot be undone.',
      confirmationWord: 'DELETE',
      confirmLabel: 'Delete Account',
    );
    if (!confirmed || !mounted) {
      return;
    }

    final reauthenticated = await ReAuthenticationDialog.show(context);
    if (!reauthenticated || !mounted) {
      return;
    }

    setState(() => _busy = true);
    try {
      await const AccountDeletionService().deleteAccount();
      await AuthService.signOut();
      // AuthGate returns to the authentication entry when session clears.
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to delete account: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text('Privacy & Data', style: AppTextStyles.screenTitle),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenHorizontal,
            vertical: AppSpacing.lg,
          ),
          children: [
            Text(
              'Control how your investigation data is stored and removed.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _PrivacyActionTile(
              icon: Icons.inventory_2_outlined,
              title: 'Clear Vault',
              subtitle:
                  'Delete every investigation while keeping your account.',
              enabled: !_busy,
              onTap: _handleClearVault,
            ),
            const SizedBox(height: AppSpacing.sm),
            _PrivacyActionTile(
              icon: Icons.delete_forever_outlined,
              title: 'Delete Account',
              subtitle:
                  'Permanently remove your account and all investigation data.',
              enabled: !_busy,
              destructive: true,
              onTap: _handleDeleteAccount,
            ),
          ],
        ),
      ),
    );
  }
}

class _PrivacyActionTile extends StatelessWidget {
  const _PrivacyActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.enabled,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool enabled;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final accent = destructive ? AppColors.danger : AppColors.navy;
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.cardPadding),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Icon(icon, color: accent),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.label.copyWith(
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      subtitle,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: accent),
            ],
          ),
        ),
      ),
    );
  }
}
