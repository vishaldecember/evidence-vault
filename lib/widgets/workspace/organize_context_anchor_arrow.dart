import 'package:flutter/material.dart';

/// Lasting Organize placement mark: context evidence → captured moment.
///
/// Presentation only. Does not store or imply Evidence Chain support.
class OrganizeContextAnchorArrow extends StatelessWidget {
  const OrganizeContextAnchorArrow({
    super.key,
    required this.contextEvidenceId,
    required this.capturedEvidenceId,
  });

  final String contextEvidenceId;
  final String capturedEvidenceId;

  static const bool pointsTowardEvidence = true;
  static const double width = 22;
  static const double height = 14;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Semantics(
        label:
            'Context $contextEvidenceId provides context for $capturedEvidenceId',
        child: SizedBox(
          width: width,
          height: height,
          child: CustomPaint(
            painter: _OrganizeContextArrowPainter(
              color: const Color(0xE8F4F8FC),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrganizeContextArrowPainter extends CustomPainter {
  const _OrganizeContextArrowPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final midY = size.height / 2;
    final start = Offset(size.width - 1, midY);
    final tip = Offset(1, midY);

    final line = Paint()
      ..color = color
      ..strokeWidth = 1.35
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..lineTo(tip.dx + 5, tip.dy);
    canvas.drawPath(
      _dashPath(
        path,
        dashArray: _CircularIntervalList<double>(const [2.6, 2.2]),
      ),
      line,
    );

    final head = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(tip.dx + 5.5, tip.dy - 3.2)
      ..lineTo(tip.dx + 5.5, tip.dy + 3.2)
      ..close();
    canvas.drawPath(
      head,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _OrganizeContextArrowPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

Path _dashPath(
  Path source, {
  required _CircularIntervalList<double> dashArray,
}) {
  final dest = Path();
  for (final metric in source.computeMetrics()) {
    var distance = 0.0;
    var draw = true;
    while (distance < metric.length) {
      final length = dashArray.next;
      if (draw) {
        dest.addPath(
          metric.extractPath(distance, distance + length),
          Offset.zero,
        );
      }
      distance += length;
      draw = !draw;
    }
  }
  return dest;
}

class _CircularIntervalList<T> {
  _CircularIntervalList(this._values);

  final List<T> _values;
  int _index = 0;

  T get next {
    if (_index >= _values.length) {
      _index = 0;
    }
    return _values[_index++];
  }
}
