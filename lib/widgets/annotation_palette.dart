import 'package:flutter/material.dart';

import '../models/score_annotation.dart';
import 'score_annotation_canvas.dart';

/// Floating Markup-style controls. Drawing and history remain in the reader.
class AnnotationPalette extends StatelessWidget {
  const AnnotationPalette({
    super.key,
    required this.tool,
    required this.color,
    required this.widthScale,
    required this.onToolChanged,
    required this.onColorChanged,
    required this.onWidthChanged,
    this.onUndo,
    this.onRedo,
    this.onClear,
  });
  final ScoreAnnotationTool tool;
  final ScoreAnnotationColor color;
  final double widthScale;
  final ValueChanged<ScoreAnnotationTool> onToolChanged;
  final ValueChanged<ScoreAnnotationColor> onColorChanged;
  final ValueChanged<double> onWidthChanged;
  final VoidCallback? onUndo, onRedo, onClear;

  @override
  Widget build(BuildContext context) => Material(
    elevation: 12,
    shadowColor: Colors.black38,
    color: const Color(0xFF777879),
    borderRadius: BorderRadius.circular(44),
    child: SizedBox(
      height: 88,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Undo marking',
              onPressed: onUndo,
              color: Colors.white,
              icon: const Icon(Icons.undo),
            ),
            IconButton(
              tooltip: 'Redo marking',
              onPressed: onRedo,
              color: Colors.white,
              icon: const Icon(Icons.redo),
            ),
            IconButton(
              tooltip: 'Navigate',
              isSelected: tool == ScoreAnnotationTool.none,
              onPressed: () => onToolChanged(ScoreAnnotationTool.none),
              color: Colors.white,
              icon: const Icon(Icons.pan_tool_outlined),
            ),
            for (final entry in [
              (ScoreAnnotationTool.pen, 'Pencil'),
              (ScoreAnnotationTool.highlighter, 'Highlighter'),
              (ScoreAnnotationTool.eraser, 'Eraser'),
            ])
              Tooltip(
                message: entry.$2,
                child: Semantics(
                  button: true,
                  selected: tool == entry.$1,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => onToolChanged(entry.$1),
                    child: SizedBox(
                      width: 58,
                      height: 84,
                      child: Column(
                        children: [
                          SizedBox(
                            height: 58,
                            width: 42,
                            child: AnimatedSlide(
                              duration: const Duration(milliseconds: 160),
                              offset: Offset(0, tool == entry.$1 ? -.07 : .08),
                              child: CustomPaint(
                                painter: _ToolPainter(entry.$1, color.color),
                              ),
                            ),
                          ),
                          Text(
                            entry.$2,
                            maxLines: 1,
                            overflow: TextOverflow.clip,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: tool == entry.$1
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          if (tool == entry.$1)
                            const SizedBox(
                              width: 18,
                              child: Divider(
                                height: 4,
                                thickness: 2,
                                color: Colors.white,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(width: 8),
            SizedBox(
              width: 112,
              height: 76,
              child: Wrap(
                spacing: 5,
                runSpacing: 5,
                children: [
                  for (final ink in [
                    ScoreAnnotationColor.black,
                    ScoreAnnotationColor.blue,
                    ScoreAnnotationColor.green,
                    ScoreAnnotationColor.yellow,
                    ScoreAnnotationColor.red,
                    ScoreAnnotationColor.purple,
                  ])
                    Tooltip(
                      message: '${ink.label} ink',
                      child: Semantics(
                        button: true,
                        selected: color == ink,
                        child: InkWell(
                          onTap: () => onColorChanged(ink),
                          customBorder: const CircleBorder(),
                          child: Container(
                            width: 32,
                            height: 32,
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: color == ink
                                    ? Colors.white
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: ink.color,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            PopupMenuButton<double>(
              tooltip: 'Stroke width',
              initialValue: widthScale,
              onSelected: onWidthChanged,
              icon: const Icon(Icons.line_weight, color: Colors.white),
              itemBuilder: (_) => [
                for (final width in [.5, 1.0, 2.0])
                  CheckedPopupMenuItem(
                    value: width,
                    checked: widthScale == width,
                    child: Text(
                      width == .5
                          ? 'Fine'
                          : width == 1
                          ? 'Medium'
                          : 'Bold',
                    ),
                  ),
              ],
            ),
            TextButton(
              onPressed: onClear,
              key: const ValueKey('remove-pencil-marks'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white38,
              ),
              child: const Text('Remove pencil marks'),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Tool silhouettes are vector artwork, so they stay crisp at any display scale.
class _ToolPainter extends CustomPainter {
  const _ToolPainter(this.tool, this.ink);
  final ScoreAnnotationTool tool;
  final Color ink;
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.width / 2;
    final body = Rect.fromLTRB(center - 10, 25, center + 10, size.height + 4);
    final paint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF242526), Color(0xFF565859), Color(0xFF202122)],
      ).createShader(body);
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, const Radius.circular(3)),
      paint,
    );
    if (tool == ScoreAnnotationTool.eraser) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(center - 10, 10, center + 10, 29),
          const Radius.circular(5),
        ),
        Paint()..color = const Color(0xFFFFA5B5),
      );
      canvas.drawRect(
        Rect.fromLTRB(center - 10, 27, center + 10, 33),
        Paint()..color = const Color(0xFFBFC0C1),
      );
    } else {
      final highlighter = tool == ScoreAnnotationTool.highlighter;
      final tip = Path()
        ..moveTo(center - (highlighter ? 8 : 2), highlighter ? 13 : 3)
        ..lineTo(center + (highlighter ? 8 : 2), highlighter ? 9 : 3)
        ..lineTo(center + 8, 26)
        ..lineTo(center - 8, 26)
        ..close();
      canvas.drawPath(tip, Paint()..color = ink);
      canvas.drawRect(
        Rect.fromLTRB(center - 10, 39, center + 10, 44),
        Paint()..color = ink,
      );
    }
  }

  @override
  bool shouldRepaint(_ToolPainter oldDelegate) =>
      oldDelegate.tool != tool || oldDelegate.ink != ink;
}
