import 'dart:io';

import 'package:flutter/material.dart';

import '../../domain/evidence/evidence_record_type.dart';
import '../../presentation/incident_cover_resolver.dart';
import '../../theme/app_colors.dart';

/// Derived cover presentation. Uses an existing thumbnail path only.
///
/// Does not decode original evidence. Missing files use a calm fallback.
class IncidentCoverPreview extends StatelessWidget {
  const IncidentCoverPreview({
    super.key,
    required this.incidentId,
    required this.resolution,
    this.size = 36,
  }) : height = null,
       expand = false;

  const IncidentCoverPreview.band({
    super.key,
    required this.incidentId,
    required this.resolution,
    this.height = 72,
  }) : size = 72,
       expand = true;

  final String incidentId;
  final IncidentCoverResolution resolution;
  final double size;
  final double? height;
  final bool expand;

  static Key resolvedKey(String incidentId) =>
      Key('incident_cover_resolved_$incidentId');

  static Key fallbackKey(String incidentId) =>
      Key('incident_cover_fallback_$incidentId');

  static const double bandHeight = 72;

  @override
  Widget build(BuildContext context) {
    final boxHeight = height ?? size;
    if (!resolution.hasThumbnail) {
      return _FallbackFrame(
        key: fallbackKey(incidentId),
        height: boxHeight,
        expand: expand,
        size: size,
        evidenceType: resolution.evidenceType,
      );
    }
    final path = resolution.thumbnailPath!.trim();
    final file = File(path);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheWidth = expand
        ? (MediaQuery.sizeOf(context).width * dpr).round().clamp(128, 640)
        : (size * dpr).round().clamp(64, 256);
    return SizedBox(
      key: resolvedKey(incidentId),
      width: expand ? double.infinity : size,
      height: boxHeight,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: file.existsSync()
            ? Image.file(
                file,
                fit: BoxFit.cover,
                width: expand ? double.infinity : size,
                height: boxHeight,
                alignment: Alignment.center,
                filterQuality: FilterQuality.medium,
                cacheWidth: cacheWidth,
                gaplessPlayback: true,
                errorBuilder: (context, error, stackTrace) {
                  return _FallbackWash(evidenceType: resolution.evidenceType);
                },
              )
            : _FallbackWash(evidenceType: resolution.evidenceType),
      ),
    );
  }
}

class _FallbackFrame extends StatelessWidget {
  const _FallbackFrame({
    super.key,
    required this.height,
    required this.expand,
    required this.size,
    this.evidenceType,
  });

  final double height;
  final bool expand;
  final double size;
  final EvidenceRecordType? evidenceType;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: expand ? double.infinity : size,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: _FallbackWash(evidenceType: evidenceType),
      ),
    );
  }
}

class _FallbackWash extends StatelessWidget {
  const _FallbackWash({this.evidenceType});

  final EvidenceRecordType? evidenceType;

  IconData? get _typeIcon => switch (evidenceType) {
        EvidenceRecordType.video => Icons.videocam_outlined,
        EvidenceRecordType.voice => Icons.mic_outlined,
        EvidenceRecordType.note => Icons.notes_outlined,
        EvidenceRecordType.document => Icons.description_outlined,
        EvidenceRecordType.witness => Icons.record_voice_over_outlined,
        EvidenceRecordType.other => null,
        EvidenceRecordType.photo || null => null,
      };

  @override
  Widget build(BuildContext context) {
    final icon = _typeIcon;
    return ColoredBox(
      color: AppColors.cardStack,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.canvasAtmosphere.withValues(alpha: 0.35),
              AppColors.cardStackDeep,
            ],
          ),
        ),
        child: icon == null
            ? null
            : Center(
                child: Icon(
                  icon,
                  size: 22,
                  color: AppColors.navy.withValues(alpha: 0.38),
                ),
              ),
      ),
    );
  }
}
