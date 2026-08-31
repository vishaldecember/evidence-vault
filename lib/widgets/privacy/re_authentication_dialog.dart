import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../services/auth_service.dart';
import '../../services/re_authentication_service.dart';
import '../../services/user_session_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/auth_validators.dart';

class ReAuthenticationDialog extends StatefulWidget {
  const ReAuthenticationDialog({super.key});

  static Future<bool> show(BuildContext context) async {
    final result = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: AppColors.navy.withValues(alpha: 0.28),
      transitionDuration: AppMotion.page,
      pageBuilder: (context, animation, secondaryAnimation) {
        return const Center(child: ReAuthenticationDialog());
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: AppMotion.enter,
          reverseCurve: AppMotion.exit,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.98, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
    return result ?? false;
  }

  @override
  State<ReAuthenticationDialog> createState() => _ReAuthenticationDialogState();
}

class _ReAuthenticationDialogState extends State<ReAuthenticationDialog> {
  final _passwordController = TextEditingController();
  bool _busy = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  bool _biometricsAvailable = false;

  @override
  void initState() {
    super.initState();
    _loadBiometricAvailability();
  }

  Future<void> _loadBiometricAvailability() async {
    final available = await ReAuthenticationService.canUseBiometrics();
    if (mounted) {
      setState(() => _biometricsAvailable = available);
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _confirmWithPassword() async {
    final password = _passwordController.text;
    if (AuthValidators.signInPassword(password) != null) {
      setState(() => _errorMessage = 'Enter your current password to continue.');
      return;
    }

    await _runReauthentication(password: password);
  }

  Future<void> _confirmWithBiometrics() async {
    await _runReauthentication();
  }

  Future<void> _runReauthentication({String? password}) async {
    setState(() {
      _busy = true;
      _errorMessage = null;
    });

    try {
      await ReAuthenticationService.reauthenticate(password: password);
      if (mounted) {
        Navigator.pop(context, true);
      }
    } on ReAuthenticationException catch (error) {
      if (password == null && _biometricsAvailable) {
        setState(() {
          _errorMessage =
              'Biometric confirmation failed. Enter your password instead.';
        });
      } else {
        setState(() => _errorMessage = error.message);
      }
    } on AuthException catch (error) {
      setState(() => _errorMessage = AuthService.messageFor(error));
    } catch (_) {
      setState(
        () => _errorMessage = 'Unable to verify your identity. Try again.',
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = UserSessionService.account?.email ?? 'your account';

    return AlertDialog(
      backgroundColor: AppColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      title: const Text('Confirm your identity', style: AppTextStyles.heading),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Re-authenticate as $email before permanently deleting your account.',
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          if (_biometricsAvailable) ...[
            OutlinedButton.icon(
              onPressed: _busy ? null : _confirmWithBiometrics,
              icon: const Icon(Icons.fingerprint_rounded),
              label: const Text('Use biometrics'),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Or enter your password',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          TextField(
            controller: _passwordController,
            enabled: !_busy,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Password',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _errorMessage!,
              style: AppTextStyles.caption.copyWith(color: AppColors.danger),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel', style: AppTextStyles.link),
        ),
        FilledButton(
          onPressed: _busy ? null : _confirmWithPassword,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Confirm'),
        ),
      ],
    );
  }
}
