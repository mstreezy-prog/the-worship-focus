import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/chordpro_document.dart';

/// A compact guitar-style chord grid drawn from a ChordPro chord definition.
class ChordDiagram extends StatelessWidget {
  const ChordDiagram({
    required this.definition,
    this.compact = false,
    super.key,
  });

  final ChordDiagramDefinition definition;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final width = compact ? 116.0 : 144.0;
    final height = compact ? 144.0 : 178.0;
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: '${definition.name} chord diagram',
      child: SizedBox(
        width: width,
        child: Card.outlined(
          clipBehavior: Clip.antiAlias,
          margin: EdgeInsets.zero,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              compact ? 8 : 12,
              compact ? 6 : 8,
              compact ? 8 : 12,
              compact ? 8 : 12,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  definition.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontFamily: 'CMG Sans',
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: height,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: _ChordDiagramPainter(
                      definition: definition,
                      color: colors.onSurface,
                      mutedColor: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChordDiagramPainter extends CustomPainter {
  const _ChordDiagramPainter({
    required this.definition,
    required this.color,
    required this.mutedColor,
  });

  final ChordDiagramDefinition definition;
  final Color color;
  final Color mutedColor;

  @override
  void paint(Canvas canvas, Size size) {
    final strings = definition.frets.length;
    if (strings < 2 || size.width <= 0 || size.height <= 0) return;
    final markerHeight = size.height * 0.14;
    final left = size.width * 0.15;
    final right = size.width * 0.85;
    final top = markerHeight + (definition.baseFret > 1 ? 14 : 2);
    final bottom = size.height * 0.88;
    final highestFret = definition.frets
        .where((fret) => fret > 0)
        .fold<int>(0, (maximum, fret) => fret > maximum ? fret : maximum);
    final fretCount = math.max(4, highestFret);
    final stringGap = (right - left) / (strings - 1);
    final fretGap = (bottom - top) / fretCount;
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final nutPaint = Paint()
      ..color = color
      ..strokeWidth = definition.baseFret == 1 ? 3.5 : 1.5
      ..style = PaintingStyle.stroke;

    for (var string = 0; string < strings; string++) {
      final x = left + string * stringGap;
      canvas.drawLine(Offset(x, top), Offset(x, bottom), linePaint);
    }
    for (var fret = 0; fret <= fretCount; fret++) {
      final y = top + fret * fretGap;
      canvas.drawLine(
        Offset(left, y),
        Offset(right, y),
        fret == 0 ? nutPaint : linePaint,
      );
    }

    if (definition.baseFret > 1) {
      final text = TextPainter(
        text: TextSpan(
          text: '${definition.baseFret}',
          style: TextStyle(
            color: mutedColor,
            fontSize: math.min(13, size.height * 0.1),
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, Offset(0, top - text.height / 2));
    }

    for (var string = 0; string < strings; string++) {
      final fret = definition.frets[string];
      final x = left + string * stringGap;
      if (fret < 0 || fret == 0) {
        _drawOpenOrMutedMarker(
          canvas,
          x: x,
          y: markerHeight / 2,
          muted: fret < 0,
        );
        continue;
      }
      final y = top + (fret - 0.5) * fretGap;
      final radius = math.min(stringGap, fretGap) * 0.27;
      canvas.drawCircle(Offset(x, y), radius, Paint()..color = color);
      final finger = definition.fingers.elementAtOrNull(string);
      if (finger != null && RegExp(r'^[1-9A-Z]$').hasMatch(finger)) {
        final label = TextPainter(
          text: TextSpan(
            text: finger,
            style: TextStyle(
              color:
                  ThemeData.estimateBrightnessForColor(color) == Brightness.dark
                  ? Colors.white
                  : Colors.black,
              fontSize: radius * 1.55,
              fontWeight: FontWeight.w700,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        label.paint(canvas, Offset(x - label.width / 2, y - label.height / 2));
      }
    }
  }

  void _drawOpenOrMutedMarker(
    Canvas canvas, {
    required double x,
    required double y,
    required bool muted,
  }) {
    const radius = 4.2;
    final paint = Paint()
      ..color = mutedColor
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    if (!muted) {
      canvas.drawCircle(Offset(x, y), radius, paint);
      return;
    }
    canvas
      ..drawLine(
        Offset(x - radius, y - radius),
        Offset(x + radius, y + radius),
        paint,
      )
      ..drawLine(
        Offset(x + radius, y - radius),
        Offset(x - radius, y + radius),
        paint,
      );
  }

  @override
  bool shouldRepaint(covariant _ChordDiagramPainter oldDelegate) =>
      definition != oldDelegate.definition ||
      color != oldDelegate.color ||
      mutedColor != oldDelegate.mutedColor;
}
