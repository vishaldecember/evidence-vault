import 'package:flutter/material.dart';

import '../navigation/app_navigation.dart';
import '../theme/app_colors.dart';

/// Legacy capture entry point — retained only so [AppNavigation.openCreateEvidence]
/// keeps compiling for any lingering caller. Redirects straight into the
/// unified Evidence Workspace instead of showing the old capture-type picker
/// (Sprint 4D legacy cleanup).
class CreateEvidenceScreen extends StatefulWidget {
  const CreateEvidenceScreen({super.key});

  @override
  State<CreateEvidenceScreen> createState() => _CreateEvidenceScreenState();
}

class _CreateEvidenceScreenState extends State<CreateEvidenceScreen> {
  bool _redirecting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _redirect());
  }

  Future<void> _redirect() async {
    if (_redirecting || !mounted) {
      return;
    }
    _redirecting = true;
    await AppNavigation.openEvidenceWorkspace(context, captureInitiated: true);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
