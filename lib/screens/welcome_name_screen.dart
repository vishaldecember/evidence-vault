import 'package:flutter/material.dart';

import '../constants/app_spacing.dart';
import '../services/auth/authentication_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/auth_form_helpers.dart';
import '../utils/auth_validators.dart';
import '../widgets/auth/auth_button.dart';
import '../widgets/auth/auth_feedback.dart';
import '../widgets/auth/auth_text_field.dart';

/// Collects preferred name after authentication — before Main Shell.
class WelcomeNameScreen extends StatefulWidget {
  const WelcomeNameScreen({super.key});

  @override
  State<WelcomeNameScreen> createState() => _WelcomeNameScreenState();
}

class _WelcomeNameScreenState extends State<WelcomeNameScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameFocus = FocusNode();
  final _scrollController = ScrollController();
  final _nameFieldKey = GlobalKey();

  String _name = '';
  bool _isLoading = false;
  bool _arrivalShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _arrivalShown) return;
      _arrivalShown = true;
      AuthFeedback.showSuccess(context, "You're in.");
    });
    _nameFocus.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _nameFocus.removeListener(_onFocusChanged);
    _nameFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_nameFocus.hasFocus) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 280));
      if (!mounted || !_nameFocus.hasFocus) return;
      final ctx = _nameFieldKey.currentContext;
      if (ctx == null || !ctx.mounted) return;
      await Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        alignment: 0.28,
      );
    });
  }

  Future<void> _handleStart() async {
    AuthFormHelpers.dismissKeyboard(context);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);
    try {
      await AuthenticationService.instance.updatePreferredName(_name.trim());
      // AuthGate moves to MainShell when needsPreferredName becomes false.
    } catch (error) {
      if (!mounted) return;
      AuthFormHelpers.handleAuthError(
        context,
        error,
        onRetry: _handleStart,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final keyboardVisible = bottomInset > 0;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.background,
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.screenHorizontal,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(
                                height: keyboardVisible
                                    ? AppSpacing.xl
                                    : AppSpacing.huge,
                              ),
                              Text(
                                'Welcome to Evidence Vault',
                                textAlign: TextAlign.center,
                                style: AppTextStyles.pageTitle.copyWith(
                                  fontSize: 26,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Text(
                                'What should we call you?',
                                textAlign: TextAlign.center,
                                style: AppTextStyles.body.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xl),
                              KeyedSubtree(
                                key: _nameFieldKey,
                                child: AuthTextField(
                                  label: 'Preferred name',
                                  hint: 'Alex',
                                  icon: Icons.person_outline_rounded,
                                  textInputAction: TextInputAction.done,
                                  validator: AuthValidators.name,
                                  focusNode: _nameFocus,
                                  enabled: !_isLoading,
                                  compact: true,
                                  onChanged: (value) => _name = value,
                                  onFieldSubmitted: (_) =>
                                      FocusScope.of(context).unfocus(),
                                ),
                              ),
                              if (!keyboardVisible) ...[
                                const SizedBox(height: AppSpacing.lg),
                                AuthButton(
                                  text: 'Start',
                                  isLoading: _isLoading,
                                  onPressed: _isLoading ? null : _handleStart,
                                ),
                              ],
                              const SizedBox(height: AppSpacing.md),
                            ],
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
                    child: AuthButton(
                      text: 'Start',
                      isLoading: _isLoading,
                      onPressed: _isLoading ? null : _handleStart,
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
