import 'package:flutter/material.dart';

import '../constants/app_spacing.dart';
import '../navigation/auth_navigation.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/auth_form_helpers.dart';
import '../utils/auth_validators.dart';
import '../widgets/auth/auth_button.dart';
import '../widgets/auth/auth_feedback.dart';
import '../widgets/auth/auth_header.dart';
import '../widgets/auth/auth_text_field.dart';
import '../widgets/common/app_back_button.dart';
import '../widgets/ev_premium_card.dart';
import 'login_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailFocus = FocusNode();

  String _email = '';
  bool _isLoading = false;
  bool _emailSent = false;

  @override
  void dispose() {
    _emailFocus.dispose();
    super.dispose();
  }

  Future<void> _handleSendResetLink() async {
    AuthFormHelpers.dismissKeyboard(context);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isLoading = true;
      _emailSent = false;
    });

    try {
      await AuthService.sendPasswordResetEmail(email: _email.trim());

      if (!mounted) return;
      setState(() => _emailSent = true);
      AuthFeedback.showSuccess(
        context,
        'Password reset email sent.\nCheck your inbox.',
      );

      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      AuthNavigation.replace(context, const LoginScreen());
    } catch (error) {
      if (!mounted) return;
      AuthFormHelpers.handleAuthError(
        context,
        error,
        onRetry: _handleSendResetLink,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: AppBackButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: GestureDetector(
          onTap: () => AuthFormHelpers.dismissKeyboard(context),
          behavior: HitTestBehavior.translucent,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
              final keyboardVisible = bottomInset > 0;

              return SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: AppSpacing.screenHorizontal,
                  right: AppSpacing.screenHorizontal,
                  bottom: bottomInset,
                ),
                physics: keyboardVisible
                    ? const ClampingScrollPhysics()
                    : const NeverScrollableScrollPhysics(),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: AbsorbPointer(
                    absorbing: _isLoading,
                    child: Form(
                      key: _formKey,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const AuthHeader(
                                compact: true,
                                title: 'Reset your password',
                                description:
                                    'Enter your email and we\'ll send you a secure reset link.',
                                showBrandName: false,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              EVPremiumCard(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md,
                                  vertical: AppSpacing.md,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      'Forgot password',
                                      style: AppTextStyles.screenTitle.copyWith(
                                        fontSize: 22,
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.xxs),
                                    Text(
                                      'We\'ll email instructions to regain access to your vault.',
                                      style: AppTextStyles.caption,
                                    ),
                                    const SizedBox(height: AppSpacing.sm),
                                    AuthTextField(
                                      label: 'Email address',
                                      hint: 'john@email.com',
                                      icon: Icons.email_outlined,
                                      keyboardType: TextInputType.emailAddress,
                                      textInputAction: TextInputAction.done,
                                      validator: AuthValidators.email,
                                      focusNode: _emailFocus,
                                      enabled: !_isLoading,
                                      onChanged: (value) => _email = value,
                                      onFieldSubmitted: (_) =>
                                          _handleSendResetLink(),
                                    ),
                                    if (_emailSent) ...[
                                      const SizedBox(height: AppSpacing.md),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(
                                          AppSpacing.md,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.surfaceMuted,
                                          borderRadius: BorderRadius.circular(
                                            AppSpacing.fieldRadius,
                                          ),
                                          border: Border.all(
                                            color: AppColors.border,
                                          ),
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Icon(
                                              Icons.mark_email_read_outlined,
                                              color: AppColors.success,
                                              size: 20,
                                            ),
                                            const SizedBox(width: AppSpacing.sm),
                                            Expanded(
                                              child: Text(
                                                'Password reset email sent.\nCheck your inbox.',
                                                style: AppTextStyles.caption
                                                    .copyWith(
                                                  color: AppColors.textPrimary,
                                                  height: 1.4,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: AppSpacing.sm),
                                    AuthButton(
                                      text: 'Send Reset Link',
                                      isLoading: _isLoading,
                                      onPressed: _isLoading
                                          ? null
                                          : _handleSendResetLink,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
