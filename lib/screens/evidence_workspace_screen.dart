import 'package:flutter/material.dart';

import '../models/workspace_capture_mode.dart';
import '../controllers/workspace_evidence_controller.dart';
import 'incident_workspace_shell.dart';

/// Entry point for the Capture stage — hosts [IncidentWorkspaceShell].
class EvidenceWorkspaceScreen extends StatelessWidget {
  const EvidenceWorkspaceScreen({
    super.key,
    this.initialCaptureMode,
    this.controller,
  });

  final WorkspaceCaptureMode? initialCaptureMode;
  final WorkspaceEvidenceController? controller;

  @override
  Widget build(BuildContext context) {
    return IncidentWorkspaceShell(
      incidentId: controller?.currentIncident.id,
      initialCaptureMode: initialCaptureMode,
      controller: controller,
    );
  }
}
