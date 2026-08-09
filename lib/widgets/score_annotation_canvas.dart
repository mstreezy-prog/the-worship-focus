import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';

import '../models/score_annotation.dart';

enum ScoreAnnotationTool { none, pen, highlighter, eraser }

/// A Pencil-first overlay for app-owned score markings.
///
/// The score remains scrollable and zoomable while [tool] is [none]. When a
/// drawing tool is selected, only a stylus (or a desktop mouse for testing)
/// changes the overlay; finger gestures never become markings.
class ScoreAnnotationCanvas extends StatefulWidget {
  const ScoreAnnotationCanvas({
    required this.annotations,
    required this.tool,
    required this.color,
    required this.onChanged,
    super.key,
  });

  final List<ScoreAnnotationStroke> annotations;
  final ScoreAnnotationTool tool;
  final ScoreAnnotationColor color;
  final ValueChanged<List<ScoreAnnotationStroke>> onChanged;

  @override
  ScoreAnnotationCanvasState createState() => ScoreAnnotationCanvasState();
}

class ScoreAnnotationCanvasState extends State<ScoreAnnotationCanvas> {
  static const _historyLimit = 30;
  static const _eraserRadius = 20.0;

  late List<ScoreAnnotationStroke> _annotations;
  final List<List<ScoreAnnotationStroke>> _undoHistory = [];
  final List<List<ScoreAnnotationStroke>> _redoHistory = [];
  final List<ScoreAnnotationPoint> _activePoints = [];
  List<ScoreAnnotationStroke>? _eraseStart;
  bool _didErase = false;

  bool get canUndo => _undoHistory.isNotEmpty;
  bool get canRedo => _redoHistory.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _annotations = List.unmodifiable(widget.annotations);
  }

  @override
  void didUpdateWidget(ScoreAnnotationCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.annotations, _annotations)) {
      _annotations = List.unmodifiable(widget.annotations);
      _undoHistory.clear();
      _redoHistory.clear();
    }
  }

  void undo() {
    if (!canUndo) return;
    final previous = _undoHistory.removeLast();
    _redoHistory.add(_annotations);
    _setAnnotations(previous);
  }

  void redo() {
    if (!canRedo) return;
    final next = _redoHistory.removeLast();
    _undoHistory.add(_annotations);
    _setAnnotations(next);
  }

  void clear() {
    if (_annotations.isEmpty) return;
    _recordChange(const <ScoreAnnotationStroke>[]);
  }

  void _recordChange(List<ScoreAnnotationStroke> next) {
    _undoHistory.add(_annotations);
    if (_undoHistory.length > _historyLimit) _undoHistory.removeAt(0);
    _redoHistory.clear();
    _setAnnotations(next);
  }

  void _setAnnotations(List<ScoreAnnotationStroke> value) {
    final next = List<ScoreAnnotationStroke>.unmodifiable(value);
    setState(() => _annotations = next);
    widget.onChanged(next);
  }

  bool _canAnnotate(PointerEvent event) {
    return event.kind == PointerDeviceKind.stylus ||
        event.kind == PointerDeviceKind.invertedStylus ||
        event.kind == PointerDeviceKind.mouse;
  }

  ScoreAnnotationPoint? _pointFor(PointerEvent event) {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return null;
    final size = renderBox.size;
    if (size.width <= 0 || size.height <= 0) return null;
    final local = renderBox.globalToLocal(event.position);
    return ScoreAnnotationPoint(
      x: (local.dx / size.width).clamp(0.0, 1.0),
      y: (local.dy / size.height).clamp(0.0, 1.0),
    );
  }

  void _onPointerDown(PointerDownEvent event) {
    if (!_canAnnotate(event) || widget.tool == ScoreAnnotationTool.none) return;
    final point = _pointFor(event);
    if (point == null) return;
    if (widget.tool == ScoreAnnotationTool.eraser) {
      _eraseStart = _annotations;
      _didErase = false;
      _eraseAt(point);
      return;
    }
    _activePoints
      ..clear()
      ..add(point);
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_canAnnotate(event) || widget.tool == ScoreAnnotationTool.none) return;
    final point = _pointFor(event);
    if (point == null) return;
    if (widget.tool == ScoreAnnotationTool.eraser) {
      _eraseAt(point);
    } else if (_activePoints.isNotEmpty) {
      setState(() => _activePoints.add(point));
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    if (!_canAnnotate(event)) return;
    if (widget.tool == ScoreAnnotationTool.eraser) {
      final start = _eraseStart;
      _eraseStart = null;
      if (_didErase && start != null) {
        _undoHistory.add(start);
        if (_undoHistory.length > _historyLimit) _undoHistory.removeAt(0);
        _redoHistory.clear();
      }
      return;
    }
    if (_activePoints.isEmpty) return;
    final style = widget.tool == ScoreAnnotationTool.highlighter
        ? ScoreAnnotationStyle.highlighter
        : ScoreAnnotationStyle.pen;
    final stroke = ScoreAnnotationStroke(
      points: List.unmodifiable(_activePoints),
      color: widget.color,
      style: style,
      width: style == ScoreAnnotationStyle.highlighter ? 16 : 4,
    );
    _activePoints.clear();
    _recordChange([..._annotations, stroke]);
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _activePoints.clear();
    _eraseStart = null;
    _didErase = false;
    setState(() {});
  }

  void _eraseAt(ScoreAnnotationPoint point) {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;
    final size = renderBox.size;
    final target = point.toOffset(size);
    final remaining = _annotations
        .where((stroke) {
          return !stroke.points.any(
            (candidate) =>
                (candidate.toOffset(size) - target).distance <= _eraserRadius,
          );
        })
        .toList(growable: false);
    if (remaining.length == _annotations.length) return;
    _didErase = true;
    _setAnnotations(remaining);
  }

  @override
  Widget build(BuildContext context) {
    final painter = CustomPaint(
      painter: _ScoreAnnotationPainter(
        annotations: _annotations,
        activePoints: _activePoints,
        activeColor: widget.color,
        activeStyle: widget.tool == ScoreAnnotationTool.highlighter
            ? ScoreAnnotationStyle.highlighter
            : ScoreAnnotationStyle.pen,
      ),
      child: const SizedBox.expand(),
    );
    if (widget.tool == ScoreAnnotationTool.none) {
      return IgnorePointer(
        child: Semantics(label: 'Saved score annotations', child: painter),
      );
    }
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: Semantics(label: 'Score annotation canvas', child: painter),
    );
  }
}

