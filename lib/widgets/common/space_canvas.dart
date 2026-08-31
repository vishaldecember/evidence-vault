import 'package:flutter/material.dart';

import '../../theme/app_decorations.dart';

/// Full-bleed aerospace atmosphere: dark edges, illuminated center.
///
/// Static [Positioned.fill] layers behind [child]. Visual only.
/// Host this around the shared Scaffold — never inside HomeBody or LayeredCard.
class SpaceCanvas extends StatelessWidget {
  const SpaceCanvas({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        for (final decoration in AppDecorations.spaceCanvasLayers)
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: decoration,
                child: const SizedBox.expand(),
              ),
            ),
          ),
        child,
      ],
    );
  }
}
