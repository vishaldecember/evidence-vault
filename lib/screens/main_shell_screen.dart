import 'package:flutter/material.dart';

import '../constants/app_spacing.dart';
import '../diagnostics/sprint6c_file_trace.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_text_styles.dart';
import '../widgets/common/space_canvas.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'vault_screen.dart';

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    Sprint6cFileTrace.nav('MainShell INIT (Home tab visible under routes)');
  }

  @override
  void dispose() {
    Sprint6cFileTrace.nav(
      'MainShell DISPOSE ← shell recreated / AuthGate swap',
    );
    super.dispose();
  }

  static final _destinations = [
    _ShellDestination(
      label: 'Home',
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      screen: const HomeScreen(),
    ),
    _ShellDestination(
      label: 'Vault',
      icon: Icons.inventory_2_outlined,
      activeIcon: Icons.inventory_2_rounded,
      screen: const VaultScreen(),
    ),
    _ShellDestination(
      label: 'Profile',
      icon: Icons.person_outline,
      activeIcon: Icons.person_rounded,
      screen: const ProfileScreen(),
    ),
  ];

  void _dismissTransientMessages() {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _dismissTransientMessages(),
      child: SpaceCanvas(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: IndexedStack(
            index: _selectedIndex,
            children: [
              for (final destination in _destinations) destination.screen,
            ],
          ),
          bottomNavigationBar: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppSpacing.cardRadius),
              ),
              border: Border(
                top: BorderSide(color: AppColors.border.withValues(alpha: 0.9)),
              ),
              boxShadow: AppDecorations.bottomNavShadows,
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppSpacing.cardRadius),
              ),
              child: BottomNavigationBar(
                currentIndex: _selectedIndex,
                onTap: (index) {
                  _dismissTransientMessages();
                  setState(() => _selectedIndex = index);
                },
                type: BottomNavigationBarType.fixed,
                elevation: 0,
                backgroundColor: Colors.transparent,
                selectedItemColor: AppColors.primary,
                unselectedItemColor: AppColors.textMuted,
                selectedLabelStyle: AppTextStyles.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
                unselectedLabelStyle: AppTextStyles.caption.copyWith(
                  fontWeight: FontWeight.w500,
                  color: AppColors.textMuted,
                ),
                items: [
                  for (final destination in _destinations)
                    BottomNavigationBarItem(
                      icon: Icon(destination.icon),
                      activeIcon: Icon(destination.activeIcon),
                      label: destination.label,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShellDestination {
  const _ShellDestination({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.screen,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final Widget screen;
}
