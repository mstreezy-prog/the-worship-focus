import 'dart:ui';

/// A normalized point on a rendered score. Normalizing allows a marking to
/// remain in place when the score is shown at a different iPad size.
class ScoreAnnotationPoint {
  const ScoreAnnotationPoint({required this.x, required this.y});

  final double x;
  final double y;

  Offset toOffset(Size size) => Offset(x * size.width, y * size.height);

  Map<String, Object> toJson() => {'x': x, 'y': y};

  factory ScoreAnnotationPoint.fromJson(Map<String, Object?> json) {
    final x = json['x'];
    final y = json['y'];
    if (x is! num || y is! num) {
      throw const FormatException('Invalid score annotation point');
    }
    return ScoreAnnotationPoint(x: x.toDouble(), y: y.toDouble());
  }
}

enum ScoreAnnotationStyle { pen, highlighter }

enum ScoreAnnotationColor {
  purple(0xFF6F42C1),
  blue(0xFF1565C0),
  red(0xFFC62828),
  black(0xFF202124);

  const ScoreAnnotationColor(this.value);

  final int value;

  Color get color => Color(value);

  String get label => switch (this) {
    ScoreAnnotationColor.purple => 'Purple',
    ScoreAnnotationColor.blue => 'Blue',
    ScoreAnnotationColor.red => 'Red',
    ScoreAnnotationColor.black => 'Black',
  };
}

class ScoreAnnotationStroke {
  const ScoreAnnotationStroke({
    required this.points,
    required this.color,
    required this.style,
    this.width = 4,
  });

  final List<ScoreAnnotationPoint> points;
  final ScoreAnnotationColor color;
  final ScoreAnnotationStyle style;
  final double width;

  Map<String, Object> toJson() => {
    'points': [for (final point in points) point.toJson()],
    'color': color.name,
    'style': style.name,
    'width': width,
  };

  factory ScoreAnnotationStroke.fromJson(Map<String, Object?> json) {
    final rawPoints = json['points'];
    final color = _enumByName(ScoreAnnotationColor.values, json['color']);
    final style = _enumByName(ScoreAnnotationStyle.values, json['style']);
    if (rawPoints is! List || color == null || style == null) {
      throw const FormatException('Invalid score annotation stroke');
    }
    return ScoreAnnotationStroke(
      points: [
        for (final point in rawPoints)
          if (point is Map<String, Object?>)
            ScoreAnnotationPoint.fromJson(point)
          else
            throw const FormatException('Invalid score annotation point'),
      ],
      color: color,
      style: style,
      width: (json['width'] as num?)?.toDouble() ?? 4,
    );
  }
}

T? _enumByName<T extends Enum>(Iterable<T> values, Object? value) {
  if (value is! String) return null;
  for (final candidate in values) {
    if (candidate.name == value) return candidate;
  }
  return null;
}
