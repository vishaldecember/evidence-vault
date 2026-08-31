import 'dart:io';

import 'package:flutter/material.dart';

import '../constants/app_spacing.dart';
import '../models/workspace_evidence_item.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/common/app_back_button.dart';
import '../widgets/evidence_inspector/evidence_media_source.dart';

/// Focused photo examination. Presentation-only — does not mutate Evidence.
class EvidenceImageInspectionScreen extends StatefulWidget {
  const EvidenceImageInspectionScreen({
    super.key,
    required this.evidence,
  });

  final WorkspaceEvidenceItem evidence;

  static const screenKey = Key('evidence_image_inspection_screen');
  static const viewerKey = Key('evidence_image_inspection_viewer');
  static const closeKey = Key('evidence_image_inspection_close');
  static const zoomInKey = Key('evidence_image_inspection_zoom_in');
  static const zoomOutKey = Key('evidence_image_inspection_zoom_out');
  static const resetKey = Key('evidence_image_inspection_reset');
  static const errorKey = Key('evidence_image_inspection_error');
  static const loadingKey = Key('evidence_image_inspection_loading');
  static const previewOnlyKey = Key('evidence_image_inspection_preview_only');

  static const minScale = 1.0;
  static const maxScale = 4.0;
  static const doubleTapScale = 2.5;

  /// Test seam — avoids [Image.file] in widget tests.
  @visibleForTesting
  static Widget Function(String filePath)? debugImageBuilder;

  static String? sourcePath(WorkspaceEvidenceItem item) =>
      EvidenceMediaSource.inspectionPath(item);

  @override
  State<EvidenceImageInspectionScreen> createState() =>
      _EvidenceImageInspectionScreenState();
}