class _ScoreAnnotationPainter extends CustomPainter {
  const _ScoreAnnotationPainter({
    required this.annotations,
    required this.activePoints,
    required this.activeColor,
    required this.activeStyle,
  });

  final List<ScoreAnnotationStroke> annotations;
  final List<ScoreAnnotationPoint> activePoints;
  final ScoreAnnotationColor activeColor;
  final ScoreAnnotationStyle activeStyle;

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in annotations) {
      _paintStroke(
        canvas,
        size,
        stroke.points,
        stroke.color,
        stroke.style,
        stroke.width,
      );
    }
    if (activePoints.isNotEmpty) {
      _paintStroke(
        canvas,
        size,
        activePoints,
        activeColor,
        activeStyle,
        activeStyle == ScoreAnnotationStyle.highlighter ? 16 : 4,
      );
    }
  }

  void _paintStroke(
    Canvas canvas,
    Size size,
    List<ScoreAnnotationPoint> points,
    ScoreAnnotationColor color,
    ScoreAnnotationStyle style,
    double width,
  ) {
    if (points.isEmpty) return;
    final paint = Paint()
      ..color = style == ScoreAnnotationStyle.highlighter
          ? color.color.withValues(alpha: 0.32)
          : color.color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(points.first.x * size.width, points.first.y * size.height);
    for (final point in points.skip(1)) {
      path.lineTo(point.x * size.width, point.y * size.height);
    }
    if (points.length == 1) {
      canvas.drawCircle(
        points.first.toOffset(size),
        width / 2,
        paint..style = PaintingStyle.fill,
      );
    } else {
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_ScoreAnnotationPainter oldDelegate) {
    return oldDelegate.annotations != annotations ||
        oldDelegate.activePoints != activePoints ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.activeStyle != activeStyle;
  }
}
