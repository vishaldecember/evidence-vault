import 'package:flutter/material.dart';
import '../constants/app_spacing.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/auth_validators.dart';
import '../widgets/auth/auth_header.dart';
import '../widgets/auth/password_strength_indicator.dart';
import '../widgets/auth/social_login_section.dart';
import '../widgets/auth/terms_checkbox.dart';
import '../widgets/ev_button.dart';
import '../widgets/ev_password_field.dart';
import '../widgets/ev_premium_card.dart';
import '../widgets/ev_text_field.dart';

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _formKey = GlobalKey<FormState>();

  String _password = '';
  bool _termsAccepted = false;
  bool _showTermsError = false;

  void _handleContinue() {
    final isFormValid = _formKey.currentState?.validate() ?? false;
    final isTermsValid = _termsAccepted;

    setState(() => _showTermsError = !isTermsValid);

    if (isFormValid && isTermsValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Account details validated successfully.',
            style: AppTextStyles.label.copyWith(color: AppColors.onPrimary),
          ),
          backgroundColor: AppColors.navy,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.sm),
          ),
        ),
      );
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
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: AppColors.navy,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenHorizontal,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const AuthHeader(
                          title: 'Create your secure vault',
                          description:
                              'Organize life\'s moments into trusted timelines and professional reports — protected, private, and always yours.',
                          showBrandName: false,
                        ),
                        const SizedBox(height: AppSpacing.xxxl),
                        EVPremiumCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Account details',
                                style: AppTextStyles.screenTitle.copyWith(
                                  fontSize: 22,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                'Your information is encrypted and never shared.',
                                style: AppTextStyles.caption,
                              ),
                              const SizedBox(height: AppSpacing.xxl),
                              EVTextField(
                                label: 'Full name',
                                hint: 'John Smith',
                                icon: Icons.person_outline_rounded,
                                textInputAction: TextInputAction.next,
                                validator: AuthValidators.name,
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              EVTextField(
                                label: 'Email address',
                                hint: 'john@email.com',
                                icon: Icons.email_outlined,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                validator: AuthValidators.email,
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              EVPasswordField(
                                label: 'Password',
                                hint: 'Create a strong password',
                                textInputAction: TextInputAction.next,
                                validator: AuthValidators.password,
                                onChanged: (value) {
                                  setState(() => _password = value);
                                  _formKey.currentState?.validate();
                                },
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              PasswordStrengthIndicator(password: _password),
                              const SizedBox(height: AppSpacing.lg),
                              EVPasswordField(
                                label: 'Confirm password',
                                hint: 'Re-enter your password',
                                textInputAction: TextInputAction.done,
                                validator: (value) => AuthValidators
                                    .confirmPassword(value, _password),
                              ),
                              const SizedBox(height: AppSpacing.xl),
                              TermsCheckbox(
                                value: _termsAccepted,
                                onChanged: (accepted) => setState(() {
                                  _termsAccepted = accepted ?? false;
                                  if (_termsAccepted) {
                                    _showTermsError = false;
                                  }
                                }),
                                onTermsTap: () {},
                              ),
                              if (_showTermsError) ...[
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  'Please accept the Terms & Conditions',
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.danger,
                                  ),
                                ),
                              ],
                              const SizedBox(height: AppSpacing.xl),
                              EVButton(
                                text: 'Continue',
                                onPressed: _handleContinue,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                        const SocialLoginSection(),
                        const SizedBox(height: AppSpacing.xxl),
                        _SignInPrompt(
                          onSignInTap: () {},
                        ),
                        const SizedBox(height: AppSpacing.xl),
                      ],
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

class _SignInPrompt extends StatelessWidget {
  final VoidCallback onSignInTap;

  const _SignInPrompt({required this.onSignInTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Already have an account?', style: AppTextStyles.signInPrompt),
        TextButton(
          onPressed: onSignInTap,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          ),
          child: Text('Sign In', style: AppTextStyles.link),
        ),
      ],
    );
  }
}