class _EvidenceImageInspectionScreenState
    extends State<EvidenceImageInspectionScreen> {
  final TransformationController _transform = TransformationController();
  TapDownDetails? _doubleTapDetails;

  String? get _path =>
      EvidenceImageInspectionScreen.sourcePath(widget.evidence);

  double get _scale => _transform.value.getMaxScaleOnAxis();

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _setScale(double next, {Offset? focal}) {
    final clamped = next.clamp(
      EvidenceImageInspectionScreen.minScale,
      EvidenceImageInspectionScreen.maxScale,
    );
    final scene = focal ?? Offset.zero;
    _transform.value = Matrix4.identity()
      ..translateByDouble(scene.dx, scene.dy, 0, 1)
      ..scaleByDouble(clamped, clamped, 1, 1)
      ..translateByDouble(-scene.dx, -scene.dy, 0, 1);
    setState(() {});
  }

  void _zoomBy(double factor) {
    _setScale(_scale * factor);
  }

  void _reset() {
    _transform.value = Matrix4.identity();
    setState(() {});
  }

  void _handleDoubleTap() {
    final details = _doubleTapDetails;
    final focal = details?.localPosition ?? Offset.zero;
    if (_scale > 1.05) {
      _reset();
      return;
    }
    _setScale(EvidenceImageInspectionScreen.doubleTapScale, focal: focal);
  }

  @override
  Widget build(BuildContext context) {
    final path = _path;
    final previewOnly =
        EvidenceMediaSource.isInspectionPreviewOnly(widget.evidence);
    final override = EvidenceImageInspectionScreen.debugImageBuilder;
    final readable =
        override != null || EvidenceMediaSource.isReadableFile(path);
    final size = MediaQuery.sizeOf(context);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final decodeW = EvidenceMediaSource.decodeWidth(
      logicalWidth: size.width,
      devicePixelRatio: dpr,
      scale: EvidenceImageInspectionScreen.maxScale,
    );

    return Scaffold(
      key: EvidenceImageInspectionScreen.screenKey,
      backgroundColor: AppColors.canvasDeep,
      body: SafeArea(
        child: Column(
          children: [
            _InspectionChrome(
              onClose: () => Navigator.of(context).maybePop(),
              onZoomIn: () => _zoomBy(1.35),
              onZoomOut: () => _zoomBy(1 / 1.35),
              onReset: _reset,
              previewOnly: previewOnly,
            ),
            Expanded(
              child: Semantics(
                label: previewOnly
                    ? 'Photo evidence. Preview only. Pinch or use zoom controls.'
                    : 'Photo evidence. Pinch or use zoom controls to examine.',
                image: true,
                child: GestureDetector(
                  onDoubleTapDown: (details) => _doubleTapDetails = details,
                  onDoubleTap: _handleDoubleTap,
                  child: InteractiveViewer(
                    key: EvidenceImageInspectionScreen.viewerKey,
                    transformationController: _transform,
                    minScale: EvidenceImageInspectionScreen.minScale,
                    maxScale: EvidenceImageInspectionScreen.maxScale,
                    clipBehavior: Clip.hardEdge,
                    child: SizedBox(
                      width: size.width,
                      height: size.height,
                      child: override != null
                          ? override(path ?? '')
                          : readable
                              ? _InspectionImage(
                                  path: path!,
                                  decodeWidth: decodeW,
                                )
                              : const _InspectionUnavailable(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InspectionChrome extends StatelessWidget {
  const _InspectionChrome({
    required this.onClose,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onReset,
    required this.previewOnly,
  });

  final VoidCallback onClose;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onReset;
  final bool previewOnly;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xs,
        AppSpacing.xxs,
        AppSpacing.xs,
        AppSpacing.xxs,
      ),
      child: Row(
        children: [
          AppBackButton(
            key: EvidenceImageInspectionScreen.closeKey,
            color: AppColors.onCanvas,
            onPressed: onClose,
          ),
          Expanded(
            child: previewOnly
                ? Text(
                    'Preview only',
                    key: EvidenceImageInspectionScreen.previewOnlyKey,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.onCanvasSecondary,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          IconButton(
            key: EvidenceImageInspectionScreen.zoomOutKey,
            tooltip: 'Zoom out',
            onPressed: onZoomOut,
            color: AppColors.onCanvas,
            icon: const Icon(Icons.remove_rounded),
          ),
          IconButton(
            key: EvidenceImageInspectionScreen.zoomInKey,
            tooltip: 'Zoom in',
            onPressed: onZoomIn,
            color: AppColors.onCanvas,
            icon: const Icon(Icons.add_rounded),
          ),
          IconButton(
            key: EvidenceImageInspectionScreen.resetKey,
            tooltip: 'Reset zoom',
            onPressed: onReset,
            color: AppColors.onCanvas,
            icon: const Icon(Icons.fit_screen_rounded),
          ),
        ],
      ),
    );
  }
}

class _InspectionImage extends StatelessWidget {
  const _InspectionImage({
    required this.path,
    required this.decodeWidth,
  });

  final String path;
  final int decodeWidth;

  @override
  Widget build(BuildContext context) {
    final override = EvidenceImageInspectionScreen.debugImageBuilder;
    if (override != null) {
      return override(path);
    }

    return Image.file(
      File(path),
      fit: BoxFit.contain,
      alignment: Alignment.center,
      cacheWidth: decodeWidth,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) {
          return child;
        }
        return const Center(
          key: EvidenceImageInspectionScreen.loadingKey,
          child: CircularProgressIndicator(color: AppColors.onCanvas),
        );
      },
      errorBuilder: (_, _, _) => const _InspectionUnavailable(
        decodeFailed: true,
      ),
    );
  }
}

class _InspectionUnavailable extends StatelessWidget {
  const _InspectionUnavailable({this.decodeFailed = false});

  final bool decodeFailed;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: EvidenceImageInspectionScreen.errorKey,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.photo_outlined,
              size: 56,
              color: AppColors.onCanvasSecondary.withValues(alpha: 0.8),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              decodeFailed ? 'Photo could not be displayed' : 'Photo unavailable',
              textAlign: TextAlign.center,
              style: AppTextStyles.label.copyWith(
                color: AppColors.onCanvas,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              decodeFailed
                  ? 'The preview could not be decoded. The original evidence was not changed.'
                  : 'The image file could not be opened. The original evidence was not changed.',
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.onCanvasSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
