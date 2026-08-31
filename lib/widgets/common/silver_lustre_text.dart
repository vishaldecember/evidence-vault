import 'package:flutter/material.dart';

import '../../theme/app_decorations.dart';

/// Restrained metallic silver text — luminance treatment, not sparkle.
class SilverLustreText extends StatelessWidget {
  const SilverLustreText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) =>
          AppDecorations.silverLustre.createShader(bounds),
      child: Text(
        text,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
        textWidthBasis: maxLines == 1
            ? TextWidthBasis.longestLine
            : TextWidthBasis.parent,
        style: (style ?? const TextStyle()).copyWith(color: Colors.white),
      ),
    );
  }
}
