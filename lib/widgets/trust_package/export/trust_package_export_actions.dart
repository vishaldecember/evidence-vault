import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../constants/app_spacing.dart';
import '../../../domain/trust_package/trust_package.dart';
import '../../../models/trust_package_archive_record.dart';
import '../../../repositories/trust_package_archive_store.dart';
import '../../../services/trust_package/trust_package_export_service.dart';
import '../../../services/trust_package/trust_package_print_service.dart';
import '../../../services/trust_package/trust_package_share_service.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../widgets/common/app_snackbar.dart';
import '../preview/trust_package_preview.dart';
import 'trust_package_share_sheet.dart';

/// Export actions for the Trust Package Preview workspace.
class TrustPackageExportActions extends StatelessWidget {
  const TrustPackageExportActions({
    super.key,
    required this.package,
  });

  final TrustPackage package;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Export Trust Package',
      onPressed: () => _openExportSheet(context),
      icon: const Icon(
        Icons.ios_share_rounded,
        color: AppColors.onCanvas,
      ),
    );
  }

  Future<void> _openExportSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.md)),
      ),
      builder: (context) {
        return _TrustPackageExportSheet(package: package);
      },
    );
  }
}

class _TrustPackageExportSheet extends StatefulWidget {
  const _TrustPackageExportSheet({required this.package});

  final TrustPackage package;

  @override
  State<_TrustPackageExportSheet> createState() =>
      _TrustPackageExportSheetState();
}

class _TrustPackageExportSheetState extends State<_TrustPackageExportSheet> {
  final _exportService = const TrustPackageExportService();
  final _shareService = const TrustPackageShareService();
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final archives = TrustPackageArchiveStore.forIncident(
      _shareService.originatingIncidentId(widget.package),
    );

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.screenHorizontal,
          AppSpacing.md,
          AppSpacing.screenHorizontal,
          AppSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Export Trust Package',
              style: AppTextStyles.screenTitle.copyWith(fontSize: 18),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Generate a professional, traceable package without changing '
              'the investigation.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _ExportOptionTile(
              icon: Icons.picture_as_pdf_outlined,
              title: 'Export PDF',
              subtitle: 'Professional report with integrity notice',
              enabled: !_busy,
              onTap: () => _run(() async {
                final result =
                    await _exportService.exportPdf(widget.package);
                if (!context.mounted) {
                  return;
                }
                Navigator.pop(context);
                await SharePlus.instance.share(
                  ShareParams(
                    files: [XFile(result.filePath)],
                    subject: widget.package.incidentSummary.incidentName,
                  ),
                );
              }),
            ),
            _ExportOptionTile(
              icon: Icons.print_outlined,
              title: 'Print',
              subtitle: 'Print-friendly layout for A4 / Letter',
              enabled: !_busy,
              onTap: () => _run(() async {
                if (!context.mounted) {
                  return;
                }
                Navigator.pop(context);
                await Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (context) => TrustPackagePrintScreen(
                      package: widget.package,
                    ),
                  ),
                );
              }),
            ),
            _ExportOptionTile(
              icon: Icons.archive_outlined,
              title: 'Archive Snapshot',
              subtitle: 'Immutable package linked to this incident',
              enabled: !_busy,
              onTap: () => _run(() async {
                final result =
                    await _exportService.exportArchive(widget.package);
                if (!context.mounted) {
                  return;
                }
                Navigator.pop(context);
                AppSnackBar.showSuccess(
                  context,
                  'Archived ${result.fileName}',
                );
              }),
            ),
            _ExportOptionTile(
              icon: Icons.link_rounded,
              title: 'Create Secure Share Link',
              subtitle: 'Optional expiry and view-only access',
              enabled: !_busy,
              onTap: () async {
                if (!context.mounted) {
                  return;
                }
                Navigator.pop(context);
                await showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: AppColors.background,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(AppSpacing.md),
                    ),
                  ),
                  builder: (context) {
                    return TrustPackageShareSheet(package: widget.package);
                  },
                );
              },
            ),
            if (archives.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Archived Snapshots',
                style: AppTextStyles.label.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final archive in archives.take(3))
                _ArchiveSummaryRow(record: archive),
            ],
          ],
        ),
      ),
    );
  }
}

class _ExportOptionTile extends StatelessWidget {
  const _ExportOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.enabled,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(AppSpacing.sm),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Icon(icon, color: AppColors.navy),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.label.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ArchiveSummaryRow extends StatelessWidget {
  const _ArchiveSummaryRow({required this.record});

  final TrustPackageArchiveRecord record;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('d MMM yyyy • HH:mm');
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Text(
        'v${record.packageVersion} • Generated ${dateFormat.format(record.generatedAt)} '
        '• Archived ${dateFormat.format(record.archivedAt)}',
        style: AppTextStyles.caption.copyWith(
          color: AppColors.textSecondary,
          height: 1.4,
        ),
      ),
    );
  }
}

/// Print-friendly Trust Package view — no navigation or application controls.
class TrustPackagePrintScreen extends StatelessWidget {
  const TrustPackagePrintScreen({
    super.key,
    required this.package,
  });

  final TrustPackage package;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenHorizontal,
                AppSpacing.sm,
                AppSpacing.screenHorizontal,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Close print view',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                  Expanded(
                    child: Text(
                      'Print Preview',
                      style: AppTextStyles.label.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => TrustPackagePrintService.printPackage(package),
                    icon: const Icon(Icons.print_rounded, size: 18),
                    label: const Text('Print'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: TrustPackagePreview(
                package: package,
                showNavigation: false,
                printLayout: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
