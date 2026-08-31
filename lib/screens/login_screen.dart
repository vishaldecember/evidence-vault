import 'package:flutter/material.dart';

import '../constants/app_spacing.dart';
import '../navigation/auth_navigation.dart';
import '../presentation/trust_security_copy.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/auth_form_helpers.dart';
import '../utils/auth_validators.dart';
import '../widgets/auth/auth_button.dart';
import '../widgets/auth/auth_feedback.dart';
import '../widgets/auth/auth_footer.dart';
import '../widgets/auth/auth_header.dart';
import '../widgets/auth/auth_text_field.dart';
import '../widgets/common/app_back_button.dart';
import '../widgets/ev_password_field.dart';
import '../widgets/ev_premium_card.dart';
import 'create_account_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  String _email = '';
  String _password = '';
  bool _isLoading = false;

  @override
  void dispose() {
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    AuthFormHelpers.dismissKeyboard(context);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);

    try {
      await AuthService.signIn(
        email: _email.trim(),
        password: _password,
      );

      if (!mounted) return;
      AuthFeedback.showSuccess(
        context,
        'Signed in successfully. Welcome back.',
      );
    } catch (error) {
      if (!mounted) return;
      AuthFormHelpers.handleAuthError(
        context,
        error,
        onRetry: _handleSignIn,
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

              return SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: AppSpacing.screenHorizontal,
                  right: AppSpacing.screenHorizontal,
                  bottom: bottomInset > 0
                      ? bottomInset + AppSpacing.xl
                      : AppSpacing.md,
                ),
                physics: const ClampingScrollPhysics(),
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
                                title: 'Welcome back',
                                description:
                                    'Sign in to access your secure vault and trusted timelines.',
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
                                      'Sign in',
                                      style: AppTextStyles.screenTitle.copyWith(
                                        fontSize: 22,
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.xxs),
                                    Text(
                                      TrustSecurityCopy.loginPrivacyCaption,
                                      style: AppTextStyles.caption,
                                    ),
                                    const SizedBox(height: AppSpacing.sm),
                                    AuthTextField(
                                      label: 'Email address',
                                      hint: 'john@email.com',
                                      icon: Icons.email_outlined,
                                      keyboardType: TextInputType.emailAddress,
                                      textInputAction: TextInputAction.next,
                                      validator: AuthValidators.email,
                                      focusNode: _emailFocus,
                                      enabled: !_isLoading,
                                      onChanged: (value) => _email = value,
                                      onFieldSubmitted: (_) =>
                                          _passwordFocus.requestFocus(),
                                    ),
                                    const SizedBox(height: AppSpacing.sm),
                                    EVPasswordField(
                                      label: 'Password',
                                      hint: 'Enter your password',
                                      textInputAction: TextInputAction.done,
                                      validator: AuthValidators.signInPassword,
                                      focusNode: _passwordFocus,
                                      enabled: !_isLoading,
                                      onChanged: (value) => _password = value,
                                      onFieldSubmitted: (_) => _handleSignIn(),
                                    ),
                                    const SizedBox(height: AppSpacing.sm),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton(
                                        onPressed: _isLoading
                                            ? null
                                            : () =>
                                                AuthNavigation.openForgotPassword(
                                                  context,
                                                ),
                                        style: TextButton.styleFrom(
                                          foregroundColor: AppColors.primary,
                                        ),
                                        child: Text(
                                          'Forgot Password?',
                                          style: AppTextStyles.link
                                              .copyWith(fontSize: 14),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.sm),
                                    AuthButton(
                                      text: 'Sign In',
                                      isLoading: _isLoading,
                                      onPressed:
                                          _isLoading ? null : _handleSignIn,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: AppSpacing.sm),
                              AuthFooter(
                                promptText: "Don't have an account?",
                                actionText: 'Create Vault',
                                onActionTap: _isLoading
                                    ? () {}
                                    : () => AuthNavigation.replace(
                                          context,
                                          const CreateAccountScreen(),
                                        ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                            ],
                          ),
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
