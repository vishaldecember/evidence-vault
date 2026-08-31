import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

/// Translucent modern-art wash behind evidence thumbnails.
///
/// One implementation for Capture and Organize. Do not fork opacity, blur,
/// colors, or composition per surface.
class ThumbnailAtmosphereSurface extends StatelessWidget {
  const ThumbnailAtmosphereSurface({super.key});

  static const asset = 'assets/images/capture/thumbnail_atmosphere.jpg';
  static const Key layerKey = Key('thumbnail_atmosphere_surface');

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        key: layerKey,
        fit: StackFit.expand,
        children: [
          ImageFiltered(
            imageFilter: ImageFilter.blur(
              sigmaX: 16,
              sigmaY: 16,
              tileMode: TileMode.decal,
            ),
            child: Image.asset(
              asset,
              fit: BoxFit.cover,
              excludeFromSemantics: true,
              filterQuality: FilterQuality.medium,
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              color: Color(0x73F6FAFC),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              color: Color(0x14A9D4E4),
            ),
          ),
        ],
      ),
    );
  }
}
