import 'dart:io';

import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import '../../models/evidence_category.dart';
import '../../models/evidence_type.dart';
import '../../models/pending_evidence.dart';
import '../../services/document_import_service.dart';
import '../../services/metadata_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/ev_button.dart';

class DocumentImportLauncher extends StatefulWidget {
  const DocumentImportLauncher({
    super.key,
    required this.title,
    required this.description,
    required this.category,
  });

  final String title;
  final String description;
  final EvidenceCategory category;

  @override
  State<DocumentImportLauncher> createState() => _DocumentImportLauncherState();
}

class _DocumentImportLauncherState extends State<DocumentImportLauncher> {
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _import());
  }

  Future<void> _import() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final path = await DocumentImportService.importDocument();
      if (!mounted) return;

      if (path == null) {
        Navigator.pop(context);
        return;
      }

      final metadata = await MetadataService.collect();
      final fileSize = await File(path).length();
      if (!mounted) return;
      final lower = path.toLowerCase();
      final thumbnail = lower.endsWith('.jpg') ||
              lower.endsWith('.jpeg') ||
              lower.endsWith('.png') ||
              lower.endsWith('.gif') ||
              lower.endsWith('.webp')
          ? path
          : null;

      Navigator.pop(
        context,
        PendingEvidence(
          title: widget.title,
          description: widget.description,
          category: widget.category,
          type: EvidenceType.document,
          filePath: path,
          thumbnailPath: thumbnail,
          metadata: metadata,
          fileSizeBytes: fileSize,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Unable to import document. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text('Import Document', style: AppTextStyles.screenTitle),
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_isLoading) ...[
              const SizedBox(height: AppSpacing.xxxl),
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Opening file picker…',
                textAlign: TextAlign.center,
                style: AppTextStyles.body,
              ),
            ],
            if (_error != null) ...[
              Text(_error!, style: AppTextStyles.body),
              const SizedBox(height: AppSpacing.lg),
              EVButton(text: 'Try again', onPressed: _import),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
