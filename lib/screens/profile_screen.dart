import 'package:flutter/material.dart';

import '../constants/app_spacing.dart';
import '../navigation/auth_navigation.dart';
import '../screens/privacy_data_screen.dart';
import '../services/auth_service.dart';
import '../services/user_session_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/auth/auth_button.dart';
import '../widgets/common/layered_card.dart';
import '../widgets/common/silver_lustre_text.dart';
import '../widgets/auth/auth_feedback.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isSigningOut = false;

  Future<void> _handleSignOut() async {
    if (_isSigningOut) return;

    setState(() => _isSigningOut = true);
    try {
      await AuthService.signOut();
      // AuthGate returns to SplashScreen when session clears.
    } catch (error) {
      if (!mounted) return;
      final message = error is AuthException
          ? AuthService.messageFor(error)
          : 'Unable to sign out. Please try again.';
      AuthFeedback.showError(context, message);
    } finally {
      if (mounted) setState(() => _isSigningOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = UserSessionService.account;
    final displayName = account?.name.trim().isNotEmpty == true
        ? account!.name
        : 'Investigator';
    final email = account?.email ?? '';

    return ColoredBox(
      color: Colors.transparent,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenHorizontal,
            vertical: AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Profile',
                style: AppTextStyles.pageTitle.copyWith(
                  fontSize: 28,
                  color: AppColors.onCanvas,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              SilverLustreText(
                'Account settings and privacy controls.',
                style: AppTextStyles.body,
              ),
              const SizedBox(height: AppSpacing.lg),
              _SettingsSection(
                title: 'Settings',
                children: [
                  _SettingsTile(
                    icon: Icons.shield_outlined,
                    title: 'Privacy & Data',
                    subtitle: 'Clear Vault and Delete Account',
                    onTap: () {
                      AuthNavigation.push(context, const PrivacyDataScreen());
                    },
                  ),
                ],
              ),
              const Spacer(),
              LayeredCard(
                elevated: true,
                padding: const EdgeInsets.all(AppSpacing.cardPadding),
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Icon(
                        Icons.person_outline,
                        size: 36,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      displayName,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.navy,
                      ),
                    ),
                    if (email.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        email,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AuthButton(
                text: 'Sign Out',
                isLoading: _isSigningOut,
                onPressed: _handleSignOut,
                color: AppColors.primary,
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SilverLustreText(
          title,
          style: AppTextStyles.label.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        ...children,
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return LayeredCard(
      elevated: true,
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTextStyles.bodySmall),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right,
            color: AppColors.textSecondary,
          ),
        ],
      ),
    );
  }
}
