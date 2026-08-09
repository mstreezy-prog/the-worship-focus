import 'package:flutter_test/flutter_test.dart';
import 'package:worship_focus_studio/models/music_xml_arrangement.dart';
import 'package:worship_focus_studio/models/score_annotation.dart';

void main() {
  test(
    'score annotation strokes round-trip through saved arrangement JSON',
    () {
      const stroke = ScoreAnnotationStroke(
        points: [
          ScoreAnnotationPoint(x: 0.2, y: 0.3),
          ScoreAnnotationPoint(x: 0.4, y: 0.5),
        ],
        color: ScoreAnnotationColor.blue,
        style: ScoreAnnotationStyle.highlighter,
        width: 16,
      );
      const arrangement = MusicXmlArrangement(
        fileName: 'Grace.musicxml',
        sourceXml: '<score-partwise/>',
        annotations: [stroke],
      );

      final restored = MusicXmlArrangement.fromJson(arrangement.toJson());

      expect(restored.annotations, hasLength(1));
      expect(restored.annotations.single.color, ScoreAnnotationColor.blue);
      expect(
        restored.annotations.single.style,
        ScoreAnnotationStyle.highlighter,
      );
      expect(restored.annotations.single.width, 16);
      expect(restored.annotations.single.points[1].x, 0.4);
      expect(restored.annotations.single.points[1].y, 0.5);
    },
  );

  test('old arrangements without annotations remain valid', () {
    final arrangement = MusicXmlArrangement.fromJson({
      'fileName': 'Older.musicxml',
      'sourceXml': '<score-partwise/>',
    });

    expect(arrangement.annotations, isEmpty);
  });
}
