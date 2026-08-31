import 'package:flutter/material.dart';

import '../constants/app_spacing.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/auth_form_helpers.dart';
import '../utils/auth_validators.dart';
import '../widgets/auth/auth_button.dart';
import '../widgets/auth/auth_header.dart';
import '../widgets/auth/auth_text_field.dart';
import '../widgets/auth/password_strength_widget.dart';
import '../widgets/auth/terms_checkbox.dart';
import '../widgets/common/app_back_button.dart';
import '../widgets/ev_password_field.dart';
import '../widgets/ev_premium_card.dart';

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen>
    with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();

  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmPasswordFocus = FocusNode();

  final _emailFieldKey = GlobalKey();
  final _passwordFieldKey = GlobalKey();
  final _confirmPasswordFieldKey = GlobalKey();
  final _termsAndActionsKey = GlobalKey();

  String _email = '';
  String _password = '';
  String _confirmPassword = '';
  bool _termsAccepted = false;
  bool _showTermsError = false;
  bool _isLoading = false;
  bool _scrollScheduled = false;

  static const _scrollDuration = Duration(milliseconds: 280);
  static const _scrollCurve = Curves.easeOutCubic;
  static const _fieldViewportAlignment = 0.28;
  static const _actionsViewportAlignment = 0.92;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _emailFocus.addListener(_onFocusChanged);
    _passwordFocus.addListener(_onFocusChanged);
    _confirmPasswordFocus.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _emailFocus.removeListener(_onFocusChanged);
    _passwordFocus.removeListener(_onFocusChanged);
    _confirmPasswordFocus.removeListener(_onFocusChanged);
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    _scheduleEnsureFocusedContentVisible();
  }

  void _onFocusChanged() {
    final focused = FocusManager.instance.primaryFocus;
    if (focused == null || !focused.hasFocus) return;
    if (focused != _emailFocus &&
        focused != _passwordFocus &&
        focused != _confirmPasswordFocus) {
      return;
    }
    _scheduleEnsureFocusedContentVisible();
  }

  void _scheduleEnsureFocusedContentVisible() {
    if (_scrollScheduled) return;
    _scrollScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollScheduled = false;
      _ensureFocusedContentVisible();
    });
  }

  Future<void> _ensureFocusedContentVisible() async {
    await Future<void>.delayed(const Duration(milliseconds: 320));
    if (!mounted) return;

    final focus = FocusManager.instance.primaryFocus;
    if (focus == null || !focus.hasFocus) return;

    if (focus == _confirmPasswordFocus) {
      await _scrollIntoView(
        _termsAndActionsKey,
        alignment: _actionsViewportAlignment,
      );
      return;
    }

    final fieldKey = switch (focus) {
      final node when node == _emailFocus => _emailFieldKey,
      final node when node == _passwordFocus => _passwordFieldKey,
      _ => null,
    };
    if (fieldKey == null) return;
    await _scrollIntoView(fieldKey, alignment: _fieldViewportAlignment);
  }

  Future<void> _scrollIntoView(
    GlobalKey key, {
    required double alignment,
  }) async {
    final targetContext = key.currentContext;
    if (targetContext == null || !mounted) return;

    await Scrollable.ensureVisible(
      targetContext,
      duration: _scrollDuration,
      curve: _scrollCurve,
      alignment: alignment,
      alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
    );
  }

  Future<void> _handleContinue() async {
    AuthFormHelpers.dismissKeyboard(context);

    final isFormValid = _formKey.currentState?.validate() ?? false;
    final isTermsValid = _termsAccepted;
    setState(() => _showTermsError = !isTermsValid);

    if (!isFormValid || !isTermsValid) {
      if (!isTermsValid) {
        await _scrollIntoView(
          _termsAndActionsKey,
          alignment: _actionsViewportAlignment,
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      await AuthService.register(
        email: _email.trim(),
        password: _password,
      );
      // AuthGate routes to WelcomeNameScreen when displayName is empty.
    } catch (error) {
      if (!mounted) return;
      AuthFormHelpers.handleAuthError(
        context,
        error,
        onRetry: _handleContinue,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildContinueButton() {
    return AuthButton(
      text: 'Continue',
      loadingText: 'Creating your vault...',
      isLoading: _isLoading,
      onPressed: _isLoading ? null : _handleContinue,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final keyboardVisible = bottomInset > 0;

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
          child: Column(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      controller: _scrollController,
                      physics: const ClampingScrollPhysics(),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.screenHorizontal,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: AbsorbPointer(
                          absorbing: _isLoading,
                          child: Form(
                            key: _formKey,
                            autovalidateMode:
                                AutovalidateMode.onUserInteraction,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const AuthHeader(
                                  onboarding: true,
                                  compact: true,
                                  title: 'Create your vault',
                                  description: 'Capture. Organize. Protect.',
                                  showBrandName: false,
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                EVPremiumCard(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.md,
                                    vertical: AppSpacing.sm + 2,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Text(
                                        'Account',
                                        style:
                                            AppTextStyles.screenTitle.copyWith(
                                          fontSize: 20,
                                        ),
                                      ),
                                      const SizedBox(height: AppSpacing.sm),
                                      KeyedSubtree(
                                        key: _emailFieldKey,
                                        child: AuthTextField(
                                          label: 'Email',
                                          hint: 'you@email.com',
                                          icon: Icons.email_outlined,
                                          keyboardType:
                                              TextInputType.emailAddress,
                                          textInputAction: TextInputAction.next,
                                          validator: AuthValidators.email,
                                          focusNode: _emailFocus,
                                          enabled: !_isLoading,
                                          compact: true,
                                          onChanged: (value) => _email = value,
                                          onFieldSubmitted: (_) =>
                                              _passwordFocus.requestFocus(),
                                        ),
                                      ),
                                      const SizedBox(height: AppSpacing.sm),
                                      KeyedSubtree(
                                        key: _passwordFieldKey,
                                        child: EVPasswordField(
                                          label: 'Password',
                                          hint: 'Create a password',
                                          textInputAction: TextInputAction.next,
                                          validator: AuthValidators.password,
                                          focusNode: _passwordFocus,
                                          enabled: !_isLoading,
                                          compact: true,
                                          onChanged: (value) {
                                            setState(() => _password = value);
                                          },
                                          onFieldSubmitted: (_) =>
                                              _confirmPasswordFocus
                                                  .requestFocus(),
                                        ),
                                      ),
                                      PasswordStrengthWidget(
                                        password: _password,
                                        confirmPassword: _confirmPassword,
                                      ),
                                      const SizedBox(height: AppSpacing.sm),
                                      KeyedSubtree(
                                        key: _confirmPasswordFieldKey,
                                        child: EVPasswordField(
                                          label: 'Confirm password',
                                          hint: 'Re-enter password',
                                          textInputAction: TextInputAction.done,
                                          validator: (value) =>
                                              AuthValidators.confirmPassword(
                                            value,
                                            _password,
                                          ),
                                          focusNode: _confirmPasswordFocus,
                                          enabled: !_isLoading,
                                          compact: true,
                                          onChanged: (value) {
                                            setState(
                                              () => _confirmPassword = value,
                                            );
                                          },
                                          onFieldSubmitted: (_) =>
                                              FocusScope.of(context).unfocus(),
                                        ),
                                      ),
                                      KeyedSubtree(
                                        key: _termsAndActionsKey,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            const SizedBox(height: AppSpacing.xs),
                                            TermsCheckbox(
                                              value: _termsAccepted,
                                              onChanged: (accepted) {
                                                if (_isLoading) return;
                                                setState(() {
                                                  _termsAccepted =
                                                      accepted ?? false;
                                                  if (_termsAccepted) {
                                                    _showTermsError = false;
                                                  }
                                                });
                                              },
                                              onTermsTap: () {},
                                              onPrivacyTap: () {},
                                            ),
                                            if (_showTermsError)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  top: AppSpacing.xxs,
                                                ),
                                                child: Text(
                                                  'Please accept the Terms and Privacy Policy',
                                                  style: AppTextStyles.caption
                                                      .copyWith(
                                                    color: AppColors.danger,
                                                  ),
                                                ),
                                              ),
                                            if (!keyboardVisible) ...[
                                              const SizedBox(
                                                height: AppSpacing.sm,
                                              ),
                                              _buildContinueButton(),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
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
              if (keyboardVisible)
                Material(
                  color: AppColors.background,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenHorizontal,
                      AppSpacing.xs,
                      AppSpacing.screenHorizontal,
                      AppSpacing.sm,
                    ),
                    child: AbsorbPointer(
                      absorbing: _isLoading,
                      child: _buildContinueButton(),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
