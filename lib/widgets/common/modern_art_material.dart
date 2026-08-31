import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'thumbnail_atmosphere_surface.dart';

/// Shared modern-art wash for chrome surfaces.
///
/// Same asset family as [ThumbnailAtmosphereSurface]. One implementation for
/// Capture Now, the Incident Workspace sticky bar, and the Organize toolbar.
class ChromeAtmosphereSurface extends StatelessWidget {
  const ChromeAtmosphereSurface({super.key, this.solid = false});

  /// Opaque floating control surface (Organize toolbar). Capture Now stays soft.
  final bool solid;

  static const asset = ThumbnailAtmosphereSurface.asset;
  static const Key layerKey = Key('chrome_atmosphere_surface');
  static const Key solidLayerKey = Key('chrome_atmosphere_surface_solid');

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        key: solid ? solidLayerKey : layerKey,
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Color(0xFFF4F8FC)),
          ImageFiltered(
            imageFilter: ImageFilter.blur(
              sigmaX: solid ? 10 : 14,
              sigmaY: solid ? 10 : 14,
              tileMode: TileMode.decal,
            ),
            child: Opacity(
              opacity: solid ? 0.92 : 1,
              child: Image.asset(
                asset,
                fit: BoxFit.cover,
                excludeFromSemantics: true,
                filterQuality: FilterQuality.medium,
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: solid ? const Color(0xE6F6FAFC) : const Color(0x59F6FAFC),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: solid ? const Color(0x33A9D4E4) : const Color(0x12A9D4E4),
            ),
          ),
        ],
      ),
    );
  }
}

/// Soft abstract artwork behind the Groups card matrix.
///
/// Visible blue/white painterly material, diffused and low-contrast so the
/// 2×2 group tiles stay primary. Artwork only — not a pasted photograph.
class GroupsAtmosphereSurface extends StatelessWidget {
  const GroupsAtmosphereSurface({super.key});

  static const asset = 'assets/images/organize/groups_atmosphere.jpg';
  static const Key layerKey = Key('groups_atmosphere_surface');

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        key: layerKey,
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Color(0xFFE8F1F7)),
          ImageFiltered(
            imageFilter: ImageFilter.blur(
              sigmaX: 14,
              sigmaY: 14,
              tileMode: TileMode.decal,
            ),
            child: ColorFiltered(
              colorFilter: const ColorFilter.matrix(<double>[
                0.88,
                0.06,
                0.06,
                0,
                18,
                0.05,
                0.90,
                0.06,
                0,
                22,
                0.04,
                0.08,
                0.92,
                0,
                28,
                0,
                0,
                0,
                1,
                0,
              ]),
              child: Opacity(
                opacity: 0.82,
                child: Image.asset(
                  asset,
                  fit: BoxFit.cover,
                  excludeFromSemantics: true,
                  filterQuality: FilterQuality.medium,
                ),
              ),
            ),
          ),
          // Soft translucent veil — artwork remains visible behind the matrix.
          const DecoratedBox(
            decoration: BoxDecoration(color: Color(0x59F4F8FB)),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(color: Color(0x14A9C8DC)),
          ),
        ],
      ),
    );
  }
}
