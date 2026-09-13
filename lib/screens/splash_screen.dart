import 'package:flutter/material.dart';
import '../navigation/auth_navigation.dart';
import '../presentation/trust_security_copy.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../utils/auth_form_helpers.dart';
import '../widgets/auth/auth_feedback.dart';
import 'create_account_screen.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const double _logoWidth = 165;
  static const double _logoHeight = 117;

  bool _isGoogleLoading = false;
  bool _isAppleLoading = false;

  bool get _isBusy => _isGoogleLoading || _isAppleLoading;

  Future<void> _handleGoogleSignIn() async {
    if (_isBusy) return;

    setState(() => _isGoogleLoading = true);

    try {
      await AuthService.signInWithGoogle();
      if (!mounted) return;
      AuthFeedback.showSuccess(context, 'Signed in with Google.');
    } catch (error) {
      if (!mounted) return;
      AuthFormHelpers.handleAuthError(
        context,
        error,
        onRetry: _handleGoogleSignIn,
      );
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  Future<void> _handleAppleSignIn() async {
    if (_isBusy) return;

    setState(() => _isAppleLoading = true);

    try {
      await AuthService.signInWithApple();
      if (!mounted) return;
      AuthFeedback.showSuccess(context, 'Signed in with Apple.');
    } catch (error) {
      if (!mounted) return;
      AuthFormHelpers.handleAuthError(
        context,
        error,
        onRetry: _handleAppleSignIn,
      );
    } finally {
      if (mounted) setState(() => _isAppleLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        minimum: const EdgeInsets.only(bottom: 4),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                24,
                10,
                24,
                bottomInset + 16,
              ),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - bottomInset,
                ),
                child: AbsorbPointer(
                  absorbing: _isBusy,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Center(
                        child: SizedBox(
                          width: _logoWidth,
                          height: _logoHeight,
                          child: Image.asset(
                            'assets/images/branding/splash_logo.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      const _HeroStatementSection(),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Color(0xFFF4F7FF),
                          borderRadius: BorderRadius.all(
                            Radius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'My Truth helps you preserve, enrich, and understand '
                          'the moments that matter—building your Library of Truth over time.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF102A5E),
                            height: 1.45,
                          ),
                        ),
                      ),
                      Transform.translate(
                        offset: const Offset(0, -14),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            Expanded(
                              child: FeatureCard(
                                icon: Icons.lock,
                                title: TrustSecurityCopy.splashProtectionTitle,
                                subtitle:
                                    TrustSecurityCopy.splashProtectionSubtitle,
                              ),
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: FeatureCard(
                                icon: Icons.access_time,
                                title: 'Time Stamped',
                                subtitle: 'Trusted Date & Time',
                              ),
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: FeatureCard(
                                icon: Icons.folder_copy,
                                title: 'Organised',
                                subtitle: 'All your records',
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: ElevatedButton(
                              onPressed: _isBusy
                                  ? null
                                  : () => AuthNavigation.push(
                                        context,
                                        const CreateAccountScreen(),
                                      ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF3B36F4),
                                foregroundColor: Colors.white,
                                elevation: 8,
                                shadowColor: const Color(0x553B36F4),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text(
                                'Create Account',
                                style: TextStyle(fontSize: 17),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: const [
                              Expanded(child: Divider()),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 10),
                                child: Text('OR'),
                              ),
                              Expanded(child: Divider()),
                            ],
                          ),
                          const SizedBox(height: 4),
                          SocialButton(
                            icon: 'assets/icons/google.png',
                            text: 'Continue with Google',
                            isLoading: _isGoogleLoading,
                            onTap: _isBusy ? null : _handleGoogleSignIn,
                          ),
                          const SizedBox(height: 18),
                          SocialButton(
                            icon: 'assets/icons/apple.png',
                            text: 'Continue with Apple',
                            isLoading: _isAppleLoading,
                            onTap: _isBusy ? null : _handleAppleSignIn,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Flexible(
                                child: Text(
                                  'Already have an account?',
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              TextButton(
                                onPressed: _isBusy
                                    ? null
                                    : () => AuthNavigation.push(
                                          context,
                                          const LoginScreen(),
                                        ),
                                style: TextButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 8),
                                ),
                                child: const Text('Log in'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HeroStatementSection extends StatelessWidget {
  const _HeroStatementSection();

  static const double _sectionPadding = 12;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _HeroDivider(),
        const SizedBox(height: _sectionPadding),
        const Text(
          'Have you ever wished you had\nproof of what really happened?',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.navy,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Helping you enrich your most\nvaluable asset — your truth.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            color: Color(0xFF6B7280),
            height: 1.4,
          ),
        ),
        const SizedBox(height: _sectionPadding),
        const _HeroDivider(),
      ],
    );
  }
}

class _HeroDivider extends StatelessWidget {
  const _HeroDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 1.5,
      color: AppColors.primary,
    );
  }
}

class FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const FeatureCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          icon,
          size: 22,
          color: const Color(0xFF3B36F4),
        ),
        const SizedBox(height: 5),
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 10,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}

class SocialButton extends StatelessWidget {
  final String icon;
  final String text;
  final VoidCallback? onTap;
  final bool isLoading;

  const SocialButton({
    super.key,
    required this.icon,
    required this.text,
    this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: OutlinedButton(
          onPressed: isLoading ? null : onTap,
          style: OutlinedButton.styleFrom(
            backgroundColor: Colors.white,
            side: BorderSide(
              color: Color(0xFFE5E7EB),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      icon,
                      width: 22,
                      height: 22,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        text,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
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
