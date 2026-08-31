import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../constants/app_spacing.dart';
import '../../../domain/trust_package/trust_package.dart';
import '../../../models/trust_package_share_link.dart';
import '../../../services/trust_package/trust_package_share_service.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../widgets/common/app_snackbar.dart';

/// Secure share settings for a Trust Package.
class TrustPackageShareSheet extends StatefulWidget {
  const TrustPackageShareSheet({
    super.key,
    required this.package,
  });

  final TrustPackage package;

  @override
  State<TrustPackageShareSheet> createState() => _TrustPackageShareSheetState();
}

class _TrustPackageShareSheetState extends State<TrustPackageShareSheet> {
  final _shareService = const TrustPackageShareService();
  final _notesController = TextEditingController();
  DateTime? _expiresAt;
  bool _viewOnly = true;
  TrustPackageShareLink? _createdLink;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _createLink() async {
    final link = _shareService.createShareLink(
      widget.package,
      settings: TrustPackageShareSettings(
        recipientNotes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        expiresAt: _expiresAt,
        viewOnly: _viewOnly,
      ),
    );
    setState(() => _createdLink = link);
  }

  Future<void> _shareLink(TrustPackageShareLink link) async {
    final expiryText = link.expiresAt == null
        ? 'No expiry'
        : DateFormat('d MMM yyyy').format(link.expiresAt!);
    final message = StringBuffer()
      ..writeln('Trust Package: ${link.packageName}')
      ..writeln('Version: ${link.packageVersion}')
      ..writeln('Generated: ${DateFormat('d MMM yyyy').format(link.generatedAt)}')
      ..writeln('Access: ${link.viewOnly ? 'View only' : 'Standard'}')
      ..writeln('Expiry: $expiryText');
    if (link.recipientNotes != null && link.recipientNotes!.isNotEmpty) {
      message.writeln('Notes: ${link.recipientNotes}');
    }
    message.writeln(link.shareUrl);

    await SharePlus.instance.share(
      ShareParams(
        text: message.toString(),
        subject: link.packageName,
      ),
    );
    if (mounted) {
      AppSnackBar.showSuccess(context, 'Secure share link created');
    }
  }

  @override
  Widget build(BuildContext context) {
    final metadata = widget.package.metadata;
    final dateFormat = DateFormat('d MMMM yyyy • HH:mm');

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.screenHorizontal,
          AppSpacing.md,
          AppSpacing.screenHorizontal,
          AppSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Secure Share',
                style: AppTextStyles.screenTitle.copyWith(fontSize: 18),
              ),
              const SizedBox(height: AppSpacing.lg),
              _SettingRow(
                label: 'Package Name',
                value: widget.package.incidentSummary.incidentName,
              ),
              _SettingRow(
                label: 'Package Version',
                value: metadata.packageVersion,
              ),
              _SettingRow(
                label: 'Generated Date',
                value: dateFormat.format(metadata.generatedAt),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Recipient Notes (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: AppSpacing.md),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('View-only mode'),
                subtitle: const Text(
                  'Recipients can review the package without editing.',
                ),
                value: _viewOnly,
                onChanged: (value) => setState(() => _viewOnly = value),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Expiry (optional)'),
                subtitle: Text(
                  _expiresAt == null
                      ? 'No expiry selected'
                      : dateFormat.format(_expiresAt!),
                ),
                trailing: TextButton(
                  onPressed: () async {
                    final selected = await showDatePicker(
                      context: context,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      initialDate:
                          _expiresAt ?? DateTime.now().add(const Duration(days: 30)),
                    );
                    if (selected != null) {
                      setState(() => _expiresAt = selected);
                    }
                  },
                  child: Text(_expiresAt == null ? 'Set' : 'Change'),
                ),
              ),
              if (_expiresAt != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => setState(() => _expiresAt = null),
                    child: const Text('Clear expiry'),
                  ),
                ),
              const SizedBox(height: AppSpacing.lg),
              if (_createdLink == null)
                FilledButton(
                  onPressed: _createLink,
                  child: const Text('Create Secure Share Link'),
                )
              else ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(AppSpacing.sm),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Package ID',
                        style: AppTextStyles.caption.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      SelectableText(
                        _createdLink!.packageId,
                        style: AppTextStyles.bodySmall,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Share URL',
                        style: AppTextStyles.caption.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      SelectableText(
                        _createdLink!.shareUrl ?? '',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.navy,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        _createdLink!.viewOnly
                            ? 'Read-only access enabled'
                            : 'Standard access',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.success,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                FilledButton(
                  onPressed: () => _shareLink(_createdLink!),
                  child: const Text('Share Link'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
